module MusicBox

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

    attr_accessor :catalog
    attr_accessor :releases
    attr_accessor :audio_device
    attr_accessor :mpv_log_level

    def initialize(**params)
      {
        mpv_log_level: 'error',
      }.merge(params).each { |k, v| send("#{k}=", v) }
      @playlist_file = Path.new('/tmp/mpv_playlist')
    end

    def play
      @releases ||= @catalog.releases.items
      @releases.select!(&:ripped?)
      raise Error, "No releases to play" if @releases.empty?
      read_tracks
      @dispatcher = IO::Dispatcher.new
      setup_interface
      setup_mpv
      puts "[ready]"
      @dispatcher.run
    end

    def setup_mpv
      @mpv = MPVClient.new(
        'mpv-log-level' => @mpv_log_level,
        'audio-device' => @audio_device,
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
      @mpv.command('af', 'add', "equalizer=#{@equalizer.join(':')}") if @equalizer
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

    def read_tracks
      @release_for_track_path = {}
      @releases.each do |release|
        release.rip.tracks.each do |track|
          @release_for_track_path[track.path] = release
        end
      end
    end

    def random_album
      @releases.shuffle.first
    end

    def random_tracks(length:)
      length.times.map do
        random_album.rip.tracks.shuffle.first
      end
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
      play_tracks(random_album.rip.tracks)
    end

    def play_random_tracks
      play_tracks(random_tracks(length: 10))
    end

    def play_album_for_current_track
      if @properties.playlist_position
        entry = @properties.playlist[@properties.playlist_position]
        track_path = Path.new(entry.filename)
        release = @release_for_track_path[track_path] \
          or raise Error, "Can't determine release for track file: #{track_path}"
        play_tracks(release.rip.tracks)
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
      if @properties.playlist
        @properties.playlist.each_with_index do |entry, i|
          track_path = Path.new(entry.filename)
          release = @release_for_track_path[track_path] \
            or raise Error, "Can't determine release for track file: #{track_path}"
          track = release.rip.tracks.find { |t| t.path == track_path } \
            or raise Error, "Can't determine track for track file: #{track_path}"
          puts '%1s %2d. %-40.40s | %-40.40s | %-40.40s' % [
            entry.current ? '>' : '',
            i + 1,
            track.title,
            release.title,
            release.artist,
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

    #
    # callbacks from MPV
    #

    def property_changed(name, value)
# ;;puts "property: <#{name}> => #{value.inspect}" unless name == 'time-pos'
      key = ObservedProperties[name] or raise
      @properties[key] = value
      show_playlist if name == 'playlist-pos'
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