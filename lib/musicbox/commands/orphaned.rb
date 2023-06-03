class MusicBox

  module Commands

    class Orphaned < SimpleCommand::Command

      def run(args)
        @musicbox.orphaned
      end

    end

  end

end