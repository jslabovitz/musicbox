class MusicBox

  module Commands

    class Fix < SimpleCommand::Command

      def run(args)
        $musicbox.fix(args)
      end

    end

  end

end