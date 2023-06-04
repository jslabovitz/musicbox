class MusicBox

  module Commands

    class Play < SimpleCommand::Command

      Keymap = {
        'a' => :play_random_album,
        't' => :play_random_tracks,
        'r' => :play_album_for_current_track,
        'n' => :skip_to_next_track,
        'p' => :skip_to_previous_track,
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

      attr_accessor :audio_device
      attr_accessor :audio_exclusive
      attr_accessor :mpv_log_level
      attr_accessor :eq
      attr_accessor :ignore_state

      def run(args)
        @playlists_dir = @musicbox.root_dir / 'playlists'
        @listens_dir = @musicbox.root_dir / 'listens'
        @playlists = Player::Playlists.new(root: @playlists_dir)
        @listens = Player::Listens.new(root: @listens_dir)

        if @eq && @musicbox.equalizers_dir&.exist?
          @equalizers = Equalizer.load_equalizers(dir: @musicbox.equalizers_dir, name: @eq)
          @equalizer_enabled = !@equalizers.empty?
        else
          @equalizers = []
        end

        # if @ignore_state
        #   @playlist.reset
        # else
        #   begin
        #     @playlist = Playlist.restore(NAME)
        #   rescue Error => _
        #     reset_state
        #   end
        # end

        @dispatcher = IO::Dispatcher.new
        setup_interface
        setup_player
        @dispatcher.run
      end

      def setup_interface
        @stty_old_params = `stty -g`.chomp
        at_exit {
          system('stty', @stty_old_params) if @stty_old_params
          @player&.shutdown
        }
        system('stty', 'cbreak', '-echo')
        @dispatcher.add_io_handler(input: STDIN) { |io| handle_key(io.sysread(1)) }
      end

      def handle_key(key)
        case @key_state
        when nil
          if key == "\e"
            @key_state = :esc
          elsif (command = Keymap[key])
            puts command_description(command)
            if @player.respond_to?(command)
              begin
                @player.send(command)
              rescue Player::RangeError => e
                puts "error: #{e}"
              end
            elsif respond_to?(command)
              begin
                send(command)
              rescue Error => e
                puts "error: #{e}"
              end
            else
              puts "unknown command: %p" % command
            end
          else
            puts "unknown key: %p" % key
          end
        when :esc
          @key_state = :left_bracket
        when :left_bracket
          case key
          when 'A'  # up
            @player.increase_volume
          when 'B'  # down
            @player.decrease_volume
          else
            puts "unknown escape key: %p" % key
          end
          @key_state = nil
        else
          raise Error, "Unknown state: #{@key_state.inspect}"
        end
      end

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

      def setup_player
        @player = Player.new(
          audio_device: @audio_device,
          audio_exclusive: @audio_exclusive,
          mpv_log_level: @mpv_log_level,
          ignore_state: @ignore_state,
          dispatcher: @dispatcher)
        @player.on_state_change do |state|
          puts "STATE: #{state}"
        end
        @player.on_volume_change do |value|
          puts "VOLUME: #{value}"
        end
        @player.on_playlist_pos_change do |value|
          if @playlist
            @playlist.track_pos = value
            @playlist.save
            show_track_change(@playlist.current_track)
          end
        end
        @player.on_time_pos_change do |time_pos|
          if @playlist
            @playlist.time_pos = time_pos
            # @playlist.save if @playlist.age > 10
            save_listen if time_pos && time_pos >= 4*60
          end
        end
        @player.on_percent_pos_change do |percent|
          if @playlist
            save_listen if percent && percent >= 50
          end
        end
        next_equalizer
      end

      def play(playlist)
        @playlist = playlist
        @playlists << @playlist
        @playlist.save
        @player.start(@playlist.paths)
      end

      def show_track_change(track)
        if track
          track.listened_at = Time.now
          show_track_notification(track)
          show_track_info(track)
        else
          puts 'no current track playing'
        end
      end

      def show_track_notification(track)
        subtitle = track.artist_name
        message = "%s (%s)" % [track.title, track.album.title]
        script = <<~END
          display notification "#{message}" with title "MusicBox" subtitle "#{subtitle}"
        END
        begin
          run_command('osascript', input: script)
        rescue => e
          warn "Couldn't show notification: #{e}"
        end
      end

      def show_track_info(track)
        system('clear')
        if track.album.has_cover?
          puts ITerm.show_image_file(track.album.cover_file, width: 'auto', height: 20)
          puts
        end
        Simple::Printer.print(
          ['Track', [track.track_num, track.album.tracks.count].join('/')],
          ['Title', track.title],
          ['Album', track.album.title],
          ['Artist', track.artist_name],
        )
        puts
        show_playlist
      end

      def set_equalizer
        if @equalizer
          @player.set_audio_filter(@equalizer.to_af(@equalizer_enabled))
          puts "equalizer: %s <%s>" % [
            @equalizer&.name || 'none',
            @equalizer_enabled ? 'enabled' : 'disabled',
          ]
        end
      end

      def save_listen
        if (track = @playlist.current_track) && !track.listen_saved
          listen = Player::Listen.new(
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
      # command callbacks
      #

      def play_random_album
        play(Player::Playlist.playlist_for_random_album(
          collection: @musicbox.collection,
          id: 'temp'))
      end

      def play_random_tracks
        play(Player::Playlist.playlist_for_random_tracks(
          collection: @musicbox.collection,
          id: 'temp',
          number: 10))
      end

      def play_album_for_current_track
        raise Error, "No current playlist" unless @playlist
        album = @playlist.current_track&.album or raise Error, "No current album"
        play(Player::Playlist.playlist_for_album(
          collection: @musicbox.collection,
          id: 'temp',
          album: album))
      end

      def show_keymap
        Keymap.each do |key, command|
          puts "%-8s %s" % [key_description(key), command_description(command)]
        end
      end

      def show_playlist
        if @playlist
          @playlist.tracks.each_with_index do |track, i|
            puts '%1s %-40.40s | %-40.40s | %-40.40s' % [
              (track == @playlist.current_track) ? '>' : ' ',
              track.title,
              track.album.title,
              track.artist_name,
            ]
          end
        end
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

      def quit
        Kernel.exit(0)
      end

    end

  end

end