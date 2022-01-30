class MusicBox

  class Collection

    class Albums < Simple::Group

      def self.item_class
        Album
      end

      def self.search_fields
        @search_fields ||= [:title, :artist_name]
      end

      def initialize(**)
        super
        @track_paths = {}
        items.each do |album|
          album.tracks.each do |track|
            @track_paths[track.path] = track
          end
        end
      end

      def random_album
        items.shuffle.first
      end

      def random_tracks(length:)
        tracks = Set.new
        while tracks.length < length
          tracks << random_album.tracks.shuffle.first
        end
        tracks.to_a
      end

      def track_from_path(path)
        path = Path.new(path)
        @track_paths[path] or raise "Can't find track for path #{path.to_s.inspect}"
      end

    end

  end

end