class MusicBox

  class Collection

    def self.setup
      # @db = Sequel.sqlite('database.sqlite')
      @db = Sequel.sqlite
      if false
        @db.loggers << Logger.new($stderr)
        @db.sql_log_level = :info
      end
      unless @db.tables.include?(:artists)
        @db.create_table :artists do
          primary_key :id
          String      :key, null: false
          String      :name, null: false, unique: true
        end
      end
      unless @db.tables.include?(:albums)
        @db.create_table :albums do
          primary_key :id
          foreign_key :artist_id, :artists, null: false
          String      :title, null: false
          String      :artist_name, null: false
          Integer     :year
          Integer     :release_id
          String      :cover_file
        end
      end
      unless @db.tables.include?(:tracks)
        @db.create_table :tracks do
          primary_key :id
          foreign_key :album_id, :albums, null: false
          String      :title, null: false
          String      :artist_name
          Integer     :track_num, null: false
          Integer     :disc_num, null: false
          String      :file, null: false
        end
      end
      Path.new(__FILE__).dirname.glob('collection/*.rb').each { |p| require p.to_s }
    end

    def self.import_album(old_album)
      # ;;puts old_album.summary
      artist_name = old_album.artist || old_album.tracks.first.artist
      artist = Artist[{key: old_album.artist_key}]
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

  end

end