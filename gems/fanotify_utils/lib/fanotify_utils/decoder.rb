# frozen_string_literal: true

module FanotifyUtils
  class InvalidEventError < StandardError; end
  class QueueOverflowError < StandardError; end

  # Decodes only the FID notification format requested by Watcher. No FDs are
  # delivered in this mode, and no permission responses are requested.
  class Decoder
    Record = Struct.new(:mask, :pid, :parent, :name, :object, keyword_init: true)

    def self.decode(buffer)
      records = []
      offset = 0
      while offset < buffer.bytesize
        if buffer.bytesize - offset < Fanotify::FAN_EVENT_METADATA_LEN
          raise InvalidEventError, "truncated event metadata"
        end
        length, version, _pad, metadata_length, mask, fd, pid =
          buffer.byteslice(offset, Fanotify::FAN_EVENT_METADATA_LEN).unpack("LCCSQll")
        if version != Fanotify::FANOTIFY_METADATA_VERSION ||
           metadata_length < Fanotify::FAN_EVENT_METADATA_LEN || length < metadata_length ||
           length > buffer.bytesize - offset
          raise InvalidEventError, "invalid event version or length"
        end
        raise QueueOverflowError, "fanotify queue overflowed; rescan the watched tree" if mask & Fanotify::FAN_Q_OVERFLOW != 0
        raise InvalidEventError, "expected a FID notification group" unless fd == Fanotify::FAN_NOFD

        record = Record.new(mask: mask, pid: pid)
        cursor = offset + metadata_length
        while cursor < offset + length
          raise InvalidEventError, "truncated info header" if offset + length - cursor < 4

          type, _pad, size = buffer.byteslice(cursor, 4).unpack("CCS")
          raise InvalidEventError, "invalid info length" if size < 4 || size > offset + length - cursor

          if [Fanotify::FAN_EVENT_INFO_TYPE_FID, Fanotify::FAN_EVENT_INFO_TYPE_DFID_NAME].include?(type)
            raise InvalidEventError, "truncated file handle" if size < 20

            bytes, handle_type = buffer.byteslice(cursor + 12, 8).unpack("Ll")
            raise InvalidEventError, "invalid file handle length" if bytes > size - 20

            key = [handle_type, buffer.byteslice(cursor + 20, bytes)].freeze
            if type == Fanotify::FAN_EVENT_INFO_TYPE_FID
              record.object = key
            else
              name = buffer.byteslice(cursor + 20 + bytes, size - 20 - bytes)
              terminator = name.index("\0")
              raise InvalidEventError, "unterminated entry name" unless terminator

              record.parent = key
              record.name = name.byteslice(0, terminator).force_encoding(Encoding.find("filesystem"))
              if record.name.empty? || record.name.include?("/") || record.name == ".."
                raise InvalidEventError, "invalid directory entry name"
              end
            end
          end
          cursor += size
        end
        records << record
        offset += length
      end
      records
    end
  end
  private_constant :Decoder
end
