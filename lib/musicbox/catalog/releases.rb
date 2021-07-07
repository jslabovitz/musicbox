class MusicBox

  class Catalog

    class Releases < Group

      def self.item_class
        Release
      end

    end

  end

end