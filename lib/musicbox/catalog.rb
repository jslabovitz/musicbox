module MusicBox

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
      @collection = Catalog::Collection.new(root: @catalog_dir / 'collection')
      @releases = Catalog::Releases.new(root: @catalog_dir / 'releases')
      @masters = Catalog::Releases.new(root: @catalog_dir / 'masters')
      @artists = Catalog::Artists.new(root: @catalog_dir / 'artists')
      @albums = Catalog::Albums.new(root: @catalog_dir / 'albums')
      link_groups
    end

    def load_config
      @config = YAML.load((@root_dir / 'config.yaml').read)
      Catalog::ReleaseArtist.class_variable_set(:@@personal_names, @config['personal_names'])
      Catalog::ReleaseArtist.class_variable_set(:@@canonical_names, @config['canonical_names'])
    end

    def make_cover(args, output_file: '/tmp/cover.pdf')
      albums = find_releases(args).map(&:album).compact.select(&:has_cover?)
      size = 4.75.in
      top = 10.in
      Prawn::Document.generate(output_file) do |pdf|
        albums.each do |album|
          puts album
          pdf.fill do
            pdf.rectangle [0, top],
              size,
              size
          end
          pdf.image album.cover_file.to_s,
            at: [0, top],
            width: size,
            fit: [size, size],
            position: :center
          pdf.stroke do
            pdf.rectangle [0, top],
              size,
              size
          end
        end
      end
      run_command('open', output_file)
    end

    def get_cover(args)
      find_releases(args).select(&:cd?).each do |release|
        puts release
        [release, release.master].compact.each(&:get_images)
      end
    end

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
      orphaned.each do |group, items|
        unless items.empty?
          puts "#{group}:"
          items.sort.each do |item|
            puts item.summary_to_s
          end
          puts
        end
      end
    end

    def make_csv(args)
      print %w[ID year artist title].to_csv
      find_releases(args).select(&:cd?).each do |release|
        print [release.id, release.original_release_year, release.artist, release.title].to_csv
      end
    end

    def fix(args)
      # key_map = {
      #   :title => :title,
      #   :artist => :artist,
      #   :original_release_year => :year,
      #   :format_quantity => :discs,
      # }
      # find_releases(args).select(&:cd?).each do |release|
      #   diffs = {}
      #   key_map.each do |release_key, album_key|
      #     release_value = release.send(release_key)
      #     album_value = release.album.send(album_key)
      #     if album_value && release_value != album_value
      #       diffs[release_key] = [release_value, album_value]
      #     end
      #   end
      #   unless diffs.empty?
      #     puts release
      #     diffs.each do |key, values|
      #       puts "\t" + '%s: %p => %p' % [key, *values]
      #     end
      #     puts
      #   end
      # end
    end

    def dir(args, open: false)
      find_releases(args).each do |release|
        puts "%-10s %s" % [release.id, release.dir]
        run_command('open', release.dir) if open
      end
    end

    def update_tags(args, force: false)
      find_releases(args).each do |release|
        album = release.album or raise
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
        if show_details
          puts release.details_to_s
          puts
        else
          puts release.summary_to_s
        end
      end
    end

    def find_dups(releases)
      dups = {}
      releases.each do |release|
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
        when ':cd'
          releases += @releases.items.select(&:cd?)
        when ':unripped'
          releases += @releases.items.select(&:cd?).reject(&:album)
        when ':odd-positions'
          releases += @releases.items.select { |r|
            r.cd? && r.tracklist_actual_tracks.find { |t| t.position !~ /^\d+$/ }
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
        type = case (ext = path.extname.delete_prefix('.').downcase)
        when 'm4a', 'm4p', 'mp3'
          :audio
        else
          ext.to_sym
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