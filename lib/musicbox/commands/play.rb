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
          @equalizer_enabled = !@equalizers.empty?
        else
          @equalizers = []
        end

        @listen_brainz = ListenBrainz.new

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
          dispatcher: @dispatcher)
        @player.on_state_change do |state|
          puts "STATE: #{state}"
        end
        @player.on_volume_change do |value|
          puts "VOLUME: #{value}"
        end
        @player.on_playlist_pos_change do |value|
          if @playlist
            @playlist.pos = value
            @playlist.save
            show_track_change(@playlist.current_track)
          end
        end
        @player.on_time_pos_change do |time_pos|
          if @playlist
            @playlist.time_pos = time_pos
            # @playlist.save if @playlist.age > 10
            if time_pos && time_pos >= 4*60 && (track = @playlist.current_track) && !track.saved_listen
              save_listen(track)
            end
          end
        end
        @player.on_percent_pos_change do |percent|
          if @playlist
            if percent && percent >= 50 && (track = @playlist.current_track) && !track.saved_listen
              save_listen(track)
            end
          end
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

      def show_track_change(track)
        if track
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
          MusicBox.show_image(
            file: track.album.cover_file,
            width: 'auto',
            height: 20,
            preserve_aspect_ratio: false)
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

      def save_listen(track)
        ;;puts "submitting listen: %s" % [track.artist, track.album, track.title].join(' - ')
        begin
          @listen_brainz.submit_listen(make_submission(track))
          track.saved_listen = true
        rescue ListenBrainz::Error => e
          warn "Failed to submit listen: #{e}"
        end
      end

      def make_submission(track)
        {
          listen_type: 'single',
          payload: [
            {
              listened_at: Time.now.to_i,
              track_metadata: make_track_metadata(track),
            }
          ],
        }
      end

      def make_track_metadata(track)
        # unused: mb_albumid
        {
          artist_name: track.artist,
          release_name: track.album,
          track_name: track.title,

          additional_info: {
            # A list of MusicBrainz Artist IDs, one or more Artist IDs may be included here.
            # If you have a complete MusicBrainz artist credit that contains multiple Artist IDs, include them all in this list.
            artist_mbids: [track.mb_albumartistid, track.mb_artistid].compact,

            # A MusicBrainz Release Group ID of the release group this recording was played from.
            release_group_mbid: track.mb_releasegroupid,

            # A MusicBrainz Release ID of the release this recording was played from.
            release_mbid: track.mb_releasetrackid,

            # A MusicBrainz Recording ID of the recording that was played.
            # recording_mbid: ???,

            # A MusicBrainz Track ID associated with the recording that was played.
            track_mbid: track.mb_trackid,

            # A list of MusicBrainz Work IDs that may be associated with this recording.
            work_mbids: [track.mb_workid].compact,
          }.delete_if { |k,v| v.kind_of?(Array) && v.empty? }.compact,
        }
      end

      def show_listens
        ;;pp(listens: @listen_brainz.listens)
      end

      def show_similar_users
        ;;pp(listens: @listen_brainz.similar_users)
      end

      def show_recommendations
        ;;pp(recommendations: @listen_brainz.recommendations)
      end

      #
      # command callbacks
      #

      def play_random_album
        play($musicbox.collection.playlist_for_random_album(id: 'album'))
      end

      def play_random_tracks
        # play($musicbox.collection.playlist_for_random_tracks(id: 'random-tracks', time: 60))
        play($musicbox.collection.playlist_for_random_tracks(id: 'random-tracks', number: 10))
      end

      def play_album_for_current_track
        raise Error, "No current playlist" unless @playlist
        album = @playlist.current_track&.album or raise Error, "No current album"
        play($musicbox.collection.playlist_for_album(id: 'album', album: album))
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