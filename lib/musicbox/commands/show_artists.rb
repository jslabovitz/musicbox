class MusicBox

  module Commands

    class ShowArtists < SimpleCommand::Command

      attr_accessor :personal

      def run(args)
        $musicbox.find_artists(args).each do |artist|
          next if @personal && !artist.personal?
          puts artist.summary
        end
      end

    end

  end

end