class MusicBox

  module Commands

    class Play < SimpleCommand::Command

      attr_accessor :device
      attr_accessor :exclusive
      attr_accessor :mpv_log_level
      attr_accessor :eq
      attr_accessor :ignore_state

      def run(args)
        if @eq
          equalizers = Equalizer.load_equalizers(
            dir: $musicbox.equalizers_dir,
            name: @eq)
        else
          equalizers = nil
        end
        player = Player.new(
          albums: $musicbox.find_albums(args),
          equalizers: equalizers,
          audio_device: @device,
          audio_exclusive: @exclusive,
          mpv_log_level: @mpv_log_level,
          ignore_state: @ignore_state)
        player.play
      end

    end

  end

end