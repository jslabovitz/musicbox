class MusicBox

  module Commands

    class Label < SimpleCommand::Command

      def run(args)
        $musicbox.label(args)
      end

    end

  end

end