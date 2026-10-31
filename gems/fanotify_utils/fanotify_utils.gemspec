# frozen_string_literal: true

require_relative "lib/fanotify_utils/version"

Gem::Specification.new do |spec|
  spec.name = "fanotify_utils"
  spec.version = FanotifyUtils::VERSION
  spec.authors = ["Matt Christen"]
  spec.email = ["oss@christen.tech"]
  spec.homepage = "https://github.com/mchristen/fanotify.rb"
  spec.metadata = {
    "source_code_uri" => "#{spec.homepage}/tree/main/gems/fanotify_utils",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "changelog_uri" => "#{spec.homepage}/blob/main/gems/fanotify_utils/CHANGELOG.md"
  }
  spec.summary = "Application-level utilities for Linux fanotify"
  spec.description = "Recursive directory change notifications built on the fanotify.rb syscall bindings."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.add_dependency "fanotify.rb", "~> 0.2.0"
end
