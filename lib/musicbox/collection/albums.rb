class MusicBox

  class Collection

    class Albums < Simple::Group

      def self.item_class
        Album
      end

      def self.search_fields
        @search_fields ||= [:title, :artist_name]
      end

    end

  end

end