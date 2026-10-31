# frozen_string_literal: true

require "rake"

GEMS = %w[fanotify.rb fanotify_utils].freeze

%w[test build].each do |operation|
  desc "#{operation.capitalize} both gems"
  task operation do
    GEMS.each do |name|
      Dir.chdir(File.join(__dir__, "gems", name)) do
        ruby "-rrake", "-e", "Rake.application.run", "--", operation
      end
    end
  end
end

desc "Compile the low-level native extension"
task :compile do
  Dir.chdir(File.join(__dir__, "gems", "fanotify.rb")) do
    ruby "-rrake", "-e", "Rake.application.run", "--", "compile"
  end
end

task default: :test
