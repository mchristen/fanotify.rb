# Changelog

## 0.1.0

Initial release.

- Native bindings for Linux `fanotify_init(2)` and `fanotify_mark(2)`.
- Linux fanotify constants, conditional on the build headers.
- Kernel errors exposed as Ruby `Errno::*` exceptions.
- Raw file descriptors for use with Ruby `IO`.
