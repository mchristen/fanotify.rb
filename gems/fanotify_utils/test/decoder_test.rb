# frozen_string_literal: true

require_relative "test_helper"

class DecoderTest < Minitest::Test
  include EventBuffers

  def setup
    @directory = Dir.mktmpdir("fanotify-decode")
    @decoder = FanotifyUtils.const_get(:Decoder, false)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_decodes_multiple_events_and_variable_length_records
    info = fid_info(@directory, "first") + [99, 0, 8].pack("CCS") + "abcd"
    data = event_buffer(Fanotify::FAN_CREATE, info) +
           event_buffer(Fanotify::FAN_MODIFY, fid_info(@directory, "second"))
    records = @decoder.decode(data)
    assert_equal %w[first second], records.map(&:name)
    assert_equal [1, [File.stat(@directory).ino].pack("Q")], records.first.parent
    assert_equal Process.pid, records.first.pid
  end

  def test_reports_queue_overflow
    assert_raises(FanotifyUtils::QueueOverflowError) do
      @decoder.decode(event_buffer(Fanotify::FAN_Q_OVERFLOW))
    end
  end

  def test_rejects_truncated_metadata_and_records
    valid = event_buffer(Fanotify::FAN_CREATE, fid_info(@directory, "file"))
    [valid.byteslice(0, 10), valid.byteslice(0, valid.bytesize - 1)].each do |data|
      assert_raises(FanotifyUtils::InvalidEventError) { @decoder.decode(data) }
    end
    bad_info = [2, 0, 65535].pack("CCS")
    assert_raises(FanotifyUtils::InvalidEventError) do
      @decoder.decode(event_buffer(Fanotify::FAN_CREATE, bad_info))
    end
  end

  def test_rejects_names_that_could_escape_the_watched_directory
    ["..", "../outside", "a/b", ""].each do |name|
      assert_raises(FanotifyUtils::InvalidEventError) do
        @decoder.decode(event_buffer(Fanotify::FAN_CREATE, fid_info(@directory, name)))
      end
    end
  end

  def test_validates_handle_lengths_and_metadata_version
    info = fid_info(@directory, "name")
    info[12, 4] = [65535].pack("L")
    assert_raises(FanotifyUtils::InvalidEventError) do
      @decoder.decode(event_buffer(Fanotify::FAN_CREATE, info))
    end
    data = event_buffer(Fanotify::FAN_MODIFY)
    data.setbyte(4, 255)
    assert_raises(FanotifyUtils::InvalidEventError) { @decoder.decode(data) }
  end

  def test_parent_and_object_handles_are_decoded_independently_of_record_order
    object_path = File.join(@directory, "object")
    Dir.mkdir(object_path)
    parent = fid_info(@directory, "file")
    object = fid_info(object_path, type: 1)
    [parent + object, object + parent].each do |info|
      record = @decoder.decode(event_buffer(Fanotify::FAN_MODIFY, info)).first
      assert_equal "file", record.name
      assert_equal [1, [File.stat(@directory).ino].pack("Q")], record.parent
      assert_equal [1, [File.stat(object_path).ino].pack("Q")], record.object
    end
  end

  def test_self_events_have_an_object_handle_without_a_parent_or_name
    data = event_buffer(Fanotify::FAN_MOVE_SELF | Fanotify::FAN_ONDIR,
                        fid_info(@directory, type: 1))
    record = @decoder.decode(data).first
    assert_nil record.parent
    assert_nil record.name
    assert_equal [1, [File.stat(@directory).ino].pack("Q")], record.object
  end

  def test_extended_metadata_is_skipped_using_metadata_length
    data = event_buffer(Fanotify::FAN_CREATE, "ext!" + fid_info(@directory, "file"))
    data[6, 2] = [28].pack("S")
    assert_equal "file", @decoder.decode(data).first.name
  end

  def test_rejects_invalid_event_and_info_boundaries
    valid = event_buffer(Fanotify::FAN_CREATE, fid_info(@directory, "file"))
    cases = {
      metadata_too_short: [6, [23].pack("S")],
      event_shorter_than_metadata: [0, [23].pack("L")],
      event_past_buffer: [0, [valid.bytesize + 1].pack("L")],
      zero_info_size: [26, [0].pack("S")],
      short_info_size: [26, [3].pack("S")]
    }
    cases.each do |name, (offset, bytes)|
      data = valid.dup
      data[offset, bytes.bytesize] = bytes
      assert_raises(FanotifyUtils::InvalidEventError, name.to_s) { @decoder.decode(data) }
    end
    assert_raises(FanotifyUtils::InvalidEventError) do
      @decoder.decode(event_buffer(Fanotify::FAN_CREATE, "\0\0".b))
    end
    assert_raises(FanotifyUtils::InvalidEventError) do
      @decoder.decode(event_buffer(Fanotify::FAN_CREATE, [2, 0, 4].pack("CCS")))
    end
  end

  def test_rejects_unterminated_names_and_descriptor_based_records
    info = fid_info(@directory, "name").byteslice(0...-1)
    info[2, 2] = [info.bytesize].pack("S")
    error = assert_raises(FanotifyUtils::InvalidEventError) do
      @decoder.decode(event_buffer(Fanotify::FAN_CREATE, info))
    end
    assert_match(/unterminated/, error.message)
    assert_raises(FanotifyUtils::InvalidEventError) do
      @decoder.decode(event_buffer(Fanotify::FAN_MODIFY, "".b, fd: 42))
    end
  end

  def test_preserves_filename_bytes_including_non_utf8_names
    ["a name with spaces", "résumé", "bad-\xff".b].each do |name|
      record = @decoder.decode(event_buffer(Fanotify::FAN_CREATE, fid_info(@directory, name))).first
      assert_equal name.b, record.name.b
      assert_equal Encoding.find("filesystem"), record.name.encoding
    end
  end
end
