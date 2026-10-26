# fanotify.rb

A thin, Linux-only Ruby gem for `fanotify_init(2)` and `fanotify_mark(2)`.
It exposes the syscalls and Linux constants. Use Ruby `IO` for `read(2)`,
`write(2)`, and `close(2)` on the returned descriptors.

## Build and install

Requires Ruby 3.1 or later, a C compiler, make, Ruby development headers,
and libc/Linux development headers providing `sys/fanotify.h` and both functions.

```sh
gem build fanotify.rb.gemspec
gem install ./fanotify.rb-0.1.0.gem
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

```sh
bundle install
bundle exec rake test
```

The tests compile the extension and exercise constants, argument conversion,
and kernel errors. The event integration test skips when the kernel denies
creating a descriptor-based fanotify group; run it with `CAP_SYS_ADMIN` to
exercise event delivery, relative directory descriptors, removal, and flush.

To run the complete suite in a container, including the integration test:

```sh
sh script/test-container
# Optional: choose another Ruby image.
RUBY_IMAGE=ruby:3.1 sh script/test-container
```

This requires a rootful Docker daemon on Linux (or a Linux VM) whose kernel
supports fanotify. The script grants `SYS_ADMIN`, mounts the source read-only,
and builds and tests inside the container. It sets
`FANOTIFY_REQUIRE_INTEGRATION=1`, which turns an unavailable fanotify group
into a test failure instead of a skip. You can also set this variable when
running the suite directly.

The GitHub Actions workflow uses the same script on `ubuntu-24.04` VM runners
with Ruby 3.1 and 3.4 for pushes and pull requests. No repository secrets or
fully privileged container are needed. A container host with an additional
seccomp policy must allow `fanotify_init` and `fanotify_mark`; rootless Docker
and restricted container runners cannot supply the required host capability.
The container also builds the gem with strict validation, installs it into
an isolated gem directory, and verifies it loads outside the source checkout.

## Releasing

Releases use the manually dispatched `Release` workflow in `.github/workflows/release.yml`.
It runs the full CI matrix, checks that the tag matches `Fanotify::VERSION`,
builds and verifies the package, then uses `rubygems/release-gem` to authenticate
using RubyGems Trusted Publishing and run Bundler's `rake release` task.
No RubyGems API key secret is needed. The supplied tag must already exist
and point to the commit selected for the workflow run.

Before the first release, create a GitHub environment named `Release` under
the repository settings. On RubyGems.org, configure a
[pending trusted publisher](https://rubygems.org/profile/oidc/pending_trusted_publishers)
with these exact values:

| Setting | Value |
| --- | --- |
| Gem name | `fanotify.rb` |
| Repository owner | `mchristen` |
| Repository name | `fanotify.rb` |
| Workflow filename | `release.yml` |
| Environment | `Release` |

The workflow is defined directly in this repository; leave the optional
Workflow Repository Owner and Workflow Repository Name fields blank.
See the [RubyGems Trusted Publishing guide](https://guides.rubygems.org/trusted-publishing/).

For each release:

1. Set the version in `lib/fanotify/version.rb` and update `CHANGELOG.md`.
2. Commit the release changes and get passing GitHub Actions checks on that
   commit for every Ruby version. Integration tests must run without skips,
   and the packaged gem must install and load successfully.
3. Build the package from a clean checkout of that commit. For version 0.1.0:

   ```sh
   gem build --strict fanotify.rb.gemspec
   gem unpack ./fanotify.rb-0.1.0.gem --target /tmp/fanotify-release-review
   ```

   Review the unpacked files. The package should contain only the Ruby source,
   native extension source, README, changelog, and license, with no compiled
   objects or local configuration.
4. Tag the tested commit and push the tag:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

   In GitHub Actions, open **Release**, select **Run workflow**, choose that
   tag under **Use workflow from**, and enter the same tag in the `tag` input.
   The tag must include the release workflow and Bundler release-task setup.

5. Verify `gem install fanotify.rb -v 0.1.0` on Linux and create GitHub release
   notes from the changelog. Published versions cannot be overwritten; fixes
   require a new version.

Branch pushes and pull requests only run tests. Publication requires a manual
workflow run and passing tests on both Ruby versions, including the required
integration test. A failed test, package check, tag/version mismatch, or tag
pointing to a different commit prevents publication.
