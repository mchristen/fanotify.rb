# frozen_string_literal: true

require "fcntl"
require "thread"

module FanotifyUtils
  class RootUnavailableError < StandardError; end

  class Watcher
    include Enumerable

    MASK = Event::TYPES.values.reduce(0, :|) | Fanotify::FAN_EVENT_ON_CHILD | Fanotify::FAN_ONDIR
    STRUCTURAL_MASK = Fanotify::FAN_CREATE | Fanotify::FAN_DELETE | Fanotify::FAN_MOVE |
                      Fanotify::FAN_DELETE_SELF | Fanotify::FAN_MOVE_SELF
    Group = Struct.new(:io, :directories, keyword_init: true)
    Directory = Struct.new(:io, :path, :key, :group, keyword_init: true)
    private_constant :MASK, :STRUCTURAL_MASK, :Group, :Directory

    attr_reader :root, :recursive

    def self.open(path, recursive: true)
      watcher = new(path, recursive: recursive)
      return watcher unless block_given?

      begin
        yield watcher
      ensure
        watcher.close
      end
    end

    def initialize(path, recursive: true)
      raise ArgumentError, "recursive must be true or false" unless [true, false].include?(recursive)

      @root = File.realpath(path).freeze
      raise Errno::ENOTDIR, @root unless File.directory?(@root)

      @recursive = recursive
      @groups = {}
      @directories = {}
      @state_mutex = Mutex.new
      @read_mutex = Mutex.new
      @closed = false
      @wakeup_read, @wakeup_write = IO.pipe
      begin
        rescan
      rescue Exception # Release native resources even when initialization is interrupted.
        close
        raise
      end
    end

    def closed?
      @state_mutex.synchronize { @closed }
    end

    def close
      @state_mutex.synchronize do
        return if @closed

        @closed = true
        @wakeup_write.write_nonblock("x", exception: false)
      end
      @read_mutex.synchronize do
        @directories.each_value { |directory| directory.io.close unless directory.io.closed? }
        @groups.each_value { |group| group.io.close unless group.io.closed? }
        @wakeup_read.close
        @wakeup_write.close
      end
      nil
    end

    def each
      return enum_for(__method__) unless block_given?

      until closed?
        begin
          events = read_events
        rescue IOError
          raise unless closed?
          break
        end
        events.each do |event|
          break if closed?
          yield event
        end
      end
      self
    end

    # A timeout is in seconds; nil waits indefinitely and zero polls.
    def read_events(timeout: nil)
      unless timeout.nil? || (timeout.is_a?(Numeric) && timeout.real? && timeout.finite? && timeout >= 0)
        raise ArgumentError, "timeout must be a finite non-negative number or nil"
      end

      @read_mutex.synchronize do
        raise IOError, "watcher is closed" if closed?

        ready = IO.select(@groups.values.map(&:io) + [@wakeup_read], nil, nil, timeout)&.first
        next [] if !ready || closed?

        events = []
        refresh = false
        @groups.each_value do |group|
          next unless ready.include?(group.io)

          buffer = group.io.read_nonblock(65_536, exception: false)
          next if buffer == :wait_readable
          raise IOError, "fanotify group closed unexpectedly" unless buffer

          Decoder.decode(buffer).each do |record|
            parent = group.directories[record.parent]
            directory = parent || group.directories[record.object]
            # A removed mark can still have queued events for a directory that
            # has left the watched tree. Such events are outside our scope.
            next unless directory

            path = parent && record.name != "." ? File.join(parent.path, record.name) : directory.path
            events << Event.new(path: path, mask: record.mask, pid: record.pid)
            refresh ||= record.mask & Fanotify::FAN_ONDIR != 0 && record.mask & STRUCTURAL_MASK != 0
          end
        end
        rescan if refresh
        events
      end
    rescue InvalidEventError, QueueOverflowError, RootUnavailableError, SystemCallError
      close
      raise
    end

    private

    def group_for(device)
      @groups[device] ||= begin
        flags = Fanotify::FAN_CLOEXEC | Fanotify::FAN_NONBLOCK |
                Fanotify::FAN_REPORT_DFID_NAME | Fanotify::FAN_REPORT_FID
        Group.new(io: IO.for_fd(Fanotify.init(flags, Fcntl::O_RDONLY), "rb"), directories: {})
      end
    end

    # Keep each directory open so removal can address the marked inode through
    # dirfd, even after its pathname has been renamed or replaced.
    def register_directory(io, path)
      stat = io.stat
      identity = [stat.dev, stat.ino]
      if (directory = @directories[identity])
        io.close
        directory.path = path
        return [identity, directory]
      end

      flags = Fanotify.const_defined?(:AT_HANDLE_FID) ? Fanotify::AT_HANDLE_FID : 0
      begin
        _mount_id, type, bytes = Fanotify.name_to_handle_at(io.fileno, ".", flags)
      rescue Errno::EINVAL
        raise if flags.zero?
        # Headers may be newer than the running kernel.
        _mount_id, type, bytes = Fanotify.name_to_handle_at(io.fileno, ".", 0)
      end
      group = group_for(stat.dev)
      Fanotify.mark(group.io.fileno, Fanotify::FAN_MARK_ADD | Fanotify::FAN_MARK_ONLYDIR,
                    MASK, io.fileno, nil)
      directory = Directory.new(io: io, path: path, key: [type, bytes].freeze, group: group)
      @directories[identity] = directory
      [identity, directory]
    rescue Exception
      io.close unless io.closed?
      raise
    end

    def rescan
      desired = {}
      paths = [root]
      until paths.empty?
        path = paths.pop
        begin
          stat = File.lstat(path)
          next if stat.symlink? || !stat.directory? || desired.key?([stat.dev, stat.ino])

          identity, directory = register_directory(File.open(path, File::RDONLY | File::NOFOLLOW), path)
          desired[identity] = directory
          next unless recursive

          # Mark the parent before examining its children. Newly observed
          # subdirectories are marked during the next structural-event rescan.
          Dir.children(path).sort.reverse_each { |name| paths << File.join(path, name) }
        rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ELOOP
          raise RootUnavailableError, "watched root disappeared: #{root}" if path == root
          # Descendants can disappear while a tree is being walked.
        end
      end
      unless desired.values.any? { |directory| directory.path == root }
        raise RootUnavailableError, "watched root is no longer a directory: #{root}"
      end

      @directories.each do |identity, directory|
        next if desired.key?(identity)

        begin
          Fanotify.mark(directory.group.io.fileno, Fanotify::FAN_MARK_REMOVE,
                        MASK, directory.io.fileno, nil)
        rescue Errno::ENOENT
          # The kernel already removed this mark.
        ensure
          directory.io.close
        end
      end
      @directories = desired
      @groups.each_value { |group| group.directories.clear }
      @directories.each_value { |directory| directory.group.directories[directory.key] = directory }
      @groups.delete_if do |_device, group|
        next false unless group.directories.empty?

        group.io.close
        true
      end
    end
  end
end
