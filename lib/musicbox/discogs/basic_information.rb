class MusicBox

  class Discogs

    class BasicInformation

      attr_accessor :id
      attr_accessor :master_id
      attr_accessor :master_url
      attr_accessor :resource_url
      attr_accessor :thumb
      attr_accessor :cover_image
      attr_accessor :title
      attr_accessor :year
      attr_reader   :formats
      attr_accessor :labels
      attr_reader   :artists
      attr_accessor :genres
      attr_accessor :styles

      include SetParams

      def formats=(formats)
        @formats = formats.map { |f| Format.new(f) }
      end

      def artists=(artists)
        @artists = ArtistList.new(artists.map { |a| Artist.new(a) })
      end

      def artist
        @artists.to_s
      end

    end

  end

end