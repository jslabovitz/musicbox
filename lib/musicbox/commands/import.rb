class MusicBox

  module Commands

    class Import < SimpleCommand::Command

      def run(args)
        $musicbox.import(args)
      end

    end

  end

end