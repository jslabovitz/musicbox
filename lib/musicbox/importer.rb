class MusicBox

  class Importer

    attr_accessor :discogs
    attr_accessor :collection
    attr_accessor :archive_dir

    include SetParams

    def initialize(params={})
      set(params)
      @prompt = TTY::Prompt.new
    end

    def import_dir(dir)
      raise Error, "Directory #{dir.to_s.inspect} does not exist" unless dir.exist?
      query = '%' + dir.basename.to_s
      puts "Finding: #{query.inspect}"
      releases = $musicbox.find_releases(query)
      release = @prompt.select('Item?', releases, filter: true, per_page: 25, quiet: true)
      release.print
      artist = make_artist(release: release)
      album, disc = make_album(release: release, artist: artist)
      copy_plan = make_tracks(album: album, disc: disc, release: release, dir: dir)
      return unless @prompt.yes?('Add?')
      @collection.albums.save_item(album)
      copy_plan.each do |source_file, dest_file|
        source_file.cp(dest_file)
      end
      @archive_dir.mkpath unless @archive_dir.exist?
      dir.rename(@archive_dir / dir.basename)
      album.extract_cover
      select_cover(album: album, release: release)
      album.update_tags
      @prompt.yes?('Make label?') && LabelMaker.make_label(album)
      @prompt.yes?('Make cover?') && album.make_cover
    end

    def make_artist(release:)
      discogs_name = release.artist
      name = MusicBox.config.fetch(:canonical_names)[discogs_name] || discogs_name
      name.sub!(/\s\(\d+\)/, '')  # handle 'Nico (3)'
      if MusicBox.config.fetch(:personal_names).include?(name)
        elems = name.split(/\s+/)
        name = [elems[-1], elems[0..-2].join(' ')].join(', ')
        personal = true
      else
        personal = false
      end
      id = make_artist_id(name)
      unless (artist = @collection.artists[id])
        artist = Collection::Artist.new(
          id: id,
          name: name,
          personal: personal)
        ;;warn "adding new artist: #{artist}"
        @collection.artists.save_item(artist)
      end
      unless discogs_name == name || artist.aliases.include?(discogs_name)
        ;;warn "adding alias #{discogs_name.inspect} to artist #{artist.inspect}"
        artist.aliases << discogs_name
        @collection.artists.save_item(artist)
      end
      artist
    end

    def make_artist_id(name)
      id = ''
      tokens = name.tokenize
      while (token = tokens.shift) && id.length < 4
        if id.empty?
          id << token[0..2].capitalize
        else
          id << token[0].upcase
        end
      end
      id
    end

    def make_album(release:, artist:)
      album = @collection.albums[release.id]
      discs = release.format_quantity || 1
      if album
        raise Error, "Album already exists" if discs == 1
        disc = @prompt.select('Disc?', (1..discs).to_a)
      else
        album = Collection::Album.new(
          id: release.id,
          title: release.title,
          artist_name: release.artist,
          artist_id: artist.id,
          year: release.original_release_year,
          discs: discs > 1 ? discs : nil,
          json_file: @collection.albums.json_file_for_id(release.id))
        disc = nil
      end
      [album, disc]
    end

    def make_tracks(album:, disc:, release:, source_dir:)
      album.tracks ||= []
      copy_plan = {}
      source_dir.children.select(&:file?).reject(&:hidden?).reject { |f| f.basename.to_s == 'info.json' }.sort.each do |source_file|
        type = MIME::Types.of(source_file.to_s).first&.media_type
        dest_file = case type
        when 'audio'
          track = make_track(file: source_file, album: album, disc: disc, release: release)
          album.tracks << track
          track.file
        else
          source_file.basename
        end
        copy_plan[source_file] = album.dir / dest_file
      end
      raise Error, "No tracks were added to album" if album.tracks.empty?
      copy_plan
    end

    def make_track(file:, album:, disc:, release:)
      tags = Tags.load(file)
      release_track = tags[:title] ? release.find_track_for_title(tags[:title]) : nil
      unless release_track
        puts "Can't find release track with title #{tags[:title].inspect}"
        choices = release.tracklist.all_tracks.to_h { |t| [t.title, t] }
        release_track = @prompt.select('Track?', choices, per_page: 50)
      end
      name = '%s%02d - %s' % [
        disc ? ('%1d-' % disc) : '',
        tags[:track],
        release_track.title.gsub(%r{[/:]}, '_'),
      ]
      album_track = Collection::Track.new(
        title: release_track.title,
        artist_name: release_track.artist || release.artist,
        track_num: tags[:track],
        disc_num: disc || tags[:disc],
        file: Path.new(name).add_extension(file.extname),
        album: album)
      puts "%-45s => %6s - %-45s => %-45s" % [
        file.basename,
        release_track.position,
        release_track.title,
        album_track.file,
      ]
      album_track
    end

    def select_cover(album:, release:)
      choices = [
        release.master&.images&.map(&:file),
        release.images&.map(&:file),
        album.cover_file,
      ].flatten.compact.uniq.select(&:exist?)
      if choices.empty?
        warn "no covers exist"
        return
      end
      choices.each { |f| run_command('open', f) }
      choice = @prompt.select('Cover?', choices)
      file = (album.dir / 'cover').add_extension(choice.extname)
      choice.cp(file) unless choice == file
    end

  end

end