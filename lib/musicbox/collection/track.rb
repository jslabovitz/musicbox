class MusicBox

  class Collection

    class Track

      attr_accessor :title
      attr_accessor :artist_name
      attr_accessor :track_num
      attr_accessor :disc_num
      attr_accessor :file
      attr_accessor :album

      include SetParams
      include Simple::Printer::Printable

      def to_h
        {
          title: @title,
          artist_name: (@artist_name != @album.artist_name) ? @artist_name : nil,
          track_num: @track_num,
          disc_num: @disc_num,
          file: @file.to_s,
        }.compact
      end

      def printable
        [
          [
            :num,
            @disc_num ? ('%1d-%02d' % [@disc_num, @track_num]) : ('%2d' % @track_num),
            @title,
          ],
        ]
      end

      def path
        @album.dir / @file
      end

      def update_cover(cover_path)
        # --replace apparently doesn't work, so must do --remove, then --add
        begin
          run_command('mp4art',
            '--quiet',
            '--remove',
            path)
        rescue RunCommandFailed => _
          # ignore
        end
        run_command('mp4art',
          '--quiet',
          '--add',
          cover_path,
          path)
      end

      def update_tags
        tags = Tags.load(path)
        tags.update(
          {
            title: @title,
            album: @album.title,
            track: @track_num,
            disc: @disc_num,
            discs: @album.discs,
            artist: @artist_name || @album.artist_name,
            album_artist: @album.artist_name,
            grouping: @album.title,
            year: @album.year,
          }.reject { |k, v| v.to_s.empty? }
        )
        tags.save(path)
      end

      def export(dest_dir:, force: false, compress: false)
        dest_file = dest_dir / @file
        if force || !dest_file.exist? || dest_file.mtime != path.mtime
          if compress
            warn "compressing #{path}"
            compress(dest_file)
          else
            warn "copying #{path}"
            path.cp(dest_file)
          end
        end
      end

      def compress(dest_file)
        begin
          tags = Tags.load(path)
          caf_file = dest_file.replace_extension('.caf')
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
          tags.save(dest_file, force: true)
          dest_file.utime(path.atime, path.mtime)
        rescue => e
          dest_file.unlink if dest_file.exist?
          raise e
        ensure
          caf_file.unlink if caf_file.exist?
        end
      end

    end

  end

end