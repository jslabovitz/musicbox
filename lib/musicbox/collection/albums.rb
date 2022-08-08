class MusicBox

  class Collection

    class Albums < Simple::Group

      def self.item_class
        Album
      end

      def self.search_fields
        @search_fields ||= [:title, :artist_name]
      end

      def self.convert_id(id)
        id.to_i
      end

    end

  end

end