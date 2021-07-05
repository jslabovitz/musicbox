module MusicBox

  class Catalog

    class Collection < Group

      def self.item_class
        CollectionItem
      end

    end

  end

end