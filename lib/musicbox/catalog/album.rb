class MusicBox

  class Catalog

    class Album < Group::Item

      attr_accessor :title
      attr_accessor :artist
      attr_accessor :year
      attr_accessor :discs
      attr_accessor :tracks
      attr_accessor :collection_item    # linked on load
      attr_accessor :release            # linked on load

      def initialize(params={})
        @tracks = []
        super
      end

      def tracks=(tracks)
        @tracks = tracks.map { |h| AlbumTrack.new(h.merge(album: self)) }
      end

      def artist
        @artist || @tracks&.first&.artist
      end

      def cover_file
        files = @dir.glob('cover.{jpg,png}')
        raise Error, "Multiple cover files: #{files.join(', ')}" if files.length > 1
        files.first
      end

      def has_cover?
        !cover_file.nil?
      end

      def to_s
        '%-8s | %1s | %-4s | %-50.50s | %-60.60s | %-6s' % [
          @id,
          has_cover? ? 'C' : '',
          @year || '-',
          artist,
          @title,
          @discs || '-',
        ]
      end

      def show_cover(width: nil, height: nil, preserve_aspect_ratio: nil)
        # see https://iterm2.com/documentation-images.html
        file = cover_file
        if file && file.exist?
          data = Base64.strict_encode64(file.read)
          args = {
            name: Base64.strict_encode64(file.to_s),
            size: data.length,
            width: width,
            height: height,
            preserveAspectRatio: preserve_aspect_ratio,
            inline: 1,
          }.compact
          puts "\033]1337;File=%s:%s\a" % [
            args.map { |a| a.join('=') }.join(';'),
            data,
          ]
        end
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
        if has_cover?
          # --replace apparently doesn't work, so must do --remove, then --add
          @tracks.each do |track|
            begin
              run_command('mp4art',
                '--quiet',
                '--remove',
                track.path)
            rescue RunCommandFailed => e
              # ignore
            end
            run_command('mp4art',
              '--quiet',
              '--add',
              cover_file,
              track.path)
          end
        end
      end

      def extract_cover
        if has_cover?
          puts "#{@id}: already has cover"
          return
        end
        file = @dir / @tracks.first.file
        begin
          run_command('mp4art',
            '--extract',
            '--art-index', 0,
            '--overwrite',
            '--quiet',
            file)
        rescue RunCommandFailed => e
          # ignore
        end
        # cover is in FILE.art[0].TYPE
        files = @dir.glob('*.art*.*').reject { |f| f.extname.downcase == '.gif' }
        if files.length == 0
          puts "#{@id}: no cover to extract"
        elsif files.length > 1
          raise Error, "Multiple covers found"
        else
          file = files.first
          new_cover_file = (@dir / 'cover').add_extension(file.extname)
          puts "#{@id}: extracted cover: #{new_cover_file.basename}"
          file.rename(new_cover_file)
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