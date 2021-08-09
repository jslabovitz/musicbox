class MusicBox

  class Collection

    class Track < Sequel::Model

      many_to_one :album

      def summary
        '%-6s | %-6s | %02d-%02d | %-60.60s | %-60.60s' % [
          id,
          album.id,
          disc_num, track_num,
          title,
          artist_name || '-',
        ]
      end

    end

  end

end