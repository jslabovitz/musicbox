module MusicBox

  class Catalog

    class AlbumTrack

      attr_accessor :title
      attr_accessor :artist
      attr_accessor :track
      attr_accessor :disc
      attr_accessor :album
      attr_accessor :file
      attr_accessor :tags

      def initialize(params={})
        params.each { |k, v| send("#{k}=", v) }
      end

      def file=(file)
        @file = Path.new(file)
      end

      def path
        @album.dir / @file
      end

      def make_name
        '%s%02d - %s' % [
          @disc ? ('%1d-' % @disc) : '',
          @track,
          @title.gsub(%r{[/:]}, '_'),
        ]
      end

      def load_tags
        @tags ||= Tags.load(path)
      end

      def save_tags
        @tags.save(path)
      end

      def update_tags
        load_tags
        @tags.update(
          {
            title: @title,
            album: @album.title,
            track: @track,
            disc: @disc,
            discs: @album.discs,
            artist: @artist || @album.artist,
            album_artist: @album.artist,
            grouping: @album.title,
            year: @album.year,
          }.reject { |k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
        )
      end

      def to_h
        {
          title: @title,
          artist: @artist,
          track: @track,
          disc: @disc,
          file: @file.to_s,
        }.compact
      end

      #FIXME: does not save tags correctly to final file

      def export(dest_dir)
        dest_file = dest_dir / path.basename
        return if dest_file.exist? && dest_file.mtime == path.mtime
        caf_file = dest_file.replace_extension('.caf')
        dest_dir.mkpath unless dest_dir.exist?
        load_tags
        warn "exporting #{path}"
        begin
          run_command('afconvert',
            path,
            caf_file,
            '--data', 0,
            '--file', 'caff',
            '--soundcheck-generate')
          run_command('afconvert',
            caf_file,
            '--data', 'aac',
            '--file', 'm4af',
            '--soundcheck-read',
            '--bitrate', 256000,
            '--quality', 127,
            '--strategy', 2,
            dest_file)
        rescue => e
          dest_file.unlink if dest_file.exist?
          raise e
        ensure
          caf_file.unlink if caf_file.exist?
        end
        @tags.save(dest_file, force: true)
        dest_file.utime(path.atime, path.mtime)
      end

    end

  end

end