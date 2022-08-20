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
        @playlists = Playlists.new(root: $musicbox.playlists_dir)

        if @eq
          @equalizers = Equalizer.load_equalizers(dir: $musicbox.equalizers_dir, name: @eq)
          @equalizer_enabled = true
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
        @player = Player.new(
          audio_device: @audio_device,
          audio_exclusive: @audio_exclusive,
          mpv_log_level: @mpv_log_level,
          ignore_state: @ignore_state,
          dispatcher: @dispatcher,
          delegate: self)
        @dispatcher.set_timeout_handler(10) do
          # update_playlist
          # @delegate&.checkpoint
        end
        next_equalizer
        @dispatcher.run
      end

      def setup_interface
        @stty_old_params = `stty -g`.chomp
        at_exit {
          system('stty', @stty_old_params) if @stty_old_params
          @player.shutdown
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

      def play(playlist)
        @playlist = playlist
        @playlists << @playlist
        @playlist.save
        @player.start(@playlist.paths)
      end

      #
      # command callbacks
      #

      def play_random_album
        play(Playlist.playlist_for_random_album(id: 'album'))
      end

      def play_random_tracks
        play(Playlist.playlist_for_random_tracks(id: 'random-tracks', time: 60))
      end

      def play_album_for_current_track
        raise Error, "No current playlist" unless @playlist
        play(@playlist.playlist_for_album_of_current_track(id: 'album'))
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
              track.album,
              track.artist,
            ]
          end
        end
      end

      def toggle_equalizer
        @equalizer_enabled = !@equalizer_enabled
        set_equalizer
      end

      def next_equalizer
        if @equalizers
          @equalizer &&= @equalizers[@equalizers.index(@equalizer) + 1]
          @equalizer ||= @equalizers.first
          if @equalizer
            @player.set_audio_filter(@player.set_equalizer(@equalizer))
            puts "equalizer: %s <%s>" % [
              @equalizer&.name || 'none',
              @equalizer_enabled ? 'enabled' : 'disabled',
            ]
          end
        end
      end

      def quit
        Kernel.exit(0)
      end

      #
      # delegate methods
      #

      def state_did_change(state)
        puts "STATE: #{state}"
      end

      def playlist_pos_did_change(value)
        if @playlist
          @playlist.pos = value
          @playlist.save
          track_did_change
        end
      end

      def time_pos_did_change(value)
        if @playlist
          @playlist.time_pos = value
          # @playlist.save if @playlist.age > 10
        end
      end

      def volume_did_change(value)
        puts "VOLUME: #{value}"
      end

      def track_did_change
        track = @playlist.current_track
        unless track
          puts 'no current track playing'
          return
        end
        message = track.title
        subtitle = [track.artist, track.title].join(': ')
        script = <<~END
          display notification "#{message}" with title "MusicBox" subtitle "#{subtitle}"
        END
        run_command('osascript', input: script)
        system('clear')
        if track.cover
          MusicBox.show_image(
            file: track.cover,
            width: 'auto',
            height: 20,
            preserve_aspect_ratio: false)
          puts
        end
        Simple::Printer.print(
          ['Track', [track.track_num, track.track_count].join('/')],
          ['Title', track.title],
          ['Album', track.album],
          ['Artist', track.artist],
        )
        puts
        show_playlist
      end

      def checkpoint
        @playlist&.save
      end

    end

  end

end