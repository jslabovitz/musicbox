class MusicBox

  class Collection

    # DB = Sequel.sqlite('sqlite://database')
    DB = Sequel.sqlite
    if false
      DB.loggers << Logger.new($stderr)
      DB.sql_log_level = :info
    end
    DB.create_table :artists do
      primary_key :id
      String      :key, null: false
      String      :name, null: false, unique: true
    end
    DB.create_table :albums do
      primary_key :id
      foreign_key :artist_id, :artists, null: false
      String      :title, null: false
      String      :artist_name, null: false
      Integer     :year
      Integer     :release_id
      String      :cover_file
    end
    DB.create_table :tracks do
      primary_key :id
      foreign_key :album_id, :albums, null: false
      String      :title, null: false
      String      :artist_name
      Integer     :track_num, null: false
      Integer     :disc_num, null: false
      String      :file, null: false
    end

    def self.import_album(old_album)
      # ;;puts old_album.summary
      artist = Artist[{key: old_album.artist_key}]
      artist_name = old_album.artist || old_album.tracks.first.artist
      unless artist
        artist = Artist.create(
          key: old_album.artist_key,
          name: artist_name)
      end
      # ;;pp(artist: artist)
      cover_file = old_album.dir.glob('cover.{jpg,png}').first
      album = artist.add_album(
        title: old_album.title,
        artist_name: artist_name,
        year: old_album.year,
        release_id: old_album.id,
        cover_file: cover_file ? cover_file.to_s : nil)
      # ;;pp(album: album)
      old_album.tracks.each do |old_track|
        track = album.add_track(
          title: old_track.title,
          artist_name: old_track.artist,
          track_num: old_track.track,
          disc_num: old_track.disc || 1,
          file: old_track.file)
        # ;;pp(track: track)
      end
    end

    #
    # Artist
    #

    class Artist < Sequel::Model

      one_to_many :albums

    end

    #
    # Album
    #

    class Album < Sequel::Model

      many_to_one :artist
      one_to_many :tracks

      dataset_module do

        def search(args)
          dataset = self
          args.each do |selector|
            dataset = case selector
            when /^[\d,]+$/
              ids = selector.split(',').map(&:to_i)
              dataset.where(id: ids)
            else
              raise Error, "Unknown selector: #{selector}"
            end
          end
          dataset
        end

        def with_covers
          where { !cover_file.nil? }
        end

        def without_covers
          where { cover_file.nil? }
        end

        def all_albums_released_in_year(year)
          where(year: year).
          all
        end

      end

      def summary
        '%-6s | %-4s | %-4s | %-60.50s | %-60.60s' % [
          id,
          artist.key,
          year || '-',
          artist_name,
          title,
        ]
      end

      def album_dir(root)
        root / release_id.to_s
      end

      def cover_path(dir)
        dir / cover_file
      end

      def has_cover?
        !cover_file.nil?
      end

      def to_label
        {
          artist: artist_name,
          artist_key: artist.key,
          title: title,
          year: year,
          id: release_id,
        }
      end

      def self.csv_header
        %w[ID year artist title].to_csv
      end

      def to_csv
        [release_id, year, artist_name, title].to_csv
      end

    end

    #
    # Track
    #

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