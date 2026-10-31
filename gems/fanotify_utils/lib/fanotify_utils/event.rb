# frozen_string_literal: true

module FanotifyUtils
  class Event
    TYPES = {
      created: Fanotify::FAN_CREATE,
      modified: Fanotify::FAN_MODIFY,
      attributes_changed: Fanotify::FAN_ATTRIB,
      closed_after_write: Fanotify::FAN_CLOSE_WRITE,
      deleted: Fanotify::FAN_DELETE,
      moved_from: Fanotify::FAN_MOVED_FROM,
      moved_to: Fanotify::FAN_MOVED_TO,
      deleted_self: Fanotify::FAN_DELETE_SELF,
      moved_self: Fanotify::FAN_MOVE_SELF
    }.freeze

    attr_reader :path, :mask, :pid, :types

    def initialize(path:, mask:, pid:)
      @path = path.dup.freeze
      @mask = mask
      @pid = pid
      @types = TYPES.filter_map { |name, flag| name if mask & flag != 0 }.freeze
      freeze
    end

    def directory? = mask & Fanotify::FAN_ONDIR != 0
  end
end
