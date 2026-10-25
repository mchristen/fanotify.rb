# frozen_string_literal: true

require "rake/testtask"
require "rbconfig"

desc "Build the native extension"
task :compile do
  Dir.chdir("ext/fanotify") do
    ruby "extconf.rb" unless File.exist?("Makefile")
    sh RbConfig::CONFIG.fetch("MAKE", "make")
  end
  mkdir_p "lib/fanotify"
  cp "ext/fanotify/fanotify.#{RbConfig::CONFIG.fetch('DLEXT')}", "lib/fanotify/"
end

Rake::TestTask.new(:test => :compile) do |task|
  task.libs << "lib"
  task.pattern = "test/**/*_test.rb"
end

task default: :test
