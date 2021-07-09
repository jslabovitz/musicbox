class MusicBox

  class Catalog

    attr_accessor :root_dir
    attr_accessor :import_dir
    attr_accessor :import_done_dir
    attr_accessor :extract_dir
    attr_accessor :extract_done_dir
    attr_accessor :catalog_dir
    attr_accessor :config
    attr_accessor :collection
    attr_accessor :releases
    attr_accessor :masters
    attr_accessor :artists
    attr_accessor :albums
    attr_accessor :groups

    def initialize(root: nil)
      @root_dir = Path.new(root || ENV['MUSICBOX_ROOT'] || '~/Music/MusicBox').expand_path
      raise Error, "#{@root_dir} doesn't exist" unless @root_dir.exist?
      load_config
      @import_dir = @root_dir / 'import'
      @import_done_dir = @root_dir / 'import-done'
      @extract_dir = @root_dir / 'extract'
      @extract_done_dir = @root_dir / 'extract-done'
      @catalog_dir = @root_dir / 'catalog'
      @collection = Collection.new(root: @catalog_dir / 'collection')
      @releases = Releases.new(root: @catalog_dir / 'releases')
      @masters = Releases.new(root: @catalog_dir / 'masters')
      @artists = Artists.new(root: @catalog_dir / 'artists')
      @albums = Albums.new(root: @catalog_dir / 'albums')
      link_groups
      @prompt = TTY::Prompt.new
    end

    def load_config
      @config = YAML.load((@root_dir / 'config.yaml').read)
      ReleaseArtist.class_variable_set(:@@personal_names, @config['personal_names'])
      ReleaseArtist.class_variable_set(:@@canonical_names, @config['canonical_names'])
    end

    def orphaned
      orphaned = %i[releases masters artists albums].map { |k| [k, send(k).items.dup] }.to_h
      @collection.items.each do |item|
        release = item.release or raise
        orphaned[:releases].delete(release)
        orphaned[:masters].delete(release.master) if release.master
        release.artists.each do |release_artist|
          orphaned[:artists].delete(release_artist.artist)
        end
        orphaned[:albums].delete(release.album) if release.album
      end
      orphaned
    end

    def artist_keys(artists)
      keys = {}
      names = {}
      non_personal_names = Set.new
      artists.map { |a| a.kind_of?(ReleaseArtist) ? a : ReleaseArtist.new(name: a) }.each do |artist|
        non_personal_names << artist.name if artist.name == artist.canonical_name
        key = artist.key
        (keys[key] ||= Set.new) << artist.name
        (names[artist.name] ||= Set.new) << key
      end
      {
        non_personal_names: non_personal_names.sort,
        keys: keys.sort.map { |k, s| [k, s.to_a] }.to_h,
        names: names.sort.map { |k, s| [k, s.to_a] }.to_h,
      }
    end

    def find_dups(releases)
      dups = {}
      releases.select(&:master_id).each do |release|
        dups[release.master_id] ||= {}
        dups[release.master_id][release.primary_format_name] ||= []
        dups[release.master_id][release.primary_format_name] << release
      end
      dups
    end

    def find(*selectors, group: nil, prompt: false, multiple: true)
      unless group.kind_of?(Group)
        group = case group&.to_sym
        when :releases, nil
          @releases
        when :masters
          @masters
        when :albums
          @albums
        else
          raise Error, "Unknown group: #{group.inspect}"
        end
      end
      ;;puts "searching #{group.items.count} items in #{group.class}"
      selectors = [selectors].compact.flatten
      selectors = [':all'] if selectors.empty?
      selected = []
      selectors.each do |selector|
        case selector.to_s
        when ':all'
          selected += group.items
        when ':recent'
          selected += group.items.select { |c| (Date.today - c.date_added) < 7 }
        when ':multidisc'
          selected += group.items.select(&:multidisc?)
        when ':cd'
          selected += group.items.select(&:cd?)
        when ':unripped'
          selected += group.items.select(&:cd?).reject(&:album)
        when ':odd-positions'
          selected += group.items.select(&:cd?).select { |r| r.tracklist_flattened.find { |t| t.position !~ /^\d+$/ } }
        when /^-?\d+$/
          n = selector.to_i
          item = group[n.abs] or raise Error, "Can't find item #{selector.inspect} in #{group.class}"
          if n > 0
            selected += [group[n]]
          else
            selected -= [group[-n]]
          end
        else
          selected += group.search(query: selector.to_s, fields: [:title, :artists, :id])
        end
      end
      selected.uniq.sort!
      if prompt
        choices = selected.map { |r| [r.to_s, r.id] }.to_h
        if multiple
          ids = @prompt.multi_select('Item?', filter: true, per_page: 100, quiet: true) do |menu|
            # menu.default *(1..choices.length).to_a
            choices.each do |name, value|
              menu.choice name, value
            end
          end
          selected = ids.map { |id| group[id] }
        else
          id = @prompt.select('Item?', choices, filter: true, per_page: 100, quiet: true)
          selected = [group[id]] if id
        end
      end
      selected
    end

    def link_groups
      @releases.items.each do |release|
        release.master = @masters[release.master_id] if release.master_id
        release.artists.each do |release_artist|
          release_artist.artist = @artists[release_artist.id]
        end
        release.album = @albums[release.id]
      end
      @collection.items.each do |item|
        item.release = @releases[item.id]
      end
    end

    def categorize_files(dir)
      categories = {}
      dir.children.sort.each do |path|
        type = case (ext = path.extname.downcase)
        when '.m4a', '.m4p', '.mp3'
          :audio
        else
          ext.delete_prefix('.').to_sym
        end
        categories[type] ||= []
        categories[type] << path
      end
      categories
    end

    def dirs_for_args(base_dir, args)
      if args.empty?
        dirs = base_dir.children.select(&:dir?)
      else
        dirs = args.map { |p| Path.new(p) }
      end
      dirs.sort_by { |d| d.to_s.downcase }
    end

  end

end