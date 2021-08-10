class MusicBox

  module Collection

    class Track < Sequel::Model

      many_to_one :album

      def summary
        '%-8s | %-8s | %02d-%02d | %-60.60s | %-60.60s' % [
          id,
          album.release_id,
          disc_num, track_num,
          title,
          artist_name || '-',
        ]
      end

    end

  end

end