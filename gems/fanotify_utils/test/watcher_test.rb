# frozen_string_literal: true

require_relative "test_helper"
require "timeout"

class WatcherTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir("fanotify-watch")
    @source = NotificationSource.new
    @watchers = []
  end

  def teardown
    @watchers.each(&:close)
    FileUtils.remove_entry(@root)
  end

  def watcher(**options)
    FanotifyUtils::Watcher.new(@root, **options).tap { |item| @watchers << item }
  end

  def added_inodes
    @source.marks.select { |flags, _| flags & Fanotify::FAN_MARK_ADD != 0 }.map(&:last)
  end

  def test_marks_existing_tree_recursively_without_following_symlinks
    nested = File.join(@root, "child", "nested")
    FileUtils.mkdir_p(nested)
    File.symlink(@root, File.join(@root, "loop"))
    @source.use do
      item = watcher
      assert item.recursive
      assert_equal [@root, File.dirname(nested), nested].map { |path| File.stat(path).ino }.sort, added_inodes.sort
      assert_empty item.read_events(timeout: 0)
    end
  end

  def test_follows_new_subdirectories_before_returning_their_creation_event
    @source.use do
      item = watcher
      nested = File.join(@root, "new", "nested")
      FileUtils.mkdir_p(nested)
      @source.emit(@root, "new", Fanotify::FAN_CREATE | Fanotify::FAN_ONDIR)
      event = item.read_events(timeout: 0).first
      assert_equal File.dirname(nested), event.path
      assert_equal [:created], event.types
      assert event.directory?
      assert_includes added_inodes, File.stat(nested).ino
      @source.emit(nested, "file", Fanotify::FAN_MODIFY | Fanotify::FAN_CLOSE_WRITE)
      changed = item.read_events(timeout: 0).first
      assert_equal File.join(nested, "file"), changed.path
      assert_equal [:modified, :closed_after_write], changed.types
      refute changed.directory?
      assert changed.frozen?
      assert changed.path.frozen?
    end
  end

  def test_immediate_child_mode_does_not_mark_descendants
    FileUtils.mkdir_p(File.join(@root, "child", "nested"))
    @source.use do
      watcher(recursive: false)
      assert_equal [File.stat(@root).ino], added_inodes
    end
  end

  def test_tracks_directory_renames_and_removes_marks_for_moved_out_directories
    before = File.join(@root, "before")
    after = File.join(@root, "after")
    FileUtils.mkdir_p(before)
    inode = File.stat(before).ino
    @source.use do
      item = watcher
      File.rename(before, after)
      @source.emit(@root, "before", Fanotify::FAN_MOVED_FROM | Fanotify::FAN_ONDIR)
      @source.emit(@root, "after", Fanotify::FAN_MOVED_TO | Fanotify::FAN_ONDIR)
      assert_equal [before, after], item.read_events(timeout: 0).map(&:path)
      @source.emit(after, "file", Fanotify::FAN_MODIFY)
      assert_equal File.join(after, "file"), item.read_events(timeout: 0).first.path
      Dir.mktmpdir("fanotify-outside") do |outside|
        moved = File.join(outside, "moved")
        File.rename(after, moved)
        @source.emit(@root, "after", Fanotify::FAN_MOVED_FROM | Fanotify::FAN_ONDIR)
        item.read_events(timeout: 0)
        assert_includes @source.marks, [Fanotify::FAN_MARK_REMOVE, inode]
        @source.emit(moved, "outside-file", Fanotify::FAN_MODIFY)
        assert_empty item.read_events(timeout: 0)
      end
    end
  end

  def test_deletion_retains_the_reported_path
    @source.use do
      item = watcher
      @source.emit(@root, "gone", Fanotify::FAN_DELETE)
      event = item.read_events(timeout: 0).first
      assert_equal File.join(@root, "gone"), event.path
      assert_equal [:deleted], event.types
    end
  end

  def test_close_interrupts_a_blocked_reader
    @source.use do
      item = watcher
      entered = Queue.new
      select = IO.method(:select)
      reader = nil
      IO.stub(:select, ->(*args) { entered << true; select.call(*args) }) do
        reader = Thread.new { item.read_events }
        entered.pop
        item.close
        assert reader.join(2), "reader did not stop"
        assert_equal [], reader.value
      end
      assert item.closed?
      assert_raises(IOError) { item.read_events(timeout: 0) }
      item.close
    ensure
      reader&.kill if reader&.alive?
    end
  end

  def test_overflow_closes_the_watcher_instead_of_silently_losing_events
    @source.use do
      item = watcher
      @source.emit_buffer(@source.event_buffer(Fanotify::FAN_Q_OVERFLOW))
      assert_raises(FanotifyUtils::QueueOverflowError) { item.read_events(timeout: 0) }
      assert item.closed?
    end
  end

  def test_open_closes_on_handler_exception
    @source.use do
      item = nil
      assert_raises(RuntimeError) do
        FanotifyUtils::Watcher.open(@root) { |opened| item = opened; raise "handler failed" }
      end
      assert item.closed?
    end
  end

  def test_watch_closes_when_the_event_handler_raises
    root = @root
    original_mark = @source.method(:mark)
    @source.define_singleton_method(:mark) do |*args|
      result = original_mark.call(*args)
      emit(root, "file", Fanotify::FAN_CREATE)
      result
    end
    @source.use do
      assert_raises(RuntimeError) do
        FanotifyUtils.watch(@root) { |_event| raise "handler failed" }
      end
      assert_raises(Errno::EPIPE) { @source.emit(@root, "another", Fanotify::FAN_CREATE) }
    end
  end

  def test_initialization_failure_does_not_leak_partial_marks_or_descriptors
    Dir.mkdir(File.join(@root, "child"))
    calls = 0
    original_mark = @source.method(:mark)
    @source.define_singleton_method(:mark) do |*args|
      calls += 1
      raise Errno::EACCES if calls == 2
      original_mark.call(*args)
    end
    descriptors = Dir.children("/proc/self/fd").size
    @source.use do
      assert_raises(Errno::EACCES) { watcher }
    end
    assert_equal descriptors, Dir.children("/proc/self/fd").size
  end

  def test_removing_the_root_raises_and_closes_the_watcher
    @source.use do
      item = watcher
      data = @source.event_buffer(Fanotify::FAN_DELETE_SELF | Fanotify::FAN_ONDIR,
                                  @source.fid_info(@root, type: 1))
      Dir.rmdir(@root)
      @source.emit_buffer(data)
      assert_raises(FanotifyUtils::RootUnavailableError) { item.read_events(timeout: 0) }
      assert item.closed?
    end
  ensure
    Dir.mkdir(@root) unless File.exist?(@root)
  end

  def test_moving_in_a_populated_tree_registers_all_descendants
    Dir.mktmpdir("fanotify-incoming") do |outside|
      incoming = File.join(outside, "tree")
      FileUtils.mkdir_p(File.join(incoming, "one", "two"))
      @source.use do
        item = watcher
        target = File.join(@root, "incoming")
        File.rename(incoming, target)
        @source.emit(@root, "incoming", Fanotify::FAN_MOVED_TO | Fanotify::FAN_ONDIR)
        assert_equal [:moved_to], item.read_events(timeout: 0).first.types
        nested = File.join(target, "one", "two")
        assert_includes added_inodes, File.stat(nested).ino
        @source.emit(nested, "file", Fanotify::FAN_MODIFY)
        assert_equal File.join(nested, "file"), item.read_events(timeout: 0).first.path
      end
    end
  end

  def test_renaming_a_directory_updates_paths_of_its_existing_descendants
    old_path = File.join(@root, "before")
    FileUtils.mkdir_p(File.join(old_path, "nested"))
    @source.use do
      item = watcher
      new_path = File.join(@root, "after")
      File.rename(old_path, new_path)
      @source.emit(@root, "before", Fanotify::FAN_MOVED_FROM | Fanotify::FAN_ONDIR)
      @source.emit(@root, "after", Fanotify::FAN_MOVED_TO | Fanotify::FAN_ONDIR)
      item.read_events(timeout: 0)
      @source.emit(File.join(new_path, "nested"), "file", Fanotify::FAN_MODIFY)
      assert_equal File.join(new_path, "nested", "file"), item.read_events(timeout: 0).first.path
      assert_equal 3, added_inodes.size, "renaming should reuse existing inode marks"
    end
  end

  def test_replacing_a_directory_at_the_same_path_replaces_its_mark
    path = File.join(@root, "child")
    Dir.mkdir(path)
    old_inode = File.stat(path).ino
    @source.use do
      item = watcher
      Dir.rmdir(path)
      Dir.mkdir(path)
      new_inode = File.stat(path).ino
      refute_equal old_inode, new_inode
      @source.emit(@root, "child", Fanotify::FAN_DELETE | Fanotify::FAN_ONDIR)
      @source.emit(@root, "child", Fanotify::FAN_CREATE | Fanotify::FAN_ONDIR)
      assert_equal [[:deleted], [:created]], item.read_events(timeout: 0).map(&:types)
      assert_includes @source.marks, [Fanotify::FAN_MARK_REMOVE, old_inode]
      assert_includes added_inodes, new_inode
      @source.emit(path, "new-file", Fanotify::FAN_MODIFY)
      assert_equal File.join(path, "new-file"), item.read_events(timeout: 0).first.path
    end
  end

  def test_non_recursive_mode_reports_child_directories_but_not_their_contents
    @source.use do
      item = watcher(recursive: false)
      child = File.join(@root, "child")
      Dir.mkdir(child)
      @source.emit(@root, "child", Fanotify::FAN_CREATE | Fanotify::FAN_ONDIR)
      assert item.read_events(timeout: 0).first.directory?
      @source.emit(child, "ignored", Fanotify::FAN_MODIFY)
      @source.emit(@root, "included", Fanotify::FAN_MODIFY)
      assert_equal [File.join(@root, "included")], item.read_events(timeout: 0).map(&:path)
      assert_equal [File.stat(@root).ino], added_inodes
    end
  end

  def test_disappearing_descendant_during_initial_scan_is_tolerated
    vanished = File.join(@root, "vanished")
    Dir.mkdir(vanished)
    lstat = File.method(:lstat)
    @source.use do
      File.stub(:lstat, lambda { |path|
        Dir.rmdir(vanished) if path == vanished && File.exist?(vanished)
        lstat.call(path)
      }) do
        item = watcher
        refute item.closed?
        assert_equal [File.stat(@root).ino], added_inodes
      end
    end
  end

  def test_failed_rescan_closes_the_watcher_and_all_descriptors
    descriptors = Dir.children("/proc/self/fd").size
    fail_marks = false
    original_mark = @source.method(:mark)
    @source.define_singleton_method(:mark) do |*args|
      raise Errno::EACCES if fail_marks
      original_mark.call(*args)
    end
    @source.use do
      item = watcher
      Dir.mkdir(File.join(@root, "child"))
      @source.emit(@root, "child", Fanotify::FAN_CREATE | Fanotify::FAN_ONDIR)
      fail_marks = true
      assert_raises(Errno::EACCES) { item.read_events(timeout: 0) }
      assert item.closed?
    end
    assert_equal descriptors, Dir.children("/proc/self/fd").size
  end

  def test_invalid_record_closes_the_watcher
    @source.use do
      item = watcher
      @source.emit_buffer("\x00".b)
      assert_raises(FanotifyUtils::InvalidEventError) { item.read_events(timeout: 0) }
      assert item.closed?
    end
  end

  def test_finite_timeout_waits_and_returns_an_empty_batch
    @source.use do
      item = watcher
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      events = Timeout.timeout(2) { item.read_events(timeout: 0.02) }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert_empty events
      assert_operator elapsed, :>=, 0.015
      refute item.closed?
    end
  end

  def test_invalid_timeouts_do_not_close_or_corrupt_the_watcher
    @source.use do
      item = watcher
      [-1, Float::INFINITY, Float::NAN, "1", Complex(0, 1)].each do |timeout|
        assert_raises(ArgumentError) { item.read_events(timeout: timeout) }
      end
      refute item.closed?
      @source.emit(@root, "still-watching", Fanotify::FAN_MODIFY)
      assert_equal File.join(@root, "still-watching"), item.read_events(timeout: 0).first.path
    end
  end

  def test_breaking_out_of_watch_closes_the_stream
    root = @root
    original_mark = @source.method(:mark)
    @source.define_singleton_method(:mark) do |*args|
      original_mark.call(*args)
      emit(root, "file", Fanotify::FAN_CREATE)
      0
    end
    @source.use do
      result = FanotifyUtils.watch(@root) { |event| break event.path }
      assert_equal File.join(@root, "file"), result
      assert_raises(Errno::EPIPE) { @source.emit(@root, "another", Fanotify::FAN_CREATE) }
    end
  end
end
