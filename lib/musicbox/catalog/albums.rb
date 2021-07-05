module MusicBox

  class Catalog

    class Albums < Group

      def self.item_class
        Album
      end

      def new_album(id, args={})
        new_item(id, args)
      end

    end

  end

end