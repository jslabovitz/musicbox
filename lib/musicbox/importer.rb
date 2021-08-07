class MusicBox

  class Importer

    attr_accessor :catalog
    attr_accessor :albums
    attr_accessor :source_dir
    attr_accessor :archive_dir

    include SetParams

    def self.import(params)
      new(params).tap { |o| o.import }
    end

    def initialize(params={})
      set(params)
      @prompt = TTY::Prompt.new
    end

    def import
      puts; puts "Importing from #{@source_dir}"
      make_album
      if @prompt.yes?('Add?')
        @albums.save_item(@album)
        copy_files
        archive
        select_cover   # also does update_tags
        make_label if @prompt.yes?('Make label?')
        make_cover if @prompt.yes?('Make cover?')
      end
    end

    def make_album
      @release = @catalog.releases.find(@source_dir.basename.to_s, prompt: true, multiple: false).first
      print @release.details
      @album = @albums[@release.id]
      if @album
        raise Error, "Album already exists" if @release.format_quantity.nil? || @release.format_quantity == 1
        puts "Release has multiple discs."
        n = @prompt.ask?('Which disc is this?', required: true, convert: :int)
        raise Error, "Disc number out of range" unless n >= 1 && n <= @release.format_quantity
        @disc = n
      else
        @album = Catalog::Album.new(
          id: @release.id,
          title: @release.title,
          artist: @release.artist,
          year: @release.original_release_year,
          discs: @release.format_quantity,
          json_file: @albums.json_file_for_id(@release.id))
      end
      make_tracks
    end

    def make_tracks
      @album.tracks ||= []
      @copy_plan = {}
      @source_dir.children.select(&:file?).reject(&:hidden?).reject { |f| f.basename.to_s == 'info.json' }.sort.each do |source_file|
        type = MIME::Types.of(source_file.to_s).first&.media_type
        dest_file = case type
        when 'audio'
          track = make_track(source_file)
          @album.tracks << track
          track.file
        else
          source_file.basename
        end
        @copy_plan[source_file] = @album.dir / dest_file
      end
      raise Error, "No tracks were added to album" if @album.tracks.empty?
    end

    def make_track(file)
      tags = Catalog::Tags.load(file)
      release_track = tags[:title] ? @release.find_track_for_title(tags[:title]) : nil
      unless release_track
        puts "Can't find release track with title #{tags[:title].inspect}"
        choices = @release.tracklist_flattened.map { |t| [t.title, t] }.to_h
        release_track = @prompt.select('Track?', choices, per_page: 50)
      end
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

    def copy_files
      @copy_plan.each do |source_file, dest_file|
        source_file.cp(dest_file)
      end
    end

    def archive
      @archive_dir.mkpath unless @archive_dir.exist?
      @source_dir.rename(@archive_dir / @source_dir.basename)
    end

    def make_label
      LabelMaker.make_labels(@album.to_label,
        output_file: '/tmp/labels.pdf',
        open: true)
    end

    def make_cover
      CoverMaker.make_covers(@album.cover_file,
        output_file: '/tmp/covers.pdf',
        open: true)
    end

  end

end