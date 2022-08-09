class MusicBox

  module Commands

    class ShowArtists < SimpleCommand::Command

      attr_accessor :personal

      def run(args)
        $musicbox.find_artists(args).each do |artist|
          if @personal
            next unless artist.personal?
          end
          puts artist.summary
        end
      end

    end

  end

end