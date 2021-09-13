class MusicBox

  module Commands

    class Update < SimpleCommand::Command

      def run(args)
        $musicbox.update_discogs
      end

    end

  end

end