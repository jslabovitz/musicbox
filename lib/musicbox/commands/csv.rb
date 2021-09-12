class MusicBox

  module Commands

    class Csv < SimpleCommand::Command

      def run(args)
        $musicbox.csv(args)
      end

    end

  end

end