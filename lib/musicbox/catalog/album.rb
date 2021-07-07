class MusicBox

  class Catalog

    class Album < Group::Item

      attr_accessor :title
      attr_accessor :artist
      attr_accessor :year
      attr_accessor :discs
      attr_accessor :tracks

      def initialize(params={})
        @tracks = []
        super
      end

      def tracks=(tracks)
        @tracks = tracks.map { |h| AlbumTrack.new(h.merge(album: self)) }
      end

      def date=(date)
        @year = case date
        when Date
          date.year
        when String
          date.to_i
        else
          date
        end
      end

      def release_id=(id)
        @id = id
      end

      def log_files=(*); end

      def artist
        @artist || @tracks&.first&.artist
      end

      def cover_file
        @dir / 'cover.jpg'
      end

      def has_cover?
        cover_file.exist?
      end

      def validate_logs
        log_files = @dir.glob('*.log')
        raise Error, "No rip logs" if log_files.empty?
        state = :initial
        log_files.each do |log_file|
          log_file.readlines.map(&:chomp).each do |line|
            case state
            when :initial
              if line =~ /^AccurateRip Summary/
                state = :accuraterip_summary
              end
            when :accuraterip_summary
              if line =~ /^\s+Track \d+ : (\S+)/
                raise Error, "Not accurately ripped" unless $1 == 'OK'
              else
                break
              end
            end
          end
        end
      end

      def update_tags(force: false)
        changes = []
        @tracks.each do |track|
          track.update_tags
          changes << track if track.tags.changed?
        end
        unless changes.empty?
          puts
          puts "#{@title} [#{@dir}]"
          changes.each do |track|
            puts "\t" + track.file.to_s
            track.tags.changes.each do |change|
              puts "\t\t" + change.inspect
            end
          end
          if force || TTY::Prompt.new.yes?('Update track files?')
            changes.each do |track|
              track.save_tags
            end
          end
        end
      end

      def serialize
        super(
          title: @title,
          artist: @artist,
          year: @year,
          discs: @discs,
          tracks: @tracks.map(&:to_h))
      end

    end

  end

end