module MusicBox

  class Exporter

    def initialize(catalog:, dir:, compress: false, force: false, parallel: false)
      @catalog = catalog
      @dir = Path.new(dir).expand_path
      @compress = compress
      @force = force
      @parallel = parallel
    end

    def export_release(release)
      name = '%s - %s (%s)' % [release.artist, release.title, release.original_release_year]
      rip = release.rip or raise Error, "Rip does not exist for release #{release.id} (#{name})"
      dir = @dir / name
      dir.mkpath unless dir.exist?
      threads = []
      rip.tracks.each do |track|
        src_file = track.path
        dst_file = dir / src_file.basename
        if @force || !dst_file.exist? || dst_file.mtime != src_file.mtime
          if @parallel
            threads << Thread.new do
              export_track(src_file, dst_file)
            end
          else
            export_track(src_file, dst_file)
          end
        end
      end
      threads.map(&:join)
    end

    def export_track(src_file, dst_file)
      if @compress
        warn "compressing #{src_file}"
        compress_track(src_file, dst_file)
      else
        warn "copying #{src_file}"
        src_file.cp(dst_file)
      end
    end

    def compress_track(src_file, dst_file)
      begin
        tags = Catalog::Tags.load(src_file)
        caf_file = dst_file.replace_extension('.caf')
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
          dst_file)
        tags.save(dst_file, force: true)
        dst_file.utime(src_file.atime, src_file.mtime)
      rescue => e
        dst_file.unlink if dst_file.exist?
        raise e
      ensure
        caf_file.unlink if caf_file.exist?
      end
    end

  end

end