# fanotify.rb

Thin, Linux-only Ruby bindings for `fanotify_init(2)`, `fanotify_mark(2)`,
and the related `name_to_handle_at(2)` file-handle API.
It exposes the syscalls and Linux constants. Use Ruby `IO` for `read(2)`,
`write(2)`, and `close(2)` on the returned descriptors.

## Build and install

Requires Ruby 3.1 or later, a C compiler, make, Ruby development headers,
and libc/Linux development headers providing `sys/fanotify.h` and the wrapped functions.

```sh
gem build fanotify.rb.gemspec
gem install ./fanotify.rb-0.2.0.gem
```

For Bundler, use `gem "fanotify.rb", require: "fanotify"`. The gem name is
`fanotify.rb`; the Ruby require path is `fanotify` and the module is `Fanotify`.

## API

```ruby
require "fanotify"

fd = Fanotify.init(flags, event_f_flags)
result = Fanotify.mark(fd, flags, mask, dirfd, pathname)
```

`init` returns an integer file descriptor. `mark` returns `0` on success.
Arguments are required and follow the C API in the same order; flags and
the 64-bit event mask are integers. `pathname` accepts a String, an object
implementing `to_path`, or `nil` for a C `NULL` pointer. Relative paths are
resolved by the kernel against `dirfd`; `Fanotify::AT_FDCWD` uses the current
working directory. Embedded NUL bytes are rejected.

Syscall failures raise Ruby's corresponding `Errno::*` exception with the
kernel's errno. Flags, permissions, filesystem support, and kernel-version
restrictions are governed by Linux. In particular, many operations require
`CAP_SYS_ADMIN`; unprivileged groups have additional restrictions.

The `Fanotify` module exposes object-like `FAN_*` UAPI constants and
`FANOTIFY_METADATA_VERSION`, including event masks, initialization/mark flags,
permission responses, info-record types, and `FAN_EVENT_METADATA_LEN`.
Constants are conditional on the headers used to compile the extension;
their presence does not guarantee running-kernel support. Function-like C
macros are not Ruby methods.

There are no watchers, callbacks, recursive traversal, event parsing, or
automatic descriptor ownership. The caller reads the kernel event records,
writes responses, and closes the group descriptor and each event descriptor
(including any reported pidfds).

## File handles

```ruby
mount_id, handle_type, bytes = Fanotify.name_to_handle_at(dirfd, pathname, flags)
```

This mirrors `name_to_handle_at(2)` and returns its output mount ID, handle
type, and opaque handle bytes. The wrapper supplies the Linux `MAX_HANDLE_SZ`
buffer. Errors, including `EOVERFLOW`, raise the corresponding `Errno::*`.
Mount IDs retain their full 64-bit width when the caller supplies the Linux
`AT_HANDLE_MNT_ID_UNIQUE` flag (UAPI value `0x001`).
The pathname accepts a String or `to_path` object. `AT_HANDLE_FID` is exposed
when present in the build headers; it requests identification-only handles
on supporting kernels. Resolving handles to application paths belongs to
`fanotify_utils`, which uses them to match directory event records.

## Reading events

This example uses the default descriptor-based event format. It requires
permission to create this type of group. Pass an existing directory in `ARGV[0]`.

```ruby
require "fanotify"
require "fcntl"

fd = Fanotify.init(Fanotify::FAN_CLOEXEC, Fcntl::O_RDONLY)
group = IO.for_fd(fd, "rb")

begin
  Fanotify.mark(fd, Fanotify::FAN_MARK_ADD,
                Fanotify::FAN_OPEN | Fanotify::FAN_EVENT_ON_CHILD,
                Fanotify::AT_FDCWD, ARGV.fetch(0))

  loop do
    data = group.sysread(4096)
    offset = 0
    while offset < data.bytesize
      event_len, version, _reserved, metadata_len, mask, event_fd, pid =
        data.byteslice(offset, Fanotify::FAN_EVENT_METADATA_LEN).unpack("LCCSQl l")

      begin
        raise "unsupported metadata version" unless version == Fanotify::FANOTIFY_METADATA_VERSION
        unless metadata_len >= Fanotify::FAN_EVENT_METADATA_LEN &&
               event_len >= metadata_len && event_len <= data.bytesize - offset
          raise "invalid event length"
        end
        puts "mask=#{mask} pid=#{pid} fd=#{event_fd}"
      ensure
        IO.for_fd(event_fd).close if event_fd >= 0
      end
      offset += event_len
    end
  end
ensure
  group.close
end
```

The unpack template uses native byte order and the Linux UAPI field widths.
Advance by `event_len`, since records may contain additional information
after the fixed metadata. `FAN_Q_OVERFLOW` reports lost events, and `FAN_NOFD`
is a sentinel rather than an open descriptor. Groups using `FAN_REPORT_*`
flags can return other record formats; consult the Linux API documentation.

For a permission event, the native `struct fanotify_response` can be written
with `group.syswrite([event_fd, Fanotify::FAN_ALLOW].pack("lL"))` (open `group`
in `"r+b"` mode). Respond before closing the event descriptor. `FAN_DENY`,
audit flags, and extra response records follow the kernel API.

See [fanotify(7)](https://man7.org/linux/man-pages/man7/fanotify.7.html),
[fanotify_init(2)](https://man7.org/linux/man-pages/man2/fanotify_init.2.html),
and [fanotify_mark(2)](https://man7.org/linux/man-pages/man2/fanotify_mark.2.html).

## Development

From this directory, run `bundle install` and `bundle exec rake test`.
The native extension is compiled before the tests. The event integration test
skips when the kernel denies creating a descriptor-based fanotify group;
`FANOTIFY_REQUIRE_INTEGRATION=1` makes this a failure instead.

The repository root provides `sh script/test-container` to test both gems
with `CAP_SYS_ADMIN`, including isolated package installation checks.

This gem is packaged independently of `fanotify_utils` and has no runtime
dependency on it. Build with `gem build --strict fanotify.rb.gemspec`.
Release tags are `fanotify.rb/vVERSION`; see the
[repository README](https://github.com/mchristen/fanotify.rb#releasing) for
manual release and Trusted Publishing configuration.
