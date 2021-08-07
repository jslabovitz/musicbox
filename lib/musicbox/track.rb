class MusicBox

  class Track

    attr_accessor :title
    attr_accessor :artist
    attr_accessor :track
    attr_accessor :disc
    attr_accessor :album
    attr_accessor :file
    attr_accessor :tags

    include SetParams

    def file=(file)
      @file = Path.new(file)
    end

    def path
      @album.dir / @file
    end

    def load_tags
      @tags ||= Tags.load(path)
    end

    def save_tags
      @tags.save(path)
    end

    def update_tags
      load_tags
      @tags.update(
        {
          title: @title,
          album: @album.title,
          track: @track,
          disc: @disc,
          discs: @album.discs,
          artist: @artist || @album.artist,
          album_artist: @album.artist,
          grouping: @album.title,
          year: @album.year,
        }.reject { |k, v| v.to_s.empty? }
      )
    end

    def to_h
      {
        title: @title,
        artist: @artist,
        track: @track,
        disc: @disc,
        file: @file.to_s,
      }.compact
    end

  end

end