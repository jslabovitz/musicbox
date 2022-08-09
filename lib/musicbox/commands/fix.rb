class MusicBox

  module Commands

    class Fix < SimpleCommand::Command

      def run(args)
        $musicbox.update_artists
      end

    end

  end

end