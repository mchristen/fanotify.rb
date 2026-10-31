# frozen_string_literal: true

require_relative "test_helper"

class WatcherIntegrationTest < Minitest::Test
  def open_watcher(root, **options)
    FanotifyUtils::Watcher.new(root, **options)
  rescue Errno::EPERM, Errno::ENOSYS, Errno::EOPNOTSUPP => error
    flunk "Required watcher integration is unavailable: #{error.message}" if ENV["FANOTIFY_REQUIRE_INTEGRATION"] == "1"
    skip "Watcher integration unavailable: #{error.message}"
  end

  def with_watcher(**options)
    Dir.mktmpdir("fanotify-utils-integration") do |root|
      watcher = open_watcher(root, **options)
      begin
        yield root, watcher
      ensure
        watcher.close
      end
    end
  end

  def wait_for(watcher, path, type)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      flunk "No #{type} event for #{path}" if remaining <= 0
      event = watcher.read_events(timeout: remaining).find do |item|
        item.path == path && item.types.include?(type)
      end
      return event if event
    end
  end

  def test_existing_new_and_renamed_subdirectories_deliver_real_changes
    Dir.mktmpdir("fanotify-utils-integration") do |root|
      existing = File.join(root, "existing", "nested")
      FileUtils.mkdir_p(existing)
      watcher = open_watcher(root)

      begin
        first_file = File.join(existing, "file")
        File.write(first_file, "initial")
        event = wait_for(watcher, first_file, :created)
        assert_equal Process.pid, event.pid
        refute event.directory?

        new_directory = File.join(root, "new")
        Dir.mkdir(new_directory)
        assert wait_for(watcher, new_directory, :created).directory?
        file = File.join(new_directory, "file")
        File.write(file, "changed")
        wait_for(watcher, file, :closed_after_write)

        renamed = File.join(root, "renamed")
        File.rename(new_directory, renamed)
        assert wait_for(watcher, renamed, :moved_to).directory?
        moved_file = File.join(renamed, "file")
        File.write(moved_file, "again")
        wait_for(watcher, moved_file, :modified)
        File.unlink(moved_file)
        wait_for(watcher, moved_file, :deleted)
        Dir.rmdir(renamed)
        assert wait_for(watcher, renamed, :deleted).directory?
      ensure
        watcher.close
      end
      assert watcher.closed?
    end
  end

  def test_populated_trees_moved_in_are_watched_and_moved_out_are_ignored
    Dir.mktmpdir("fanotify-moving-tree") do |outside|
      incoming = File.join(outside, "incoming")
      FileUtils.mkdir_p(File.join(incoming, "nested"))
      with_watcher do |root, watcher|
        destination = File.join(root, "tree")
        File.rename(incoming, destination)
        assert wait_for(watcher, destination, :moved_to).directory?
        file = File.join(destination, "nested", "file")
        File.write(file, "inside")
        assert_equal file, wait_for(watcher, file, :created).path

        moved_out = File.join(outside, "outgoing")
        File.rename(destination, moved_out)
        assert wait_for(watcher, destination, :moved_from).directory?
        File.write(File.join(moved_out, "nested", "post-move"), "outside")
        events = watcher.read_events(timeout: 0.05)
        refute events.any? { |event| File.basename(event.path) == "post-move" }
      end
    end
  end

  def test_non_recursive_mode_filters_real_descendant_changes
    Dir.mktmpdir("fanotify-shallow") do |root|
      child = File.join(root, "child")
      Dir.mkdir(child)
      watcher = open_watcher(root, recursive: false)
      begin
        nested_file = File.join(child, "nested-file")
        root_file = File.join(root, "root-file")
        File.write(nested_file, "nested")
        File.write(root_file, "root")
        events = watcher.read_events(timeout: 5)
        events.concat(watcher.read_events(timeout: 0))
        assert events.any? { |event| event.path == root_file && event.types.include?(:created) }
        refute events.any? { |event| event.path == nested_file }
      ensure
        watcher.close
      end
    end
  end

  def test_file_and_directory_metadata_changes
    with_watcher do |root, watcher|
      file = File.join(root, "file")
      File.write(file, "contents")
      wait_for(watcher, file, :created)
      File.chmod(0o640, file)
      refute wait_for(watcher, file, :attributes_changed).directory?
      File.chmod(0o750, root)
      event = wait_for(watcher, root, :attributes_changed)
      assert event.directory?
      assert_equal root, event.path
    end
  end

  def test_external_symlink_targets_are_not_watched
    Dir.mktmpdir("fanotify-symlink-target") do |outside|
      Dir.mktmpdir("fanotify-symlink-root") do |root|
        File.symlink(outside, File.join(root, "link"))
        watcher = open_watcher(root)
        begin
          File.write(File.join(outside, "external"), "outside")
          assert_empty watcher.read_events(timeout: 0.05)
        ensure
          watcher.close
        end
      end
    end
  end
end
