# Changelog

## Unreleased

- Establish the `fanotify_utils` gem and `FanotifyUtils` namespace.
- Depend on `fanotify.rb` for syscall bindings.
- Add directory watching with recursive traversal by default, including newly
  created and moved-in subdirectories.
- Decode named events in Ruby and report creation, modification, metadata,
  write-close, deletion, and movement changes.
- Support timed batch reads, blocking iteration, and interruptible shutdown.
- Close and raise explicitly on queue overflow or invalid kernel records.
