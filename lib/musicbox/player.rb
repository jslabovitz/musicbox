class MusicBox

  class Player

    class RangeError < Error; end

    attr_accessor :musicbox
    attr_accessor :equalizers_dir
    attr_accessor :audio_device
    attr_accessor :audio_exclusive
    attr_accessor :mpv_log_level
    attr_accessor :seek_seconds
    attr_accessor :volume
    attr_accessor :replay_gain

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
    end

    def setup
      at_exit { shutdown }
      @playlists = Playlists.new(root: @musicbox.playlists_dir)
      @listens = Listens.new(root: @musicbox.listens_dir)
      setup_mpv
      setup_events
      setup_properties
      setup_equalizer
      setup_interface
      next_equalizer
      set_state(:ready)
      # restore_state
      ;;play_random_tracks
    end

    def setup_mpv
      @mpv = MPVClient.new(
        'msg-level' => "all=#{@mpv_log_level}",
        'audio-device' => @audio_device,
        'audio-exclusive' => @audio_exclusive ? 'yes' : 'no',
        'replaygain' => @replay_gain,
        'audio-display' => 'no',
        'vo' => 'null',
        'volume' => @volume)
      @dispatcher = IO::Dispatcher.new
      @dispatcher.add_io_handler(input: @mpv.socket) { |io| @mpv.process_response }
      @dispatcher.add_io_handler(exception: @mpv.socket) { |io| raise Error, "Exception on #{io}" }
    end

    def setup_events
      @mpv.register_event('log-message') do |event|
        warn "LOG: %-6s | %-20s | %s" % [
          event['level'],
          event['prefix'],
          event['text'].strip,
        ]
      end
      @mpv.command('request_log_messages', @mpv_log_level) if @mpv_log_level
      @mpv.register_event('start-file') do |event|
        # ;;warn "EVENT: #{event.inspect}"
        if @future_playlist_pos
          @mpv.set_property('playlist-pos', @future_playlist_pos)
          @future_playlist_pos = nil
        end
      end
      @mpv.register_event('playback-restart') do |event|
        # ;;warn "EVENT: #{event.inspect}"
        if @future_time_pos
          @mpv.set_property('time-pos', @future_time_pos)
          @future_time_pos = nil
        end
      end
    end

    def setup_properties
      @mpv.observe_property('playlist-pos') do |name, value|
        # ;;warn "PROPERTY: #{name} => #{value.inspect}"
        @playlist_pos = (value >= 0) ? value : nil
        if @playlist
          @playlist.pos = @playlist_pos
          @playlist.save
          if (track = @playlist.current_track)
            track.listened_at = Time.now
          end
        end
        playlist_pos_changed
      end
      @mpv.observe_property('time-pos') do |name, value|
        # ;;warn "PROPERTY: #{name} => #{value.inspect}"
        @time_pos = value
        if @playlist
          @playlist.time_pos = @time_pos
          # @playlist.save if @playlist.age > 10
          save_listen if @time_pos && @time_pos >= 4*60
        end
        time_pos_changed
      end
      @mpv.observe_property('percent-pos') do |name, value|
        # ;;warn "PROPERTY: #{name} => #{value.inspect}"
        @percent_pos = value
        if @playlist
          save_listen if @percent_pos && @percent_pos >= 50
        end
        percent_pos_changed
      end
      @mpv.observe_property('pause') do |name, value|
        # ;;warn "PROPERTY: #{name} => #{value.inspect}"
        set_state(value ? :paused : :playing)
      end
      @mpv.observe_property('volume') do |name, value|
        # ;;warn "PROPERTY: #{name} => #{value.inspect}"
        @volume = value
        volume_changed
      end
    end

    def setup_equalizer
      if @eq && @equalizers_dir
        equalizers = AutoEQLoader.load_equalizers(@equalizers_dir)
        @equalizers = equalizers.select { |e| e.name =~ /#{Regexp.quote(@eq)}/i }
        @equalizer_enabled = !@equalizers.empty?
      else
        @equalizers = []
      end
    end

    def setup_interface
      # implemented in subclass
    end

    def shutdown
      shutdown_mpv
      shutdown_interface
      @dispatcher = nil
    end

    def shutdown_mpv
      if @mpv
        @mpv.command('quit')
        @dispatcher.remove_io_handler(input: @mpv.socket, exception: @mpv.socket)
        @mpv.stop
        @mpv = nil
      end
    end

    def shutdown_interface
      # implemented in subclass
    end

    def run
      setup
      @dispatcher.run
      shutdown
    end

    def restore_state
      # if @ignore_state
      #   @playlist.reset
      # else
      #   begin
      #     @playlist = Playlist.restore(NAME)
      #   rescue Error => _
      #     reset_state
      #   end
      # end
    end

    def play(playlist)
      @playlist = playlist
      @playlists << @playlist
      @playlist.save
      m3u8_file = @playlist.dir / 'list.m3u8'
      @playlist.write_m3u8(m3u8_file)
      @future_playlist_pos = (@playlist.pos && @playlist.pos >= 0) ? @playlist.pos : nil
      @future_time_pos = (@playlist.time_pos && @playlist.time_pos > 0) ? @playlist.time_pos : nil
      @mpv.command('loadlist', m3u8_file.to_s)
    end

    def stop
      @playlist = nil
      @mpv.command('stop')
      set_state(:stopped)
    end

    def play_random_album
      play(Playlist.playlist_for_random_album(
        collection: @musicbox.collection,
        id: 'temp'))
    end

    def play_random_tracks
      play(Playlist.playlist_for_random_tracks(
        collection: @musicbox.collection,
        id: 'temp',
        number: 10))
    end

    def play_album_for_current_track
      track = @playlist&.current_track or raise RangeError, 'No current track'
      album = track.album or raise Error, 'No current album'
      play(Playlist.playlist_for_album(
        collection: @musicbox.collection,
        id: 'temp',
        album: album))
    end

    def skip_to_next_track
      raise RangeError, "No next track" unless @playlist&.next_track
      @mpv.command('playlist-next')
    end

    def skip_to_previous_track
      raise RangeError, "No previous track" unless @playlist&.previous_track
      @mpv.command('playlist-prev')
    end

    def toggle_pause
      raise RangeError, "No current track" unless @playlist&.current_track
      @mpv.set_property('pause', !@mpv.get_property('pause'))
    end

    def skip_backward
      raise RangeError, "No current track" unless @playlist&.current_track
      @mpv.command('seek', -@seek_seconds)
    end

    def skip_forward
      raise RangeError, "No current track" unless @playlist&.current_track
      @mpv.command('seek', @seek_seconds)
    end

    def skip_to_beginning
      raise RangeError, "No current track" unless @playlist&.current_track
      @mpv.command('seek', 0, 'absolute-percent')
    end

    def increase_volume
      @mpv.command('add', 'volume', 5)
    end

    def decrease_volume
      @mpv.command('add', 'volume', -5)
    end

    def toggle_equalizer
      if @equalizer
        @equalizer_enabled = !@equalizer_enabled
        set_equalizer
      end
    end

    def next_equalizer
      if @equalizers
        @equalizer &&= @equalizers[@equalizers.index(@equalizer) + 1]
        @equalizer ||= @equalizers.first
        set_equalizer
      end
    end

    def set_equalizer
      if @equalizer
        @mpv.command('af', 'set', @equalizer.to_s(@equalizer_enabled))
        equalizer_changed
      end
    end

    def set_state(state)
      @state = state
      state_changed
    end

    def save_listen
      if (track = @playlist&.current_track) && !track.listen_saved
        listen = Listen.new(
          id: track.listened_at.to_i,
          listened_at: track.listened_at,
          artist_name: track.artist_name,
          album_title: track.album.title,
          album_id: track.album.id,
          track_title: track.title,
          track_num: track.track_num,
          track_disc: track.disc_num,
        )
        @listens << listen
        listen.save
        track.listen_saved = true
        warn "[saved listen]"
      end
    end

    #
    # status-changed (to override in subclass)
    #

    def playlist_pos_changed
    end

    def time_pos_changed
    end

    def percent_pos_changed
    end

    def state_changed
    end

    def volume_changed
    end

    def equalizer_changed
    end

  end

end