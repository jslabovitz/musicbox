module MusicBox

  class Importer

    def initialize(catalog:)
      @catalog = catalog
    end

    def import(args)
      for_each_dir(@catalog.import_dir, args) do |dir|
        import_dir(dir)
      end
    end

    def extract(args)
      for_each_dir(@catalog.extract_dir, args) do |dir|
        extract_dir(source_dir: dir, dest_dir: @catalog.import_dir / dir.basename)
      end
    end

    private

    def extract_dir(source_dir:, dest_dir:)
      source_dir = Path.new(source_dir)
      dest_dir = Path.new(dest_dir)
      puts "Extracting #{source_dir}"

      files = {}
      source_dir.children.each do |path|
        files[path.extname] ||= []
        files[path.extname] << path
      end

      cue_files = files.delete('.cue') || []
      bin_files = files.delete('.m4a') || []
      log_files = files.delete('.log') || []

      raise Error, "Expecting one cue file" if cue_files.length != 1
      raise Error, "Expecting one bin file" if bin_files.length != 1
      raise Error, "Expecting one log file" if log_files.length != 1

      raise Error, "Extraction directory already exists: #{dest_dir}" if dest_dir.exist?
      dest_dir.mkpath

      log_files.each { |p| p.cp(dest_dir) }
      files.values.flatten.each { |p| p.cp_r(dest_dir) }

      dest_dir.chdir do
        run_command('xld',
          '-c', cue_files.first,
          '-f', 'alac',
          '--filename-format', '%D-%n - %t',
          bin_files.first)
      end

      @catalog.extract_done_dir.mkpath unless @catalog.extract_done_dir.exist?
      source_dir.rename(@catalog.extract_done_dir / source_dir.basename)
    end

    def import_dir(source_dir)
      source_dir = Path.new(source_dir).realpath
      puts; puts "Importing from #{source_dir}"
      releases = @catalog.prompt_releases(source_dir.basename.to_s) or return
      raise "Must specify one release" unless releases.length == 1
      release = releases.first
      print release.details_to_s
      if (album = release.album)
        puts "Album already exists: #{release.id}"
        puts "\ta - add as additional disc"
        puts "\to - overwrite"
        puts "\ts - skip"
        print "Choice? [a] "
        loop do
          case STDIN.gets.to_s.strip
          when 'a', ''
            album.convert_to_multidisc unless album.discs
            album.discs += 1
            break
          when 'o'
            # import as-is
            break
          when 's'
            puts "Skipping #{source_dir}"
            return
          end
        end
      else
        album = @catalog.albums.new_album(release.id, release_id: release.id)
        album.title = release.title
        album.artist = release.artists.first.name
        album.year = release.original_release_year
        album.release = release
        puts "Created album: #{album.dir}"
      end
      source_files = categorize_source_files(source_dir)
      actual_tracks = release.tracklist_actual_tracks
      [source_files[:tracks], actual_tracks].map(&:length).max.times.each do |i|
        puts "%2s. %-70s => %-70s" % [
          i + 1,
          source_files[:tracks][i]&.basename,
          actual_tracks[i].title,
        ]
      end
      if source_files[:tracks].length == actual_tracks.length
        print "Add? [y] "
        loop do
          case STDIN.gets.to_s.strip
          when 'y', ''
            break
          when 'n'
            return
          end
        end
      else
        print "Imported tracks differ from release tracks. Add anyway? [n] "
        loop do
          case STDIN.gets.to_s.strip
          when 'y'
            break
          when 'n', ''
            return
          end
        end
      end
      album.dir.mkpath unless album.dir.exist?
      source_files[:tracks].each { |f| import_track_file(f, album) }
      source_files[:logs].each { |f| import_log_file(f, album) }
      source_files[:other].each { |f| import_other_file(f, album) }
      album.save
      @catalog.import_done_dir.mkpath unless @catalog.import_done_dir.exist?
      source_dir.rename(@catalog.import_done_dir / source_dir.basename)
      print "Make label? [y] "
      loop do
        case STDIN.gets.to_s.strip
        when 'y', ''
          labeler = Labeler.new(catalog: @catalog)
          labeler << release.to_label
          labeler.make_labels('/tmp/labels.pdf', open: true)
          break
        when 'n'
          break
        end
      end
    end

    def categorize_source_files(source_dir)
      source_files = {
        tracks: [],
        logs: [],
        other: [],
      }
      source_dir.children.sort.each do |source_file|
        type = case source_file.extname.downcase
        when '.m4a', '.m4p', '.mp3'
          :tracks
        when '.log'
          :logs
        else
          :other
        end
        source_files[type] << source_file
      end
      source_files
    end

    def import_track_file(source_file, album)
      tags = Catalog::Tags.load(source_file)
      track = Catalog::AlbumTrack.new(
        title: tags[:title],
        artist: tags[:artist] || album.artist,
        track: tags[:track],
        disc: album.discs,
        album: album,
        tags: tags)
      album.tracks << track
      track.file = Path.new(track.make_name).add_extension(source_file.extname)
      puts "Importing track: #{source_file.basename} => #{track.path.basename}"
      source_file.cp(track.path)
      track.update_tags
      track.save_tags
    end

    def import_log_file(source_file, album)
      puts "Importing log: #{source_file.basename}"
      album.log_files << source_file.basename
      source_file.cp(album.dir)
    end

    def import_other_file(source_file, album)
      puts "Importing other: #{source_file.basename}"
      source_file.cp_r(album.dir)
    end

    def validate!
      validate_logs!
    end

    def validate_logs!
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

    def for_each_dir(base_dir, args, &block)
      if args.empty?
        dirs = base_dir.children.select(&:dir?)
      else
        dirs = args.map { |p| Path.new(p) }
      end
      dirs.sort_by { |d| d.to_s.downcase }.each do |dir|
        begin
          yield(dir)
        rescue Error => e
          warn "#{dir}: #{e}"
        end
      end
    end

  end

end