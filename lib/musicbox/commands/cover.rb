class MusicBox

  module Commands

    class Cover < SimpleCommand::Command

      def run(args)
        $musicbox.cover(args)
      end

    end

  end

end