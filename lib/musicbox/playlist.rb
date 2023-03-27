class MusicBox

  class Playlist < Simple::Group::Item

    attr_accessor :tracks
    attr_accessor :pos
    attr_accessor :time_pos

    include Simple::Printer::Printable

    def initialize(**params)
      @pos = @time_pos = nil
      @tracks = []
      super
    end

    def inspect
      "<#{self.class}>"
    end

    def to_h
      super.merge(
        tracks: @tracks.map(&:to_h),
        pos: @pos,
        time_pos: @time_pos,
      )
    end

    def paths
      @tracks.map(&:path)
    end

    def current_track
      @pos && @tracks[@pos]
    end

  end

end