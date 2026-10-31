# frozen_string_literal: true

require "mkmf"

abort "fanotify requires Linux" unless RUBY_PLATFORM.include?("linux")
abort "sys/fanotify.h is required" unless have_header("sys/fanotify.h")
abort "fanotify_init(2) is unavailable" unless have_func("fanotify_init", "sys/fanotify.h")
abort "fanotify_mark(2) is unavailable" unless have_func("fanotify_mark", "sys/fanotify.h")
abort "name_to_handle_at(2) is unavailable" unless have_func("name_to_handle_at", "fcntl.h")

create_makefile("fanotify/fanotify")
