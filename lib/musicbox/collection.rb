class MusicBox

  class Collection

    attr_accessor :root_dir
    attr_accessor :albums
    attr_accessor :artists

    include SetParams

    def initialize(params={})
      set(params)
      raise Error, "root_dir not specified" unless @root_dir
      raise Error, "root_dir #{@root_dir.to_s.inspect} doesn't exist" unless @root_dir.exist?
      @albums = Albums.new(root: @root_dir / 'albums')
      @artists = Artists.new(root: @root_dir / 'artists')
    end

    #FIXME: dup code?

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
        cover_file: cover_file&.to_s)
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