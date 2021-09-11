class MusicBox

  class Collection

    class Album < Group::Item

      attr_accessor :title
      attr_accessor :artist_name
      attr_accessor :artist_key
      attr_accessor :year
      attr_accessor :discs
      attr_accessor :tracks

      InfoKeyMap = {
        :title => :title,
        :artist => :artist_name,
        :artist_key => :artist_key,
        :original_release_year => :year,
        :format_quantity => :discs,
      }

      alias_method :artist=, :artist_name=

      def tracks=(tracks)
        @tracks = tracks.map { |t| Track.new(t.merge(album: self)) }
      end

      def to_h
        super.merge(
          title: @title,
          artist: @artist_name,
          artist_key: @artist_key,
          year: @year,
          discs: @discs,
          tracks: @tracks.map(&:to_h),
        )
      end

      def summary
        '%-8s | %-4s | %-4s | %-60.50s | %-60.60s' % [
          @id,
          @artist_key,
          @year || '-',
          @artist_name,
          @title,
        ]
      end

      def details
        info = [
          ['ID', @id],
          ['Artist', @artist_name],
          ['Title', @title],
          ['Released', @year || '-'],
          ['Tracks', nil, @tracks.map(&:to_info)],
        ]
        MusicBox.info_to_s(info)
      end

      def cover_file
        @cover_file ||= dir.glob('cover.{jpg,png}').first
      end

      def has_cover?
        cover_file != nil
      end

      def to_label
        {
          artist_name: @artist_name,
          artist_key: @artist_key,
          title: @title,
          year: @year,
          id: @id,
        }
      end

      def self.csv_header
        %w[ID year artist title].to_csv
      end

      def to_csv
        [@id, @year, @artist_name, @title].to_csv
      end

      def validate_logs
        log_files = dir.glob('*.log')
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

      def extract_cover
        begin
          run_command('mp4art',
            '--extract',
            '--art-index', 0,
            '--overwrite',
            '--quiet',
            @tracks.first.path)
        rescue RunCommandFailed => e
          # ignore
        end
        # cover is in FILE.art[0].TYPE
        art_paths = dir.glob('*.art*.*').reject { |f| f.extname.downcase == '.gif' }
        raise Error, "#{id}: multiple covers found" if art_paths.length > 1
        art_path = art_paths.first
        unless art_path
          puts "#{id}: no cover to extract"
          return nil
        end
        file = (art_path.dirname / 'extracted-cover').add_extension(art_path.extname)
        file.unlink if file.exist?
        art_path.rename(file)
        file
      end

      def make_label
        LabelMaker.make_labels(to_label,
          output_file: '/tmp/labels.pdf',
          open: true)
      end

      def make_cover
        CoverMaker.make_covers(cover_file,
          output_file: '/tmp/covers.pdf',
          open: true)
      end

      def update_from_release(release, force: false)
        diffs = {}
        InfoKeyMap.each do |release_key, album_key|
          release_value = @release.send(release_key)
          album_value = send(album_key)
          if album_value && release_value != album_value
            diffs[album_key] = [release_value, album_value]
          end
        end
        unless diffs.empty?
          puts summary
          diffs.each do |key, values|
            puts "\t" + '%s: %p != %p' % [key, *values]
          end
          puts
          if force || TTY::Prompt.new.yes?('Update?')
            diffs.each do |k, vs|
              set(k => vs.first)
            end
            save
            update_tags
          end
        end
      end

      def update_tags
        @tracks.each do |track|
          track.update_tags
          track.update_cover(cover_file) if has_cover?
        end
      end

    end

  end

end