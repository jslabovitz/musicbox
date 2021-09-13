class MusicBox

  module Commands

    class Csv < SimpleCommand::Command

      def run(args)
        print Collection::Album.csv_header
        $musicbox.find_albums(args).each do |album|
          print album.to_csv
        end
      end

    end

  end

end