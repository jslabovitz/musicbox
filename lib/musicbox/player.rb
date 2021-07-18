class MusicBox

  class Player

    Keymap = {
      'a' => :play_random_album,
      't' => :play_random_tracks,
      'r' => :play_album_for_current_track,
      'n' => :play_next_track,
      'p' => :play_previous_track,
      ' ' => :toggle_pause,
      '<' => :skip_backward,
      '>' => :skip_forward,
      '^' => :skip_to_beginning,
      'e' => :toggle_equalizer,
      'E' => :next_equalizer,
      'q' => :quit,
      '.' => :show_playlist,
      '?' => :show_keymap,
    }
    ObservedProperties = {
      'playlist' => :playlist,
      'playlist-pos' => :playlist_position,
      'pause' => :pause_state,
      'time-pos' => :time_position,
    }
    SeekSeconds = 30

    attr_accessor :albums
    attr_accessor :audio_device
    attr_accessor :audio_exclusive
    attr_accessor :mpv_log_level
    attr_accessor :equalizers

    def initialize(**params)
      {
        mpv_log_level: 'error',
      }.merge(params).each { |k, v| send("#{k}=", v) }
      @playlist_file = Path.new('/tmp/mpv_playlist')
    end

    def play
      raise Error, "No albums to play" if @albums.nil? || @albums.empty?
      read_albums
      @dispatcher = IO::Dispatcher.new
      setup_interface
      setup_mpv
      puts "[ready]"
      play_random_album
      @dispatcher.run
    end

    def setup_mpv
      @mpv = MPVClient.new(
        'mpv-log-level' => @mpv_log_level,
        'audio-device' => @audio_device,
        'audio-exclusive' => @audio_exclusive ? 'yes' : 'no',
        'audio-display' => 'no',
        'vo' => 'null',
        'volume' => 100)
      @mpv.register_event('log-message') do |event|
        ;;pp(log: event)
      end
      @mpv.command('request_log_messages', @mpv_log_level) if @mpv_log_level
      @properties = HashStruct.new
      ObservedProperties.each do |name, key|
        @mpv.observe_property(name) { |n, v| property_changed(n, v) }
      end
      if @equalizers
        @equalizer_enabled = true
        next_equalizer
      end
      @dispatcher.add_io_handler(input: @mpv.socket) do |io|
        @mpv.process_response
      end
      @dispatcher.add_io_handler(exception: @mpv.socket) do |io|
        shutdown_mpv
      end
      at_exit { shutdown_mpv }
    end

    def shutdown_mpv
      if @mpv
        @mpv.command('quit')
        @dispatcher.remove_io_handler(input: @mpv.socket, exception: @mpv.socket)
        @mpv.stop
        @mpv = nil
      end
    end

    def setup_interface
      @stty_old_params = `stty -g`.chomp
      at_exit { system('stty', @stty_old_params) }
      system('stty', 'cbreak', '-echo')
      @dispatcher.add_io_handler(input: STDIN) do |io|
        key = io.sysread(1)
        if (command = Keymap[key])
          puts "[#{command_description(command)}]"
          send(command)
        else
          puts "unknown key: %p" % key
        end
      end
    end

    def read_albums
      @album_for_track_path = {}
      @albums.each do |album|
        album.tracks.each do |track|
          @album_for_track_path[track.path] = album
        end
      end
    end

    def random_album
      @albums.shuffle.first
    end

    def random_tracks(length:)
      tracks = Set.new
      while tracks.length < length
        tracks << random_album.tracks.shuffle.first
      end
      tracks.to_a
    end

    def playlist_changed(value)
      @current_track = @playlist = nil
      if @properties.playlist
        @playlist = @properties.playlist.map do |entry|
          track_path = Path.new(entry.filename)
          album = @album_for_track_path[track_path] \
            or raise Error, "Can't determine album for track file: #{track_path}"
          track = album.tracks.find { |t| t.path == track_path } \
            or raise Error, "Can't determine track for track file: #{track_path}"
          @current_track = track if entry.current
          track
        end
      end
      show_playlist
    end

    #
    # commands called by interface
    #

    def quit
      Kernel.exit(0)
    end

    def play_next_track
      if @properties.playlist_position && @properties.playlist_position < @properties.playlist.count - 1
        @mpv.command('playlist-next')
      else
        puts 'no next track'
      end
    end

    def play_previous_track
      if @properties.playlist_position && @properties.playlist_position > 0
        @mpv.command('playlist-prev')
      else
        puts 'no previous track'
      end
    end

    def play_random_album
      play_tracks(random_album.tracks)
    end

    def play_random_tracks
      play_tracks(random_tracks(length: 10))
    end

    def play_album_for_current_track
      if @properties.playlist_position
        entry = @properties.playlist[@properties.playlist_position]
        track_path = Path.new(entry.filename)
        album = @album_for_track_path[track_path] \
          or raise Error, "Can't determine album for track file: #{track_path}"
        play_tracks(album.tracks)
      else
        puts "no current track"
      end
    end

    def toggle_pause
      @mpv.set_property('pause', !@properties.pause_state)
    end

    def skip_backward
      if @properties.time_position && @properties.time_position > 0
        @mpv.command('seek', -SeekSeconds)
      end
    end

    def skip_forward
      if @properties.time_position
        @mpv.command('seek', SeekSeconds)
      end
    end

    def skip_to_beginning
      if @properties.time_position && @properties.time_position > 0
        @mpv.command('seek', 0, 'absolute-percent')
      end
    end

    def show_playlist
      if @playlist
        system('clear')
        if @current_track
          @current_track.album.show_cover(width: 'auto', height: 20, preserve_aspect_ratio: false)
          puts
        end
        @playlist.each_with_index do |track, i|
          puts '%1s %2d. %-40.40s | %-40.40s | %-40.40s' % [
            track == @current_track ? '>' : '',
            i + 1,
            track.title,
            track.album.title,
            track.album.artist,
          ]
        end
      end
    end

    def show_keymap
      Keymap.each do |key, command|
        puts "%-8s %s" % [key_description(key), command_description(command)]
      end
    end

    def play_tracks(tracks)
      @playlist_file.dirname.mkpath
      @playlist_file.write(tracks.map(&:path).join("\n"))
      @mpv.command('loadlist', @playlist_file.to_s)
    end

    def toggle_equalizer
      @equalizer_enabled = !@equalizer_enabled
      set_current_equalizer
    end

    def next_equalizer
      if @equalizers
        @current_equalizer &&= @equalizers[@equalizers.index(@current_equalizer) + 1]
        @current_equalizer ||= @equalizers.first
        set_current_equalizer
      end
    end

    def set_current_equalizer
      if @current_equalizer
        puts "[equalizer: %s <%s>]" % [
          @current_equalizer.name,
          @equalizer_enabled ? 'enabled' : 'disabled',
        ]
        @mpv.command('af', 'set', @current_equalizer.to_s(enabled: @equalizer_enabled))
      end
    end

    #
    # callbacks from MPV
    #

    def property_changed(name, value)
# ;;pp(name => value) unless name == 'time-pos'
      key = ObservedProperties[name] or raise
      @properties[key] = value
      send("#{key}_changed", value) rescue NoMethodError
    end

    private

    def key_description(key)
      case key
      when ' '
        'space'
      else
        key
      end
    end

    def command_description(command)
      command.to_s.gsub('_', ' ')
    end

  end

end