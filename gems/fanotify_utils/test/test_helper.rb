# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "fanotify_utils"

module EventBuffers
  def fid_info(directory, name = nil, type: 2)
    handle = [File.stat(directory).ino].pack("Q")
    payload = "\0".b * 8 + [handle.bytesize, 1].pack("Ll") + handle
    payload += name.b + "\0" if name
    [type, 0, 4 + payload.bytesize].pack("CCS") + payload
  end

  def event_buffer(mask, info = "".b, fd: Fanotify::FAN_NOFD)
    [24 + info.bytesize, Fanotify::FANOTIFY_METADATA_VERSION, 0, 24,
     mask, fd, Process.pid].pack("LCCSQll") + info
  end
end

# Use real directory changes and selectable pipes to exercise the Ruby layer
# independently of host fanotify capabilities. Integration tests use Linux too.
class NotificationSource
  include EventBuffers
  attr_reader :marks, :group_fds

  def initialize
    @writers = []
    @marks = []
    @group_fds = []
  end

  def init(*)
    reader, writer = IO.pipe
    @writers << writer
    descriptor = reader.fcntl(Fcntl::F_DUPFD, 0)
    reader.close
    @group_fds << descriptor
    descriptor
  end

  def name_to_handle_at(dirfd, *)
    stat = File.stat("/proc/self/fd/#{dirfd}")
    [stat.dev, 1, [stat.ino].pack("Q")]
  end

  def mark(group_fd, flags, mask, dirfd, path)
    @marks << [flags, File.stat("/proc/self/fd/#{dirfd}").ino]
    0
  end

  def emit(directory, name, mask)
    @writers.fetch(0).write(event_buffer(mask, fid_info(directory, name)))
  end

  def emit_buffer(buffer)
    @writers.fetch(0).write(buffer)
  end

  def use(&block)
    Fanotify.stub(:init, method(:init)) do
      Fanotify.stub(:mark, method(:mark)) do
        Fanotify.stub(:name_to_handle_at, method(:name_to_handle_at), &block)
      end
    end
  ensure
    @writers.each { |writer| writer.close unless writer.closed? }
  end
end
