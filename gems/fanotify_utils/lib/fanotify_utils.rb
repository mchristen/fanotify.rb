# frozen_string_literal: true

require "fanotify"
require_relative "fanotify_utils/version"
require_relative "fanotify_utils/event"
require_relative "fanotify_utils/decoder"
require_relative "fanotify_utils/watcher"

module FanotifyUtils
  def self.watch(path, recursive: true, &block)
    watcher = Watcher.new(path, recursive: recursive)
    return watcher unless block

    begin
      watcher.each(&block)
    ensure
      watcher.close
    end
  end
end
