module MusicBox

  class Catalog

    class Album < Group::Item

      attr_accessor :title
      attr_accessor :artist
      attr_accessor :year
      attr_accessor :discs
      attr_accessor :tracks
      attr_accessor :log_files
      attr_accessor :release    # linked on load

      def initialize(params={})
        @tracks = []
        @log_files = []
        super
      end

      def release_id=(id)
        @id = id
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

      def artist
        @artist || @tracks&.first&.artist
      end

      def log_files=(files)
        @log_files = files.map { |f| Path.new(f) }
      end

      def tracks=(tracks)
        @tracks = tracks.map { |h| AlbumTrack.new(h.merge(album: self)) }
      end

      def dir
        @path.dirname
      end

      def has_cover?
        cover_file.exist?
      end

      def cover_file
        dir / 'cover.jpg'
      end

      def <=>(other)
        @release <=> other.release
      end

      def to_s
        if @release
          @release.to_s
        else
          '<%s: %s: %s (%s)> | %s' % [
            @id,
            artist,
            @title,
            @year,
            dir,
          ]
        end
      end

      def convert_to_multidisc
        raise Error, "Already multidisc" if @discs
        @discs = 1
        @tracks.each do |track|
          old_path = track.path.dup
          track.disc = @discs
          track.file = Path.new(track.make_name).add_extension(old_path.extname)
          old_path.rename(dir / track.file)
        end
        save
      end

      def validate
        raise Error, "Invalid album: missing title (#{dir})" unless @title
        # raise Error, "Invalid album: missing artist (#{dir})" unless @artist
        validate_logs
      end

      def validate_logs
        raise Error, "No rip logs" if @log_files.empty?
        state = :initial
        @log_files.each do |log_file|
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
          track.load_tags
          track.update_tags
          changes << track if track.tags.changed?
        end
        unless changes.empty?
          puts
          puts "#{@title} [#{dir}]"
          changes.each do |track|
            puts "\t" + track.make_name.to_s
            track.tags.changes.each do |change|
              puts "\t\t" + change.inspect
            end
          end
          unless force
            print "Update album? [y] "
            case STDIN.gets.to_s.strip
            when 'y', ''
              force = true
            end
          end
          if force
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
          tracks: @tracks.map(&:to_h),
          log_files: @log_files.map(&:to_s))
      end

    end

  end

end