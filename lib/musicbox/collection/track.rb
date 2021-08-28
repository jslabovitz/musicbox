class MusicBox

  module Collection

    class Track < Sequel::Model

      many_to_one :album

      dataset_module do

        def from_path(path)
          path = Path.new(path)
          release_id = path.dirname.basename.to_s.to_i
          file = path.basename.to_s
          album = Album.where(release_id: release_id).first
          where(album_id: album.id, file: file).first
        end

      end

      def summary
        '%-8s | %-8s | %02d-%02d | %-60.60s | %-60.60s' % [
          id,
          album.release_id,
          disc_num, track_num,
          title,
          artist_name || '-',
        ]
      end

      def path
        album.dir / file
      end

    end

  end

end