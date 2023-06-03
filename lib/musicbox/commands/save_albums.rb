class MusicBox

  module Commands

    class SaveAlbums < SimpleCommand::Command

      def run(args)
        @musicbox.find_albums(args).each do |album|
          @musicbox.collection.albums.save_item(album)
        end
      end

    end

  end

end