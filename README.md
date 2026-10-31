# fanotify.rb and fanotify_utils

Two independently packaged Ruby gems share this repository:

| Gem | Location | Responsibility |
| --- | --- | --- |
| `fanotify.rb` | [`gems/fanotify.rb`](gems/fanotify.rb) | Linux fanotify syscall bindings and constants |
| `fanotify_utils` | [`gems/fanotify_utils`](gems/fanotify_utils) | Application helpers built on `fanotify.rb` |

`fanotify_utils` provides recursive directory watching in the `FanotifyUtils` namespace.
It reports file and directory changes, including newly discovered subdirectories. The low-level `Fanotify` API
and native extension remain in `fanotify.rb`, which has no runtime dependencies.
The utilities gem depends on `fanotify.rb`; each package includes only its own
source, README, changelog, and license.

## Using the gems

For the C interface:

```ruby
gem "fanotify.rb", require: "fanotify"
```

For directory watching, once published:

```ruby
gem "fanotify_utils"
```

See each gem's README for its API and requirements. Both require Linux and
Ruby 3.1 or later; installing `fanotify.rb` requires C and Ruby development tools.

## Development

The root Gemfile resolves both gems from their local directories. Each gem also
has its own development Gemfile, Rakefile, version, changelog, and tests.
The utilities development Gemfile resolves `fanotify.rb` from its sibling directory;
the published gemspec declares a normal RubyGems dependency.

From the repository root:

```sh
bundle install
bundle exec rake test     # Run each gem's tests separately.
bundle exec rake build    # Build each gem into its own pkg/ directory.
sh script/check-packages  # Build, install, and load both packages in isolation.
```

Run a gem's tasks directly by changing into its directory first. Compile the
native extension with `bundle exec rake compile` at the root before using the
low-level library directly from the source tree.

To run the complete suite, including real fanotify event delivery:

```sh
sh script/test-container
RUBY_IMAGE=ruby:3.1 sh script/test-container
```

The container requires rootful Docker on Linux (or a Linux VM) and a kernel
with fanotify support. It grants `SYS_ADMIN`, mounts the source read-only,
and sets `FANOTIFY_REQUIRE_INTEGRATION=1` so the integration test fails instead
of skipping when access is unavailable. It builds both gems from source and
checks installation outside the checkout. GitHub Actions uses the same runner
with Ruby 3.1 and 3.4. Default local tests may skip privileged integration.

## Releasing

Versions and releases are independent. Tags include the gem name:

- `fanotify.rb/v0.2.0`
- `fanotify_utils/v0.1.0`

Each gem defines Bundler's release tasks in its own Rakefile with that tag prefix.
Run release tasks only from the relevant gem directory; the root Rakefile
provides aggregate test and build tasks and does not publish anything.

Create a GitHub environment named `Release`. Configure a separate
[RubyGems Trusted Publisher](https://guides.rubygems.org/trusted-publishing/)
for each gem, using these settings:

| Setting | Low-level gem | Utilities gem |
| --- | --- | --- |
| Gem name | `fanotify.rb` | `fanotify_utils` |
| Repository owner | `mchristen` | `mchristen` |
| Repository name | `fanotify.rb` | `fanotify.rb` |
| Workflow filename | `release.yml` | `release.yml` |
| Environment | `Release` | `Release` |

Use a pending publisher for an unpublished gem. Leave the optional Workflow
Repository Owner and Workflow Repository Name fields blank: the workflow is
in this repository. The environment name is case-sensitive in the configuration.

For a release:

1. Update that gem's version and changelog. If changing its dependency version,
   update the utilities gemspec too.
2. Commit and push the changes and get passing CI checks.
3. Tag the commit, for example `git tag fanotify.rb/v0.2.0`, and push it with
   `git push origin fanotify.rb/v0.2.0`.
4. Open the **Release** workflow in GitHub Actions. Select the tag under
   **Use workflow from**, choose the matching `gem`, and supply the same `tag`.
5. The workflow tests both gems, verifies the tag points to the tested commit
   and matches the selected gem's version, checks both packages, and publishes
   only the selected gem using Trusted Publishing. No API key secret is needed.
6. Verify installation from RubyGems and add release notes from that gem's changelog.

Publish a compatible `fanotify.rb` release before publishing `fanotify_utils`
so its runtime dependency can be resolved by users. Existing historical `vVERSION`
tags remain valid history; releases using this layout require prefixed tags
that include the monorepo changes.
