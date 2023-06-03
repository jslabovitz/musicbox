class MusicBox

  class Collection

    class Album < Simple::Group::Item

      attr_accessor :title
      attr_accessor :artist_name
      attr_accessor :artist_id
      attr_accessor :artist       # linked on load
      attr_accessor :year
      attr_accessor :discs
      attr_reader   :tracks

      include Simple::Printer::Printable

      def inspect
        "<#{self.class}>"
      end

      def tracks=(tracks)
        @tracks = tracks.map { |t| Track.new(t.merge(album: self)) }
      end

      def to_h
        super.merge(
          title: @title,
          artist_name: @artist_name,
          artist_id: @artist_id,
          year: @year,
          discs: @discs,
          tracks: @tracks.map(&:to_h),
        )
      end

      def <=>(other)
        sort_tuple <=> other.sort_tuple
      end

      def sort_tuple
        [@artist.id, @year || 0, @title]
      end

      def summary
        '%-8s | %-4s | %-4s | %-60.60s | %-60.60s' % [
          @id,
          @artist.id,
          @year || '-',
          @artist_name,
          @title,
        ]
      end

      def printable
        [
          [:id, 'ID'],
          [:artist_name, 'Artist'],
          :title,
          [:year, 'Released', @year || '-'],
          [:tracks, @tracks],
        ]
      end

      def description
        '%s - %s (%s)' % [@artist_name, @title, @year]
      end

      def cover_file
        @cover_file ||= dir.glob('cover.{jpg,png}').first
      end

      def has_cover?
        cover_file != nil
      end

      def update_tags
        @tracks.each do |track|
          track.update_tags
          MP4Tags.update_cover(cover_file) if has_cover?
        end
      end

      def check
        # warn "#{@id}: cover file doesn't exist: #{cover_file}" unless cover_file.exist?
        # puts summary
        unless @artist_name
          warn "#{@id}: artist_name not set"
        end
        @tracks.each do |track|
          unless track.path&.exist?
            warn "#{@id}: track file doesn't exist: #{track.path}"
          end
        end
      end

      def random_track
        @tracks.sample
      end

    end

  end

end