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
      include Simple::Printer::Printable

      def type_=(type)
        @type = type
      end

      def artists=(artists)
        @artists = ArtistList.new(artists.map { |a| Artist.new(a) })
      end

      def extraartists=(artists)
        @extraartists = ArtistList.new(artists.map { |a| Artist.new(a) })
      end

      def sub_tracks=(sub_tracks)
        @sub_tracks = TrackList.new(sub_tracks.map { |t| Track.new(t) })
      end

      def artist
        @artists&.to_s
      end

      def to_s
        [
          @title || '-',
          @artists ? "(#{@artists})" : nil,
          !@duration ? "[#{@duration}]" : nil,
        ].compact.join(' ')
      end

      def printable
        [
          Simple::Printer::Field.new(
            label: [@type, @position].reject { |s| s.to_s.empty? }.join(' '),
            value: to_s,
            children: @sub_tracks),
        ]
      end

    end

  end

end