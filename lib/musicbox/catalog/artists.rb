module MusicBox

  class Catalog

    class Artists < Group

      def self.item_class
        Artist
      end

    end

  end

end