class MusicBox

  class Playlist < Simple::Group::Item

    attr_accessor :tracks
    attr_accessor :track_pos
    attr_accessor :time_pos

    include Simple::Printer::Printable

    def self.playlist_for_random_tracks(collection:, id:, number: nil, time: nil)
      tracks = Set.new
      if number
        while tracks.count < number
          tracks << collection.random_album.random_track
        end
      elsif time
        ;;raise Error, "Can't handle :time yet"
      else
        raise Error, "Must specify either :number or :time"
      end
      new(tracks: tracks.to_a, id: id)
    end

    def self.playlist_for_random_album(collection:, id:)
      new(tracks: collection.random_album.tracks, id: id)
    end

    def self.playlist_for_album(collection:, id:, album:)
      new(tracks: album.tracks, id: id)
    end

    def initialize(**params)
      @track_pos = @time_pos = nil
      @tracks = []
      super
    end

    def inspect
      "<#{self.class}>"
    end

    def to_h
      super.merge(
        tracks: @tracks.map(&:to_h),
        track_pos: @track_pos,
        time_pos: @time_pos,
      )
    end

    def paths
      @tracks.map(&:path)
    end

    def current_track
      @track_pos && @tracks[@track_pos]
    end

  end

end