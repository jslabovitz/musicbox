class MusicBox

  class Discogs

    class ArtistList < Array

      def to_s
        map { |a|
          [a.name, (a.join == ',' ? '' : ' '), a.join].join
        }.
        join(' ').
        squeeze(' ').
        strip
      end

    end

  end

end