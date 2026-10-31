# fanotify_utils

Directory change notifications built on `fanotify.rb`. Watching is recursive
by default and includes new or moved-in subdirectories after they are discovered.

```ruby
require "fanotify_utils"

FanotifyUtils.watch("/data") do |event|
  puts "#{event.types.join(', ')} #{event.directory? ? 'directory' : 'file'} #{event.path}"
end
```

The block runs on the calling thread. Leaving it, raising an exception, or
interrupting iteration closes the watcher. Pass `recursive: false` to watch
only the root directory and its immediate children.

For batch reads and explicit lifecycle management:

```ruby
FanotifyUtils::Watcher.open("/data", recursive: true) do |watcher|
  watcher.read_events(timeout: 1.0).each do |event|
    puts "#{event.types.inspect}: #{event.path}"
  end
end
```

`Watcher.new` and `FanotifyUtils.watch` without a block return an open watcher.
Call `close` when finished. `each` returns an Enumerator without a block;
it iterates until closed. `close` also wakes a thread blocked in `read_events`.
Reads on an already closed watcher raise `IOError`.

`read_events(timeout: nil)` waits indefinitely; `timeout: 0` polls; a finite
non-negative timeout is in seconds. Timeout expiry returns an empty array.

Events are immutable and expose:

| Method | Value |
| --- | --- |
| `path` | Absolute path derived from the watched directory and reported entry name |
| `types` | An array of change symbols; a kernel event can carry several flags |
| `directory?` | Whether the affected entry is a directory |
| `pid` | Process ID as reported by the kernel; restricted groups may hide other processes' IDs |
| `mask` | Original fanotify bitmask |

Change types are `:created`, `:modified`, `:attributes_changed`,
`:closed_after_write`, `:deleted`, `:moved_from`, `:moved_to`, `:deleted_self`,
and `:moved_self`. Moves are separate source/destination notifications, not
paired rename objects. An existing file written during a modification can
produce both modification and write-close events.

## Requirements and behavior

- Linux 5.9 or later for named directory records, and filesystems supporting
  fanotify file handles. The dependency must be `fanotify.rb` 0.2.x.
- Unprivileged notification groups are supported by Linux 5.13 and later
  (and selected backports), subject to kernel limits, permissions, and syscall
  filtering. Containers must allow `fanotify_init`, `fanotify_mark`, and
  `name_to_handle_at`. Native errors propagate instead of falling back to polling.
- Every watched directory holds an open descriptor and a fanotify inode mark.
  There is also one notification group per filesystem plus a wakeup pipe.
  Large trees require suitable descriptor and kernel mark limits.
- Descendant symlinks are not traversed. The initial root is canonicalized.
  Repeated directory identities, such as bind aliases, are visited once to
  avoid traversal loops. Supported filesystems mounted below the tree are
  visited too; an unsupported filesystem causes initialization or refresh to fail.
- Directory creation, deletion, and movement trigger a tree rescan. New marks
  are installed before those batches are returned. Changes between creating or
  moving in a subtree and installing its marks can be missed. Existing contents
  of a moved-in subtree are not synthesized as creation events. Initial setup
  and later rescans are not atomic snapshots.
- Kernel events can be coalesced. Paths reflect the watcher's directory mapping
  and can be stale during concurrent moves; they are notifications, not stable
  references for security decisions. Unresolvable queued events from directories
  removed from the tree are ignored.
- `QueueOverflowError` and `InvalidEventError` close the watcher and raise.
  After overflow, reconcile application state and create a new watcher.
- If the configured root disappears or stops being a directory during refresh,
  `RootUnavailableError` closes the watcher. Create a new watcher for its new location.

This API only requests notifications. It does not intercept access, make
permission decisions, start background worker threads, or write to watched files.

## Development

Run `bundle install` at the repository root and `bundle exec rake test` to
compile the dependency and test both gems. From this directory, its own
Gemfile resolves `fanotify.rb` from the neighboring source directory.
Run `bundle exec rake compile` at the root before running utility tests alone
from a fresh source checkout.

Unit tests exercise decoding, recursive directory maintenance, and shutdown
without kernel capabilities. The system test performs real file operations;
it skips if fanotify or file handles are unavailable. The repository's
`sh script/test-container` requires the system test to pass without a skip.

Build with `gem build --strict fanotify_utils.gemspec`. Release tags are
`fanotify_utils/vVERSION`; see the repository README for Trusted Publishing.
