class MusicBox

  class Catalog

    class Albums < Group

      def self.item_class
        Album
      end

      def self.search_fields
        @search_fields ||= [:title, :artist]
      end

      def new_album(id, args={})
        new_item(id, args)
      end

    end

  end

end