class MusicBox

  module Commands

    class Play < SimpleCommand::Command

      option :device
      option :exclusive
      option :mpv_log_level
      option :eq
      option :ignore_state

      def run(args)
        $musicbox.play(args,
          audio_device: @device,
          audio_exclusive: @exclusive,
          mpv_log_level: @mpv_log_level,
          equalizer_name: @eq,
          ignore_state: @ignore_state)
      end

    end

  end

end