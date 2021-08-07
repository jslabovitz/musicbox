class MusicBox

  class Discogs

    class Track

      attr_accessor :type
      attr_accessor :position
      attr_accessor :title
      attr_accessor :duration
      attr_accessor :extraartists
      attr_accessor :artists
      attr_accessor :sub_tracks

      include SetParams

      def type_=(type)
        self.type = type
      end

      def artists=(artists)
        @artists = artists.map { |a| Artist.new(a) }
      end

      def extraartists=(artists)
        @extraartists = artists.map { |a| Artist.new(a) }
      end

      def sub_tracks=(sub_tracks)
        @sub_tracks = sub_tracks.map { |t| Track.new(t) }
      end

      def artist
        @artists ? Artist.join(@artists) : nil
      end

    end

  end

end