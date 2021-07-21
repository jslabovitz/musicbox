class MusicBox

  class Catalog

    class Releases < Group

      def self.item_class
        Release
      end

      def self.search_fields
        @search_fields ||= [:title, :artist]
      end

    end

  end

end