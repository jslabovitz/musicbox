class MusicBox

  class Exporter

    def initialize(src_dir:, dest_dir:, compress: false, force: false, parallel: false)
      raise Error, "Must specify source directory" unless src_dir
      @src_dir = Path.new(src_dir).expand_path
      raise Error, "Must specify destination directory" unless dest_dir
      @dest_dir = Path.new(dest_dir).expand_path
      @compress = compress
      @force = force
      @parallel = parallel
    end

    def export_album(album)
      name = '%s - %s (%s)' % [album.artist_name, album.title, album.year]
      export_dir = @dest_dir / name
      export_dir.mkpath unless export_dir.exist?
      threads = []
      album.tracks.each do |track|
        src_file = album.file_path(@src_dir, track.file)
        dest_file = export_dir / track.file
        if @force || !dest_file.exist? || dest_file.mtime != src_file.mtime
          if @parallel
            threads << Thread.new do
              export_track(src_file, dest_file)
            end
          else
            export_track(src_file, dest_file)
          end
        end
      end
      threads.map(&:join)
    end

    def export_track(src_file, dest_file)
      if @compress
        warn "compressing #{src_file}"
        compress_track(src_file, dest_file)
      else
        warn "copying #{src_file}"
        src_file.cp(dest_file)
      end
    end

    def compress_track(src_file, dest_file)
      begin
        tags = Tags.load(src_file)
        caf_file = dest_file.replace_extension('.caf')
        run_command('afconvert',
          src_file,
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
        dest_file.utime(src_file.atime, src_file.mtime)
      rescue => e
        dest_file.unlink if dest_file.exist?
        raise e
      ensure
        caf_file.unlink if caf_file.exist?
      end
    end

  end

end