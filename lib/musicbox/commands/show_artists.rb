class MusicBox

  module Commands

    class ShowArtists < SimpleCommand::Command

      def run(args)
        $musicbox.show_artists
      end

    end

  end

end