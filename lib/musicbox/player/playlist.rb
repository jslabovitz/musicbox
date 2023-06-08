class MusicBox

  class Player

    class Playlist < Simple::Group::Item

      attr_accessor :tracks
      attr_accessor :pos
      attr_accessor :time_pos

      include Simple::Printer::Printable

      def self.playlist_for_random_tracks(collection:, id:, number:)
        tracks = Set.new
        while tracks.count < number
          tracks << collection.random_album.random_track
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

      def current_track
        @pos && @tracks[@pos]
      end

      def next_track
        @pos && @tracks[@pos + 1]
      end

      def previous_track
        @pos && @pos > 0 && @tracks[@pos - 1]
      end

      def write_m3u8(path)
        File.write(path, @tracks.map(&:path).join("\n"))
      end

    end

  end

end