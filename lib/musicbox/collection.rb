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

  end

end