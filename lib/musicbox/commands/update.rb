class MusicBox

  module Commands

    class Update < SimpleCommand::Command

      def run(args)
        $musicbox.update
      end

    end

  end

end