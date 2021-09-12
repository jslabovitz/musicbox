class MusicBox

  module Commands

    class Open < SimpleCommand::Command

      def run(args)
        $musicbox.open(args)
      end

    end

  end

end