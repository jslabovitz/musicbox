class MusicBox

  module Commands

    class Play < SimpleCommand::Command

      option :device
      option :exclusive
      option :mpv_log_level
      option :eq
      option :ignore_state

      def run(args)
        if @eq
          equalizers = Equalizer.load_equalizers(
            dir: $musicbox.equalizers_dir,
            name: @eq)
        else
          equalizers = nil
        end
        player = Player.new(
          albums: $musicbox.collection.albums,
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