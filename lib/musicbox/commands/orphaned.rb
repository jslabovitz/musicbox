class MusicBox

  module Commands

    class Orphaned < SimpleCommand::Command

      def run(args)
        $musicbox.orphaned(args)
      end

    end

  end

end