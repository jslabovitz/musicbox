class MusicBox

  class Importer

    def initialize(catalog:)
      @catalog = catalog
      @prompt = TTY::Prompt.new
    end

    def import_dir(source_dir)
      @source_dir = Path.new(source_dir).realpath
      puts; puts "Importing from #{@source_dir}"
      find_release
      determine_disc
      make_album
      if @prompt.yes?('Add?')
        @album.save
        copy_files
        @release.select_cover   # also does update_tags
        make_label if @prompt.yes?('Make label?')
        make_cover if @prompt.yes?('Make cover?')
      end
    end

    def determine_disc
      @disc = nil
      if @album
        raise Error, "Album already exists" if @release.format_quantity.nil? || @release.format_quantity == 1
        puts "Release has multiple discs."
        n = @prompt.ask?('Which disc is this?', required: true, convert: :int)
        raise Error, "Disc number out of range" unless n >= 1 && n <= @release.format_quantity
        @disc = n
      end
    end

    def find_release
      releases = @catalog.find(@source_dir.basename.to_s,
        group: :releases,
        prompt: true,
        multiple: false)
      @release = releases.first
      @tracklist_flattened = @release.tracklist_flattened
      print @release.details_to_s
    end

    def make_album
      @album = Catalog::Album.new(
        id: @release.id,
        title: @release.title,
        artist: @release.artist,
        year: @release.original_release_year,
        discs: @release.format_quantity,
        dir: @catalog.albums.dir_for_id(@release.id))
      @release.album = @album
      @copy_plan = {}
      @source_dir.children.select(&:file?).reject { |f| f.basename.to_s.start_with?('.') }.sort.each do |source_file|
        type = MIME::Types.of(source_file.to_s).first&.media_type
        dest_file = case type
        when 'audio'
          album_track = make_album_track(source_file)
          @album.tracks << album_track
          album_track.file
        else
          source_file.basename
        end
        @copy_plan[source_file] = @album.dir / dest_file
      end
      raise Error, "No tracks were added to album" if @album.tracks.empty?
    end

    def make_album_track(file)
      tags = Catalog::Tags.load(file)
      release_track = find_track_for_title(tags[:title])
      name = '%s%02d - %s' % [
        @disc ? ('%1d-' % @disc) : '',
        tags[:track],
        release_track.title.gsub(%r{[/:]}, '_'),
      ]
      album_track = Catalog::AlbumTrack.new(
        title: release_track.title,
        artist: release_track.artist || @release.artist,
        track: tags[:track],
        disc: @disc || tags[:disc],
        file: Path.new(name).add_extension(file.extname),
        tags: tags,
        album: @album)
      puts "%-45s => %6s - %-45s => %-45s" % [
        file.basename,
        release_track.position,
        release_track.title,
        album_track.file,
      ]
      album_track
    end

    def find_track_for_title(title)
      normalized_title = title.normalize
      release_track = @tracklist_flattened.find { |t| t.title.normalize == normalized_title }
      unless release_track
        puts "Can't find release track with title #{title.inspect}"
        choices = @tracklist_flattened.map { |t| [t.title, t] }.to_h
        release_track = @prompt.select('Track?', choices, per_page: 100)
      end
      release_track
    end

    def copy_files
      @copy_plan.each do |source_file, dest_file|
        source_file.cp(dest_file)
      end
      @catalog.import_done_dir.mkpath unless @catalog.import_done_dir.exist?
      @source_dir.rename(@catalog.import_done_dir / @source_dir.basename)
    end

    def make_label
      output_file = '/tmp/labels.pdf'
      LabelMaker.make_labels(@release.to_label, output_file: output_file)
      run_command('open', output_file)
    end

    def make_cover
      output_file = '/tmp/covers.pdf'
      CoverMaker.make_covers(@release, output_file: output_file)
      run_command('open', output_file)
    end

  end

end