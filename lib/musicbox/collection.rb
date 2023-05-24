class MusicBox

  class Collection

    attr_accessor :root_dir
    attr_accessor :albums_dir
    attr_accessor :artists_dir
    attr_accessor :refs_dir
    attr_accessor :albums
    attr_accessor :artists

    include SetParams

    def initialize(params={})
      set(params)
      raise Error, "root_dir not specified" unless @root_dir
      raise Error, "root_dir #{@root_dir.to_s.inspect} doesn't exist" unless @root_dir.exist?
      @albums_dir = @root_dir / 'albums'
      @artists_dir = @root_dir / 'artists'
      @albums = Albums.new(root: @albums_dir, refs_dir: @refs_dir)
      @artists = Artists.new(root: @artists_dir)
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

  end

end