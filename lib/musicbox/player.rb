class MusicBox

  class Player

    class RangeError < Error; end

    attr_accessor :audio_device
    attr_accessor :audio_exclusive
    attr_accessor :mpv_log_level
    attr_accessor :seek_seconds
    attr_accessor :volume
    attr_accessor :replay_gain
    attr_accessor :dispatcher

    include SetParams

    def initialize(**params)
      set(
        {
          mpv_log_level: 'error',
          seek_seconds: 30,
          volume: 100,
          replay_gain: 'album',
        }.merge(params.compact)
      )
      @mpv = MPVClient.new(
        'msg-level' => "all=#{@mpv_log_level}",
        'audio-device' => @audio_device,
        'audio-exclusive' => @audio_exclusive ? 'yes' : 'no',
        'replaygain' => @replay_gain,
        'audio-display' => 'no',
        'vo' => 'null',
        'volume' => @volume)
      @dispatcher.add_io_handler(input: @mpv.socket) { |io| @mpv.process_response }
      @dispatcher.add_io_handler(exception: @mpv.socket) { |io| raise Error, "Exception on #{io}" }
      @mpv.register_event('log-message') { |e| handle_log_message(e) }
      @mpv.command('request_log_messages', @mpv_log_level) if @mpv_log_level
      @mpv.register_event('start-file') { |e| handle_start_file(e) }
      @mpv.register_event('playback-restart') { |e| handle_playback_restart(e) }
      @mpv.observe_property('playlist-pos') { |n, v| playlist_pos_did_change(v) }
      @mpv.observe_property('time-pos') { |n, v| time_pos_did_change(v) }
      @mpv.observe_property('pause') { |n, v| pause_did_change(v) }
      @mpv.observe_property('volume') { |n, v| volume_did_change(v) }
      set_state(:ready)
    end

    def shutdown
      if @mpv
        @mpv.command('quit')
        @dispatcher.remove_io_handler(input: @mpv.socket, exception: @mpv.socket)
        @mpv.stop
        @mpv = nil
      end
      @dispatcher = nil
    end

    def start(playlist, playlist_pos: nil, time_pos: nil)
      @playlist = playlist
      @playlist_pos = nil
      playlist_path = Path.new('/tmp/mpv.playlist.m3u8')
      playlist_path.write(@playlist.join("\n"))
      @future_playlist_pos = (playlist_pos && playlist_pos >= 0) ? playlist_pos : nil
      @future_time_pos = (time_pos && time_pos > 0) ? time_pos : nil
      @mpv.command('loadlist', playlist_path.to_s)
    end

    def stop
      @mpv.command('stop')
      set_state(:stopped)
    end

    def skip_to_next_track
      raise RangeError, "No next track" unless next_track
      @mpv.command('playlist-next')
    end

    def skip_to_previous_track
      raise RangeError, "No previous track" unless previous_track
      @mpv.command('playlist-prev')
    end

    def toggle_pause
      raise RangeError, "No current track" unless current_track
      @mpv.set_property('pause', !@mpv.get_property('pause'))
    end

    def skip_backward
      raise RangeError, "No current track" unless current_track
      @mpv.command('seek', -@seek_seconds)
    end

    def skip_forward
      raise RangeError, "No current track" unless current_track
      @mpv.command('seek', @seek_seconds)
    end

    def skip_to_beginning
      raise RangeError, "No current track" unless current_track
      @mpv.command('seek', 0, 'absolute-percent')
    end

    def increase_volume
      @mpv.command('add', 'volume', 5)
    end

    def decrease_volume
      @mpv.command('add', 'volume', -5)
    end

    def set_audio_filter(filter)
      @mpv.command('af', 'set', filter)
    end

    def on_state_change(&block)
      @state_change_cb = block
    end

    def on_volume_change(&block)
      @volume_change_cb = block
    end

    def on_playlist_pos_change(&block)
      @playlist_pos_change_cb = block
    end

    def on_time_pos_change(&block)
      @time_pos_change_cb = block
    end

    private

    def current_track
      @playlist_pos && @playlist[@playlist_pos]
    end

    def next_track
      @playlist_pos && @playlist[@playlist_pos + 1]
    end

    def previous_track
      @playlist_pos && @playlist_pos > 0 && @playlist[@playlist_pos - 1]
    end

    def set_state(state)
      @state_change_cb&.call(state)
    end

    #
    # callbacks for events
    #

    def handle_log_message(event)
      warn "LOG: %-6s | %-20s | %s" % [
        event['level'],
        event['prefix'],
        event['text'].strip,
      ]
    end

    def handle_start_file(event)
# ;;warn "EVENT: #{event.inspect}"
      if @future_playlist_pos
        @mpv.set_property('playlist-pos', @future_playlist_pos)
        @future_playlist_pos = nil
      end
    end

    def handle_playback_restart(event)
# ;;warn "EVENT: #{event.inspect}"
      if @future_time_pos
        @mpv.set_property('time-pos', @future_time_pos)
        @future_time_pos = nil
      end
    end

    #
    # callbacks for properties
    #

    def playlist_pos_did_change(value)
# ;;warn "PROPERTY: #{__method__} => #{value.inspect}"
      @playlist_pos = (value >= 0) ? value : nil
      @playlist_pos_change_cb&.call(@playlist_pos)
    end

    def time_pos_did_change(value)
# ;;warn "PROPERTY: #{__method__} => #{value.inspect}"
      @time_pos_change_cb&.call(value)
    end

    def pause_did_change(value)
# ;;warn "PROPERTY: #{__method__} => #{value.inspect}"
      set_state(value ? :paused : :playing)
    end

    def volume_did_change(value)
# ;;warn "PROPERTY: #{__method__} => #{value.inspect}"
      @volume_change_cb&.call(value)
    end

  end

end