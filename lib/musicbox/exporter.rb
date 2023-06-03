class MusicBox

  class Exporter

    attr_accessor :dest_dir
    attr_accessor :compress
    attr_accessor :force
    attr_accessor :parallel

    include SetParams

    def initialize(params={})
      @compress = @parallel = true
      @force = false
      @num_workers = 8
      super
    end

    def dest_dir=(dir)
      @dest_dir = Path.new(dir)
    end

    def export
      queue = make_queue
      if queue.empty?
        puts "Nothing to do"
      else
        Thread.abort_on_exception = true
        @num_workers.times.to_a.map { Thread.new { Worker.run(queue) } }.map(&:join)
      end
    end

    def make_queue
      ignore_paths = [
        @musicbox.import_dir,
        @musicbox.archive_dir,
        @musicbox.discogs_dir,
        @musicbox.playlists_dir,
        @musicbox.listens_dir,
        @musicbox.equalizers_dir,
      ]
      queue = Queue.new
      @musicbox.root_dir.find do |src|
        dst = @dest_dir / src.relative_to(@musicbox.root_dir)
        Find.prune if ignore_paths.include?(src) || src.hidden?
        if src.file? && (@force || !dst.exist? || dst.mtime != src.mtime)
          queue.push([
            should_compress?(src) ? :compress_file : :copy_file,
            src,
            dst
          ])
        end
      end
      queue
    end

    def should_compress?(path)
      @compress && path.extname.downcase == '.m4a'
    end

    class Worker

      def self.run(queue)
        new.run(queue)
      end

      def run(queue)
        while (job = queue.pop)
          send(*job)
        end
      end

      def compress_file(src, dst)
        puts '%-15s %s' % ['COMPRESSING', src]
        dst.dirname.mkpath
        tags = MP4Tags.load(src)
        tmp = dst.add_extension('.tmp')
        intermediate = dst.replace_extension('.caf')
        begin
          run_command('afconvert',
            src,
            intermediate,
            '--data', 0,
            '--file', 'caff',
            '--soundcheck-generate')
          run_command('afconvert',
            intermediate,
            '--data', 'aac',
            '--file', 'm4af',
            '--soundcheck-read',
            '--bitrate', 256000,
            '--quality', 127,
            '--strategy', 2,
            tmp)
          tags.save(tmp, force: true)
          tmp.utime(src.atime, src.mtime)
          tmp.rename(dst)
        rescue => e
          dst.unlink if dst.exist?
          raise e
        ensure
          intermediate.unlink if intermediate.exist?
          tmp.unlink if tmp.exist?
        end
      end

      def copy_file(src, dst)
        puts '%-15s %s' % ['COPYING', src]
        dst.dirname.mkpath
        tmp = dst.add_extension('.tmp')
        begin
          src.cp(tmp)
          tmp.rename(dst)
        ensure
          tmp.unlink if tmp.exist?
        end
      end

    end

  end

end