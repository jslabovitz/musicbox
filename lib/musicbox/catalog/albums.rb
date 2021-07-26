class MusicBox

  class Catalog

    class Albums < Group

      def self.item_class
        Album
      end

      def self.search_fields
        @search_fields ||= [:title, :artist]
      end

    end

  end

end