class MusicBox

  class Collection

    class Album < Simple::Group::Item

      attr_accessor :title
      attr_accessor :artist_name
      attr_accessor :artist_id
      attr_accessor :artist       # linked on load
      attr_accessor :year
      attr_accessor :discs
      attr_accessor :tracks

      include Simple::Printer::Printable

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

      def make_label(pdf)
        pdf.bounding_box([0, 1.in], width: 2.5.in, height: 1.in) do
          # ;;pdf.transparent(0.5) { pdf.stroke_bounds }
          pdf.text_box <<~END, inline_format: true
            <b>#{@artist_name}</b>
            <i>#{@title}</i>
          END
        end
        pdf.bounding_box([2.7.in, 1.in], width: 0.8.in, height: 1.in) do
          # ;;pdf.transparent(0.5) { pdf.stroke_bounds }
          pdf.text_box <<~END, align: :right, inline_format: true
            <b>#{@artist_id}
            #{@year}</b>


            #{@id}
          END
        end
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

      def make_cover
        CoverMaker.make_covers(cover_file,
          output_file: '/tmp/covers.pdf',
          open: true)
      end

      def update_tags
        @tracks.each do |track|
          track.update_tags
          track.update_cover(cover_file) if has_cover?
        end
      end

      def export(dest_dir:, compress: false, force: false, parallel: true)
        dest_dir.mkpath unless dest_dir.exist?
        threads = []
        @tracks.each do |track|
          if parallel
            threads << Thread.new do
              track.export(dest_dir: dest_dir, force: force, compress: compress)
            end
          else
            track.export(dest_dir: dest_dir, force: force, compress: compress)
          end
        end
        threads.map(&:join)
      end

    end

  end

end