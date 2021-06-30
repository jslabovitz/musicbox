module MusicBox

  class Catalog

    attr_accessor :root_dir
    attr_accessor :import_dir
    attr_accessor :import_done_dir
    attr_accessor :extract_dir
    attr_accessor :extract_done_dir
    attr_accessor :catalog_dir
    attr_accessor :config
    attr_accessor :albums
    attr_accessor :collection
    attr_accessor :wantlist
    attr_accessor :releases
    attr_accessor :masters
    attr_accessor :artists

    def initialize(root: nil)
      @root_dir = Path.new(root || ENV['MUSICBOX_ROOT'] || '~/Music/MusicBox').expand_path
      raise Error, "#{@root_dir} doesn't exist" unless @root_dir.exist?
      load_config
      @import_dir = @root_dir / 'import'
      @import_done_dir = @root_dir / 'import-done'
      @extract_dir = @root_dir / 'extract'
      @extract_done_dir = @root_dir / 'extract-done'
      @catalog_dir = @root_dir / 'catalog'
      @albums = Catalog::Albums.new(root: @catalog_dir / 'albums', mode: :dir)
      @collection = Catalog::References.new(root: @catalog_dir / 'collection', mode: :file)
      @wantlist = Catalog::References.new(root: @catalog_dir / 'wantlist', mode: :file)
      @releases = Catalog::Releases.new(root: @catalog_dir / 'releases', mode: :file)
      @masters = Catalog::Releases.new(root: @catalog_dir / 'masters', mode: :file)
      @artists = Catalog::Artists.new(root: @catalog_dir / 'artists', mode: :file)
      link_groups
    end

    def load_config
      @config = YAML.load((@root_dir / 'config.yaml').read)
      Catalog::ReleaseArtist.class_variable_set(:@@personal_names, @config['personal_names'])
      Catalog::ReleaseArtist.class_variable_set(:@@canonical_names, @config['canonical_names'])
    end

    LocationCodes = {
      collection: 'C',
      wantlist: 'W',
    }

    def show(args, show_details: false)
      show_releases(find_releases(args), show_details: show_details)
    end

    def show_dups(args)
      dups = find_dups(find_releases(args))
      dups.each do |id, formats|
        formats.each do |format, releases|
          if releases.length > 1
            puts
            show_releases(releases)
          end
        end
      end
    end

    def show_orphaned
      orphaned_releases = @releases.items.dup
      orphaned_masters = @masters.items.dup
      orphaned_artists = @artists.items.dup
      orphaned_albums = @albums.items.dup
      (@collection.items + @wantlist.items).each do |item|
        release = item.release or raise
        orphaned_releases.delete(release)
        orphaned_masters.delete(release.master) if release.master
        release.artists.each do |release_artist|
          orphaned_artists.delete(release_artist.artist)
        end
        orphaned_albums.delete(release.album) if release.album
      end
      unless orphaned_releases.empty?
        puts "Orphaned releases:"
        orphaned_releases.sort.each do |release|
          puts release
        end
        puts
      end
      unless orphaned_masters.empty?
        puts 'Orphaned masters:'
        orphaned_masters.sort.each do |master|
          puts master
        end
        puts
      end
      unless orphaned_artists.empty?
        puts 'Orphaned artists:'
        orphaned_artists.sort.each do |artist|
          puts artist
        end
        puts
      end
      unless orphaned_albums.empty?
        puts 'Orphaned albums:'
        orphaned_albums.sort.each do |album|
          puts album
        end
        puts
      end
    end

    def make_csv(args)
      print %w[ID year artist title].to_csv
      find_releases(args).each do |release|
        if release.cd? && release_in_collection?(release)
          print [release.id, release.original_release_year, release.artist, release.title].to_csv
        end
      end
    end

    def fix(args)
    end

    def dir(args, open: false)
      find_releases(args).each do |release|
        puts "%-10s %s" % [release.id, release.album ? release.album.dir : '-']
        run_command('open', release.album.dir) if release.album && open
      end
    end

    def update_tags(args, force: false)
      if args.empty?
        albums = @albums.items
      else
        albums = args.map { |a| @albums[a.to_i] }
      end
      albums.each do |album|
        album.update_tags(force: force)
      end
    end

    def make_artist_keys(args)
      if args.empty?
        args = @releases.items.map { |r| r.artists.map(&:name) }.flatten
      end
      by_key = {}
      by_name = {}
      non_personal_names = Set.new
      args.map { |a| ReleaseArtist.new(name: a) }.each do |artist|
        non_personal_names << artist.name if artist.name == artist.canonical_name
        key = artist.key
        (by_key[key] ||= Set.new) << artist.name
        (by_name[artist.name] ||= Set.new) << key
      end
      ;;pp non_personal_names.sort
      ;;pp by_key.sort.map { |k, s| [k, s.to_a] }.to_h
      ;;pp by_name.sort.map { |k, s| [k, s.to_a] }.to_h
    end

    def select(args)
      ids = []
      loop do
        releases = find_releases(args)
        case (choice = MusicBox.prompt(releases))
        when Numeric
          ids << releases[choice].id
          puts ids.join(' ')
        when String
          args = choice.split(/\s+/)
        when nil
          break
        end
      end
    end

    def show_releases(releases, show_details: false)
      releases.each do |release|
        locations = release_locations(release)
        if show_details
          puts release.details_to_s(locations: locations.join(', '))
          puts
        else
          puts release.summary_to_s(locations: locations.map { |loc| LocationCodes[loc] }.join)
        end
      end
    end

    def find_dups(releases)
      dups = {}
      releases.select { |r| release_in_collection?(r) }.each do |release|
        if release.master_id
          dups[release.master_id] ||= {}
          dups[release.master_id][release.primary_format_name] ||= []
          dups[release.master_id][release.primary_format_name] << release
        end
      end
      dups.each do |id, formats|
        formats.each do |format, releases|
          if releases.length > 1
            puts
            show_releases(releases)
          end
        end
      end
    end

    def find_releases(selectors)
      selectors = [':all'] if selectors.nil? || selectors.empty?
      releases = []
      selectors.each do |selector|
        case selector.to_s
        when ':all'
          releases += @releases.items
        when ':recent'
          releases += @releases.items.select { |c| (Date.today - c.date_added) < 7 }
        when ':multidisc'
          releases += @releases.items.select(&:multidisc?)
        when ':unripped'
          releases += @releases.items.select { |r|
            if release_in_collection?(r) && r.primary_format.cd?
              !r.album || r.album.tracks.select { |t| t.path.exist? }.empty?
            end
          }
        when /^-?\d+$/
          n = selector.to_i
          if n > 0
            releases += [@releases[n]]
          else
            releases -= [@releases[-n]]
          end
        else
          releases += @releases.search(query: selector.to_s, fields: [:title, :artists, :id])
        end
      end
      releases.uniq.sort!
    end

    def prompt_releases(query)
      loop do
        choices = @releases.search(
          query: [query].flatten.join(' '),
          fields: [:title, :artists],
          limit: 20).select(&:cd?)
        choice = MusicBox.prompt(choices)
        case choice
        when Numeric
          return [choices[choice]]
        when /^[\d,]+/
          return choices.values_at(*choice.split(',').map(&:to_i))
        when nil
          return nil
        when String
          query = choice
        end
      end
    end

    def release_locations(release)
      locations = []
      locations << :collection if release_in_collection?(release)
      locations << :wantlist if release_in_wantlist?(release)
      locations
    end

    def release_in_collection?(release)
      @collection[release.id] != nil
    end

    def release_in_wantlist?(release)
      @wantlist[release.id] != nil
    end

    def link_groups
      @releases.items.each do |release|
        release.master = @masters[release.master_id] if release.master_id
        release.artists.each do |release_artist|
          release_artist.artist = @artists[release_artist.id]
        end
        if (release.album = @albums[release.id])
          release.album.release = release
        end
      end
      (@collection.items + @wantlist.items).each do |item|
        item.release = @releases[item.id]
      end
    end

  end

end