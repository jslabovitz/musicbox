module MusicBox

  class Importer

    def initialize(catalog:)
      @catalog = catalog
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
      source_files = @catalog.categorize_files(source_dir)
      audio_files = source_files[:audio]
      raise Error, "No audio files to import" if audio_files.nil? || audio_files.empty?
      actual_tracks = release.tracklist_actual_tracks
      max_tracks = [audio_files, actual_tracks].map(&:length).max
      max_tracks.times.each do |i|
        puts "%2s. %-70s => %-70s" % [
          i + 1,
          audio_files[i]&.basename,
          actual_tracks[i].title,
        ]
      end
      if audio_files.length == actual_tracks.length
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
      source_files.each do |type, files|
        case type
        when :audio
          files.each { |f| import_track_file(f, album) }
        when :log
          files.each { |f| import_log_file(f, album) }
        else
          files.each { |f| import_other_file(f, album) }
        end
      end
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

  end

end