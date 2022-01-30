class MusicBox

  module Commands

    class ShowArtists < SimpleCommand::Command

      attr_accessor :personal

      def run(args)
        $musicbox.show_artists
      end

    end

  end

end