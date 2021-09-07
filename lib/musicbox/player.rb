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
      @play_state = :stopped
      @playlist = nil
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
      @dispatcher = IO::Dispatcher.new
      setup_interface
      setup_mpv
      next_equalizer
      @dispatcher.set_timeout_handler(@checkpoint_timeout) { save_state }
      unless @ignore_state
        begin
          restore_state
        rescue Error => e
          show_error("Invalid state: #{path} not in albums")
          reset_state
        end
      end
      show_status('ready')
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
      at_exit { shutdown_mpv }
      @dispatcher.add_io_handler(input: @mpv.socket) { |io| @mpv.process_response }
      @dispatcher.add_io_handler(exception: @mpv.socket) { |io| shutdown_mpv }
      @mpv.register_event('log-message') { |e| show_log(e) }
      @mpv.command('request_log_messages', @mpv_log_level) if @mpv_log_level
      @mpv.register_event('start-file') { |e| start_file(e) }
      @mpv.register_event('playback-restart') { |e| playback_restart(e) }
      @mpv.observe_property('playlist') { |n, v| playlist_changed(v) }
      @mpv.observe_property('playlist-pos') { |n, v| playlist_pos_changed(v) }
      @mpv.observe_property('pause') { |n, v| pause_changed(v) }
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
          show_status(command_description(command))
          send(command)
        else
          show_error("unknown key: %p" % key)
        end
      end
    end

    def save_state
      state = {}
      if (playlist = @mpv.get_property('playlist'))
        state['playlist'] = playlist.map { |e| e['filename'] }
        if (pos = @mpv.get_property('playlist-pos')) && pos >= 0
          state['playlist-pos'] = pos
          state['time-pos'] = @mpv.get_property('time-pos') rescue nil
        end
      end
      @state_file.dirname.mkpath unless @state_file.dirname.exist?
      @state_file.write(JSON.dump(state))
    end

    def restore_state
      if state_file.exist?
        state = JSON.load(state_file.read)
        if state['playlist']
          play_tracks(state['playlist'].map { |p| @albums.track_from_path(p) },
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
      @playlist_file.write(tracks.map(&:path).join("\n"))
      @mpv.command('loadlist', @playlist_file.to_s)
      @future_playlist_pos = pos if pos && pos >= 0
      @future_time_pos = time if time && time > 0
    end

    def set_equalizer(equalizer)
      show_equalizer(equalizer || 'none')
      if equalizer
        equalizer.enabled = @equalizer_enabled
        @mpv.command('af', 'set', equalizer.to_af)
      end
    end

    #
    # callbacks for events
    #

    def start_file(event)
# ;;puts "EVENT: #{event.inspect}"
      if @future_playlist_pos
        @mpv.set_property('playlist-pos', @future_playlist_pos)
        @future_playlist_pos = nil
      end
    end

    def playback_restart(event)
# ;;puts "EVENT: #{event.inspect}"
      if @future_time_pos
        @mpv.set_property('time-pos', @future_time_pos)
        @future_time_pos = nil
      end
    end

    #
    # callbacks for properties
    #

    def playlist_changed(value)
# ;;puts "PROPERTY: #{__method__} => #{value.inspect}"
      @playlist = value
      @current_track = @current_pos = nil
      @playlist.each_with_index do |entry, i|
        if entry['current']
          @current_track = @albums.track_from_path(entry['filename'])
          @current_pos = i
          break
        end
      end
      save_state
      show_playlist
    end

    def playlist_pos_changed(value)
# ;;puts "PROPERTY: #{__method__} => #{value.inspect}"
      if value >= 0
        entry = @mpv.get_property('playlist')[value] or raise
        @current_track = @albums.track_from_path(entry['filename'])
        @current_pos = value
      else
        @current_track = @current_pos = nil
      end
      save_state
      show_current_track
    end

    def pause_changed(value)
# ;;puts "PROPERTY: #{__method__} => #{value.inspect}"
      @play_state = value ? :paused : :playing
      show_play_state
    end

    #
    # commands called by interface
    #

    def quit
      Kernel.exit(0)
    end

    def play_next_track
      if @current_pos && @current_pos < @playlist.length - 1
        @mpv.command('playlist-next')
      else
        show_status('no next track')
      end
    end

    def play_previous_track
      if @current_pos && @current_pos > 0
        @mpv.command('playlist-prev')
      else
        show_status('no previous track')
      end
    end

    def play_random_album
      play_tracks(@albums.random_album.tracks)
    end

    def play_random_tracks
      play_tracks(@albums.random_tracks(length: 10))
    end

    def play_album_for_current_track
      if @current_track
        play_tracks(@current_track.album.tracks)
      else
        show_status('no current track')
      end
    end

    def toggle_pause
      if @current_track
        @mpv.set_property('pause', !@mpv.get_property('pause'))
      else
        show_status('no current track')
      end
    end

    def skip_backward
      if @current_track
        @mpv.command('seek', -@seek_seconds)
      else
        show_status('no current track')
      end
    end

    def skip_forward
      if @current_track
        @mpv.command('seek', @seek_seconds)
      else
        show_status('no current track')
      end
    end

    def skip_to_beginning
      if @current_track
        @mpv.command('seek', 0, 'absolute-percent')
      else
        show_status('no current track')
      end
    end

    def stop
      @mpv.command('stop')
      reset_state
      @play_state = :stopped
    end

    def show_current_track
      if (track = @current_track)
        album = track.album
        if album.has_cover?
          MusicBox.show_image(
            file: album.cover_file,
            width: 'auto',
            height: 20,
            preserve_aspect_ratio: false)
          puts
        end
        puts MusicBox.info_to_s(
          [
            ['Disc', track.disc_num || '-'],
            ['Track', [track.track_num, album.tracks.count].join('/')],
            ['Title', track.title],
            ['Album', album.title],
            ['Artist', [album.artist_name, track.artist_name].compact.uniq.join(' / ')],
          ]
        )
        puts
      end
    end

    def show_playlist
      if @playlist
        @playlist.each_with_index do |entry, i|
          track = @albums.track_from_path(entry['filename'])
          album = track.album
          puts '%1s%1s %2d. %-40.40s | %-40.40s | %-40.40s' % [
            entry['current'] ? '=' : '',
            entry['playing'] ? '>' : '',
            i + 1,
            track.title,
            album.title,
            album.artist_name,
          ]
        end
      else
        show_status('no current playlist')
      end
      puts
    end

    def show_equalizer(equalizer)
      puts "EQUALIZER: #{equalizer}"
    end

    def show_play_state
      puts "PLAY STATE: #{@play_state}"
    end

    def show_error(msg)
      puts "ERROR: #{msg}"
    end

    def show_status(status)
      puts "STATUS: #{status}"
    end

    def show_log(event)
      puts "LOG: %-6s | %-20s | %s" % [
        event['level'],
        event['prefix'],
        event['text'].strip,
      ]
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