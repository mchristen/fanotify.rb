# Changelog

## 0.2.0

- Add a thin `name_to_handle_at(2)` binding returning the mount ID, handle type,
  and opaque handle bytes, for matching named fanotify events to directories.
- Expose `AT_HANDLE_FID` when provided by the build headers.

## 0.1.0

Initial release.

- Native bindings for Linux `fanotify_init(2)` and `fanotify_mark(2)`.
- Linux fanotify constants, conditional on the build headers.
- Kernel errors exposed as Ruby `Errno::*` exceptions.
- Raw file descriptors for use with Ruby `IO`.
