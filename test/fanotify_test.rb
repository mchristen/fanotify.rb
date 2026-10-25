# frozen_string_literal: true

require "minitest/autorun"
require "fcntl"
require "pathname"
require "tmpdir"
require "fanotify"

class FanotifyTest < Minitest::Test
  def test_only_syscall_methods_are_exposed
    assert_equal [:init, :mark], Fanotify.singleton_methods(false).sort
    assert_equal 2, Fanotify.method(:init).arity
    assert_equal 5, Fanotify.method(:mark).arity
  end

  def test_constants_match_the_uapi
    assert_equal 0x20, Fanotify::FAN_OPEN
    assert_equal 0x08000000, Fanotify::FAN_EVENT_ON_CHILD
    assert_equal 0x40000000, Fanotify::FAN_ONDIR
    assert_equal(-1, Fanotify::FAN_NOFD)
    assert_equal(-100, Fanotify::AT_FDCWD)
    assert_equal 24, Fanotify::FAN_EVENT_METADATA_LEN
    assert_equal 3, Fanotify::FANOTIFY_METADATA_VERSION
    assert_equal Fanotify::FAN_CLOSE_WRITE | Fanotify::FAN_CLOSE_NOWRITE, Fanotify::FAN_CLOSE
  end

  def test_init_preserves_kernel_errors
    error = assert_raises(SystemCallError) { Fanotify.init(0xffffffff, 0) }
    assert_match(/fanotify_init/, error.message)
    # Sandboxes may reject the syscall before the kernel validates its flags.
    assert_includes [Errno::EINVAL::Errno, Errno::EPERM::Errno, Errno::ENOSYS::Errno], error.errno
  end

  def test_mark_preserves_kernel_errors_and_accepts_null_path
    error = assert_raises(SystemCallError) do
      Fanotify.mark(-1, Fanotify::FAN_MARK_FLUSH, 0, Fanotify::AT_FDCWD, nil)
    end
    assert_match(/fanotify_mark/, error.message)
    assert_includes [Errno::EBADF::Errno, Errno::EPERM::Errno, Errno::ENOSYS::Errno], error.errno
  end

  def test_mark_accepts_path_objects_and_a_64_bit_mask
    error = assert_raises(SystemCallError) do
      Fanotify.mark(-1, Fanotify::FAN_MARK_ADD, 1 << 63, Fanotify::AT_FDCWD, Pathname.new("."))
    end
    assert_match(/fanotify_mark/, error.message)
  end

  def test_rejects_embedded_null_bytes
    assert_raises(ArgumentError) do
      Fanotify.mark(-1, Fanotify::FAN_MARK_ADD, Fanotify::FAN_OPEN, Fanotify::AT_FDCWD, "a\0b")
    end
  end

  def test_rejects_invalid_argument_types
    assert_raises(TypeError) { Fanotify.init(nil, 0) }
    assert_raises(TypeError) { Fanotify.mark(nil, 0, 0, 0, nil) }
    assert_raises(TypeError) { Fanotify.mark(-1, 0, nil, 0, nil) }
    assert_raises(TypeError) { Fanotify.mark(-1, 0, 0, 0, Object.new) }
    assert_raises(RangeError) { Fanotify.mark(-1, 0, 1 << 100, 0, nil) }
  end

  def test_read_event_and_remove_mark_using_a_directory_fd
    fd = begin
      Fanotify.init(Fanotify::FAN_CLOEXEC | Fanotify::FAN_NONBLOCK, Fcntl::O_RDONLY)
    rescue Errno::EPERM, Errno::ENOSYS => error
      if ENV["FANOTIFY_REQUIRE_INTEGRATION"] == "1"
        flunk "fanotify integration is required: #{error.message}. " \
              "Use a Linux kernel with fanotify enabled and grant CAP_SYS_ADMIN."
      end
      skip "kernel denied fanotify_init: #{error.message}"
    end
    io = IO.for_fd(fd, "rb")

    Dir.mktmpdir("fanotify-test") do |directory|
      File.open(directory, File::RDONLY) do |dir|
        mask = Fanotify::FAN_OPEN | Fanotify::FAN_EVENT_ON_CHILD
        assert_equal 0, Fanotify.mark(fd, Fanotify::FAN_MARK_ADD, mask, dir.fileno, ".")
        path = File.join(directory, "event")
        File.write(path, "test")
        File.open(path, &:read)
        assert IO.select([io], nil, nil, 5), "expected an open event"
        data = io.read_nonblock(4096)
        found = false
        offset = 0
        while offset < data.bytesize
          length, version, _reserved, metadata_length, event_mask, event_fd, pid =
            data.byteslice(offset, Fanotify::FAN_EVENT_METADATA_LEN).unpack("LCCSQl l")
          begin
            assert_equal Fanotify::FANOTIFY_METADATA_VERSION, version
            assert_operator length, :>=, metadata_length
            assert_operator length, :<=, data.bytesize - offset
            found ||= (event_mask & Fanotify::FAN_OPEN != 0 && pid == Process.pid)
          ensure
            IO.for_fd(event_fd).close if event_fd >= 0
          end
          offset += length
        end
        assert found, "expected this process's FAN_OPEN event"
        assert_equal 0, Fanotify.mark(fd, Fanotify::FAN_MARK_REMOVE, mask, dir.fileno, ".")
        assert_equal 0, Fanotify.mark(fd, Fanotify::FAN_MARK_FLUSH, 0, Fanotify::AT_FDCWD, nil)
      end
    end
  ensure
    io&.close
  end
end
