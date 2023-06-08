class MusicBox

  class Player

    class ConsolePlayer < Player

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

      def initialize(**params)
        super
      end

      def setup_interface
        @stty_old_params = `stty -g`.chomp
        system('stty', 'cbreak', '-echo')
        @dispatcher.add_io_handler(input: STDIN) { |io| handle_key(io.sysread(1)) }
      end

      def shutdown_interface
        @dispatcher&.remove_io_handler(input: STDIN)
        system('stty', @stty_old_params) if @stty_old_params
      end

      def handle_key(key)
        case @key_state
        when nil
          if key == "\e"
            @key_state = :esc
          elsif (command = Keymap[key])
            if respond_to?(command)
              puts command_description(command)
              begin
                send(command)
              rescue Error => e
                puts "error: #{e}"
              end
            else
              puts 'unknown command: %p' % command
            end
          else
            puts 'unknown key: %p' % key
          end
        when :esc
          @key_state = :left_bracket
        when :left_bracket
          case key
          when 'A'  # up
            increase_volume
          when 'B'  # down
            decrease_volume
          else
            puts 'unknown escape key: %p' % key
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

      #
      # command callbacks (see also commands in base Player)
      #

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

      def quit
        shutdown
      end

      def show_keymap
        Keymap.each do |key, command|
          puts "%-8s %s" % [key_description(key), command_description(command)]
        end
      end

      ## end of command callbacks

      def display_notification(title:, subtitle:, message:)
        script = <<~END
          display notification "#{message}" with title "#{title}" subtitle "#{subtitle}"
        END
        begin
          run_command('osascript', input: script)
        rescue => e
          warn "Couldn't show notification: #{e}"
        end
      end

      def show_info
        system('clear')
        if @playlist
          if (track = @playlist&.current_track)
            display_notification(
              title: 'MusicBox',
              subtitle: track.artist_name,
              message: '%s (%s)' % [track.title, track.album.title])
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
          end
          show_playlist
        else
          puts 'no playlist'
        end
      end

      #
      # status-changed methods
      #

      def playlist_changed
        show_info
      end

      def playlist_pos_changed
        show_info
      end

      def state_changed
        puts "STATE: #{@state}"
      end

      def volume_changed
        puts "VOLUME: #{@volume}"
      end

      def equalizer_changed
        puts "EQUALIZER: %s <%s>" % [
          @equalizer&.name || 'none',
          @equalizer_enabled ? 'enabled' : 'disabled',
        ]
      end

    end

  end

end