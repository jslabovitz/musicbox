class MusicBox

  class Playlist < Simple::Group::Item

    attr_accessor :tracks
    attr_accessor :pos
    attr_accessor :time_pos

    include Simple::Printer::Printable

    def self.playlist_for_random_tracks(number: nil, time: nil, **params)
      recs = Beets.random(fields: %i[mb_trackid], number: number, time: time)
      tracks = Beets.export(recs.map { |r| "mb_trackid:#{r.mb_trackid}" }.join(' , ').split(' '))
# ;;pp(__method__ => { recs: recs, tracks: tracks })
      new(tracks: tracks, **params)
    end

    def self.playlist_for_random_album(**params)
      recs = Beets.random(fields: %i[mb_albumid], number: 1).first or raise Error, "Can't get random album"
      tracks = Beets.export("mb_albumid:#{recs.mb_albumid}")
# ;;pp(__method__ => { recs: recs, tracks: tracks })
      new(tracks: tracks, **params)
    end

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

    def playlist_for_album_of_current_track(**params)
      raise Error, "No current track" unless current_track
      tracks = Beets.export("mb_albumid:#{current_track.mb_albumid}")
# ;;pp(__method__ => { tracks: tracks })
      self.class.new(tracks: tracks, **params)
    end

  end

end