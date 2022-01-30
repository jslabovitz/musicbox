class MusicBox

  class Discogs

    class Releases < Simple::Group

      def self.item_class
        Release
      end

      def self.search_fields
        @search_fields ||= [:title, :artist]
      end

    end

  end

end