module MusicBox

  class Catalog

    class Albums < Group

      def self.item_class
        Album
      end

      def update_info(albums, yes: false)
        albums.each do |album|
          album.validate
          album.update_info(yes: yes)
        end
      end

      def new_album(id, args={})
        new_item(id, args)
      end

    end

  end

end