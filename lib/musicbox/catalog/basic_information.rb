class MusicBox

  class Catalog

    class BasicInformation

      attr_accessor :id
      attr_accessor :master_id
      attr_accessor :master_url
      attr_accessor :resource_url
      attr_accessor :thumb
      attr_accessor :cover_image
      attr_accessor :title
      attr_accessor :year
      attr_accessor :formats
      attr_accessor :labels
      attr_accessor :artists
      attr_accessor :genres
      attr_accessor :styles

      include SetParams

      def formats=(formats)
        @formats = formats.map { |f| Format.new(f) }
      end

      def artists=(artists)
        @artists = artists.map { |a| Artist.new(a) }
      end

      def artist
        Artist.join(@artists)
      end

      def artist_key
        @artists.first.key
      end

    end

  end

end