class MusicBox

  module Commands

    class SaveAlbums < Command

      def run(args)
        super
        @musicbox.find_albums(args).each do |album|
          @musicbox.collection.albums.save_item(album)
        end
      end

    end

  end

end