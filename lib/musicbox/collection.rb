class MusicBox

  class Collection

    attr_accessor :root_dir
    attr_accessor :refs_dir
    attr_accessor :albums
    attr_accessor :artists

    include SetParams

    def initialize(params={})
      set(params)
      raise Error, "root_dir not specified" unless @root_dir
      raise Error, "root_dir #{@root_dir.to_s.inspect} doesn't exist" unless @root_dir.exist?
      @albums = Albums.new(root: @root_dir / 'albums', refs_dir: @refs_dir)
      @artists = Artists.new(root: @root_dir / 'artists')
      link_artists
    end

    def inspect
      "<#{self.class}>"
    end

    def link_artists
      @albums.items.each do |album|
        album.artist = @artists[album.artist_id] or raise "#{album.id}: Can't find artist ID #{album.artist_id.inspect}"
      end
    end

    def random_album
      @albums.items.sample
    end

    def playlist_for_random_tracks(id:, number: nil, time: nil)
      tracks = Set.new
      if number
        while tracks.count < number
          tracks << random_album.random_track
        end
      elsif time
        ;;raise Error, "Can't handle :time yet"
      else
        raise Error, "Must specify either :number or :time"
      end
      Playlist.new(tracks: tracks.to_a, id: id)
    end

    def playlist_for_random_album(id:)
      Playlist.new(tracks: random_album.tracks, id: id)
    end

    def playlist_for_album(id:, album:)
      Playlist.new(tracks: album.tracks, id: id)
    end

  end

end