class MusicBox

  class Discogs

    class Collection < Simple::Group

      def self.item_class
        CollectionItem
      end

    end

  end

end