class MusicBox

  module Commands

    class Play < Command

      attr_accessor :audio_device
      attr_accessor :audio_exclusive
      attr_accessor :mpv_log_level
      attr_accessor :eq
      attr_accessor :ignore_state

      def run(args)
        super
        if args.empty?
          album = nil
        else
          albums = @musicbox.find_albums(args)
          warn "only playing first found album!" if albums.count > 1
          album = albums.sort.first
        end
        Player::ConsolePlayer.new(
          album: album,
          musicbox: @musicbox,
          audio_device: @audio_device,
          audio_exclusive: @audio_exclusive,
          mpv_log_level: @mpv_log_level,
          eq: @eq,
          equalizers_dir: @musicbox.equalizers_dir,
          ignore_state: @ignore_state,
        ).run
      end

    end

  end

end