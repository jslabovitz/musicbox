class MusicBox

  class Collection

    class Artists < Group

      def self.item_class
        Artist
      end

      def self.search_fields
        @search_fields ||= [:name]
      end

    end

  end

end