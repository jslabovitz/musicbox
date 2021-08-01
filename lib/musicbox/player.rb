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
      's' => :stop,
      'e' => :toggle_equalizer,
      'E' => :next_equalizer,
      'q' => :quit,
      '.' => :show_playlist,
      '?' => :show_keymap,
    }

    attr_accessor :albums
    attr_accessor :audio_device
    attr_accessor :audio_exclusive
    attr_accessor :mpv_log_level
    attr_accessor :equalizers
    attr_accessor :ignore_state
    attr_accessor :checkpoint_timeout
    attr_accessor :state_file
    attr_accessor :playlist_file
    attr_accessor :seek_seconds

    include SetParams

    def initialize(**params)
      set(
        {
          mpv_log_level: 'error',
          checkpoint_timeout: 10,
          state_file: '/tmp/musicbox.state.json',
          playlist_file: '/tmp/musicbox.playlist.m3u8',
          seek_seconds: 30,
          ignore_state: false,
        }.merge(params.compact)
      )
    end

    def state_file=(file)
      @state_file = Path.new(file)
    end

    def playlist_file=(file)
      @playlist_file = Path.new(file)
    end

    def play
      raise Error, "No albums to play" if @albums.nil? || @albums.empty?
      read_albums
      @dispatcher = IO::Dispatcher.new
      setup_interface
      setup_mpv
      next_equalizer
      restore_state unless @ignore_state
      puts "[ready]"
      @dispatcher.run
    end

    def setup_mpv
      @mpv = MPVClient.new(
        'msg-level' => "all=#{@mpv_log_level}",
        'audio-device' => @audio_device,
        'audio-exclusive' => @audio_exclusive ? 'yes' : 'no',
        'audio-display' => 'no',
        'vo' => 'null',
        'volume' => 100)
      @mpv.register_event('log-message') do |event|
        puts "%-6s | %-20s | %s" % [
          event['level'],
          event['prefix'],
          event['text'].strip,
        ]
      end
      @mpv.register_event('start-file') { |e| start_file(e) }
      @mpv.register_event('playback-restart') { |e| playback_restart(e) }
      @mpv.command('request_log_messages', @mpv_log_level) if @mpv_log_level
      @mpv.observe_property('playlist') do |name, value|
        update_playlist(value)
      end
      @mpv.observe_property('pause') do |name, value|
        puts '[%s]' % [value ? 'paused' : 'playing']
      end
      @dispatcher.add_io_handler(input: @mpv.socket) { |io| @mpv.process_response }
      @dispatcher.add_io_handler(exception: @mpv.socket) { |io| shutdown_mpv }
      @dispatcher.set_timeout_handler(@checkpoint_timeout) { save_state }
      at_exit { shutdown_mpv }
    end

    def shutdown_mpv
      if @mpv
        save_state
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

    def save_state
      state = {}
      if @current_tracks
        state['playlist'] = @current_tracks.map(&:path).map(&:to_s)
        if (pos = @mpv.get_property('playlist-pos')) && pos >= 0
          state['playlist-pos'] = pos
          state['time-pos'] = @mpv.get_property('time-pos')
        end
      end
      @state_file.dirname.mkpath unless @state_file.dirname.exist?
      @state_file.write(JSON.dump(state))
    end

    def restore_state
      if state_file.exist?
        state = JSON.load(state_file.read)
        if state['playlist']
          paths = state['playlist'].map do |path|
            path = Path.new(path)
            unless @album_for_track_path[path]
              puts "Invalid state: #{path} not in albums"
              reset_state
              return
            end
            path
          end
          play_tracks(paths,
            pos: state['playlist-pos'],
            time: state['time-pos'])
        end
      end
    end

    def reset_state
      @state_file.unlink
    end

    def play_tracks(tracks, pos: nil, time: nil)
      @playlist_file.dirname.mkpath
      @playlist_file.write(tracks.map { |t| t.respond_to?(:path) ? t.path : t }.join("\n"))
      @mpv.command('loadlist', @playlist_file.to_s)
      @future_playlist_pos = pos if pos && pos >= 0
      @future_time_pos = time if time && time > 0
    end

    def start_file(event)
      if @future_playlist_pos
        @mpv.set_property('playlist-pos', @future_playlist_pos)
        @future_playlist_pos = nil
      end
    end

    def playback_restart(event)
      if @future_time_pos
        @mpv.set_property('time-pos', @future_time_pos)
        @future_time_pos = nil
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

    def update_playlist(value)
      @current_track = @current_pos = @current_tracks = nil
      if value
        value.each_with_index do |entry, pos|
          track_path = Path.new(entry['filename'])
          album = @album_for_track_path[track_path] \
            or raise Error, "Can't determine album for track file: #{track_path}"
          track = album.tracks.find { |t| t.path == track_path } \
            or raise Error, "Can't determine track for track file: #{track_path}"
          if entry['current']
            @current_track = track
            @current_pos = pos
          end
          @current_tracks ||= []
          @current_tracks << track
        end
      end
      show_playlist
    end

    def set_equalizer(equalizer)
      puts "[equalizer: #{equalizer || 'none'}]"
      if equalizer
        equalizer.enabled = @equalizer_enabled
        @mpv.command('af', 'set', equalizer.to_af)
      end
    end

    #
    # commands called by interface
    #

    def quit
      Kernel.exit(0)
    end

    def play_next_track
      if @current_pos && @current_pos < @current_tracks.length - 1
        @mpv.command('playlist-next')
      else
        puts 'no next track'
      end
    end

    def play_previous_track
      if @current_pos && @current_pos > 0
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
      if @current_track
        album = @album_for_track_path[@current_track.path] \
          or raise Error, "Can't determine album for track file: #{track_path}"
        play_tracks(album.tracks)
      else
        puts "no current track"
      end
    end

    def toggle_pause
      if @current_track
        @mpv.set_property('pause', !@mpv.get_property('pause'))
      else
        puts "no current track"
      end
    end

    def skip_backward
      if @current_track
        @mpv.command('seek', -@seek_seconds)
      else
        puts "no current track"
      end
    end

    def skip_forward
      if @current_track
        @mpv.command('seek', @seek_seconds)
      else
        puts "no current track"
      end
    end

    def skip_to_beginning
      if @current_track
        @mpv.command('seek', 0, 'absolute-percent')
      else
        puts "no current track"
      end
    end

    def stop
      @mpv.command('stop')
      reset_state
    end

    def show_playlist
      system('clear')
      if @current_tracks
        if @current_track&.album&.has_cover?
          MusicBox.show_image(
            file: @current_track.album.cover_file,
            width: 'auto',
            height: 20,
            preserve_aspect_ratio: false)
          puts
        end
        @current_tracks.each_with_index do |track, i|
          puts '%1s %2d. %-40.40s | %-40.40s | %-40.40s' % [
            track == @current_track ? '>' : '',
            i + 1,
            track.title,
            track.album.title,
            track.album.artist,
          ]
        end
      else
        puts "no current tracks"
      end
    end

    def show_keymap
      Keymap.each do |key, command|
        puts "%-8s %s" % [key_description(key), command_description(command)]
      end
    end

    def toggle_equalizer
      @equalizer_enabled = !@equalizer_enabled
      set_equalizer(@current_equalizer)
    end

    def next_equalizer
      if @equalizers
        equalizer = @current_equalizer
        equalizer &&= @equalizers[@equalizers.index(equalizer) + 1]
        equalizer ||= @equalizers.first
        if equalizer != @current_equalizer
          @current_equalizer = equalizer
          set_equalizer(@current_equalizer)
        end
      end
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