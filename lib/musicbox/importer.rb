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
      make_copy_plan
      if @prompt.yes?('Add?')
        import_album
        make_label if @prompt.yes?('Make label?')
        make_cover if @prompt.yes?('Make cover?')
      end
    end

    def determine_disc
      @disc = nil
      if @album
        raise Error, "Album already exists" if @release.format_quantity.nil? || @release.format_quantity == 1
        puts "Release is multidisc."
        n = @prompt.ask?('Which disc is this?', required: true, convert: :int)
        raise Error, "Disc number out of range" unless n >= 1 && n <= @release.format_quantity
        @disc = n
      end
    end

    def find_release
      @release = @catalog.find(@source_dir.basename.to_s,
        group: :releases,
        prompt: true,
        multiple: false)
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
      puts "%-50s ==> %6s - %-50s ==> %-50s" % [
        file.basename,
        release_track.position,
        release_track.title,
        album_track.file,
      ]
      album_track
    end

    def find_track_for_title(title)
      release_track = @tracklist_flattened.find { |t| t.title.downcase == title.downcase }
      unless release_track
        puts "Can't find release track with title #{title.inspect}"
        choices = @tracklist_flattened.map { |t| [t.title, t] }.to_h
        release_track = @prompt.select('Track?', choices, per_page: 100)
      end
      release_track
    end

    def import_album
      raise Error, "No tracks were added to album" if @album.tracks.empty?
      @album.save
      copy_files
      @album.update_tags
      extract_cover
    end

    def make_copy_plan
      @copy_plan = @source_dir.children.select(&:file?).sort.map do |source_file|
        dest_file = case source_file.extname.downcase
        when '.m4a'
          album_track = make_album_track(source_file) or next
          @album.tracks << album_track
          album_track.file
        else
          source_file.basename
        end
        [source_file, @album.dir / dest_file]
      end.to_h
    end

    def copy_files
      @copy_plan.each do |source_file, dest_file|
        source_file.cp(dest_file)
      end
      @catalog.import_done_dir.mkpath unless @catalog.import_done_dir.exist?
      @source_dir.rename(@catalog.import_done_dir / @source_dir.basename)
    end

    def make_label
      Labeler.make_label(@release.to_label, output_file: '/tmp/labels.pdf', open: true)
    end

    def make_cover
      #FIXME
    end

  end

end