class MusicBox

  module Commands

    class ShowArtists < Command

      attr_accessor :personal

      def run(args)
        super
        @musicbox.find_artists(args).each do |artist|
          next if @personal == true && !artist.personal?
          next if @personal == false && artist.personal?
          puts artist.summary
        end
      end

    end

  end

end