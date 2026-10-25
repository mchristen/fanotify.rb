# frozen_string_literal: true

require_relative "lib/fanotify/version"

Gem::Specification.new do |spec|
  spec.name = "fanotify.rb"
  spec.version = Fanotify::VERSION
  spec.authors = ["Matt Christen"]
  spec.email = ["oss@christen.tech"]
  spec.homepage = "https://github.com/mchristen/fanotify.rb"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }
  spec.summary = "Thin Ruby bindings for Linux fanotify syscalls"
  spec.description = "Native bindings for fanotify_init(2) and fanotify_mark(2), with Linux fanotify constants."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*.rb", "ext/**/*.{c,h,rb}", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/fanotify/extconf.rb"]
end
