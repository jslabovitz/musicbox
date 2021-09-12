class MusicBox

  module Commands

    class Dir < SimpleCommand::Command

      def run(args)
        $musicbox.dir(args)
      end

    end

  end

end