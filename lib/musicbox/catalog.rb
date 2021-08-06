class MusicBox

  class Catalog

    attr_accessor :root_dir
    attr_accessor :import_dir
    attr_accessor :import_done_dir
    attr_accessor :catalog_dir
    attr_accessor :images_dir
    attr_accessor :config
    attr_accessor :collection
    attr_accessor :releases
    attr_accessor :masters
    attr_accessor :albums
    attr_accessor :groups

    def initialize(root: nil)
      @root_dir = Path.new(root || ENV['MUSICBOX_ROOT'] || '~/Music/MusicBox').expand_path
      raise Error, "#{@root_dir} doesn't exist" unless @root_dir.exist?
      load_config
      @import_dir = @root_dir / 'import'
      @import_done_dir = @root_dir / 'import-done'
      @catalog_dir = @root_dir / 'catalog'
      @collection = Collection.new(root: @catalog_dir / 'collection')
      @releases = Releases.new(root: @catalog_dir / 'releases')
      @masters = Releases.new(root: @catalog_dir / 'masters')
      @albums = Albums.new(root: @catalog_dir / 'albums')
      @images_dir = @catalog_dir / 'images'
      link_groups
      @prompt = TTY::Prompt.new
    end

    def load_config
      @config = YAML.load((@root_dir / 'config.yaml').read)
      Artist.class_variable_set(:@@personal_names, @config['personal_names'])
      Artist.class_variable_set(:@@canonical_names, @config['canonical_names'])
    end

    def orphaned
      orphaned = %i[releases masters albums].map { |k| [k, send(k).items.dup] }.to_h
      @collection.items.each do |item|
        release = item.release or raise
        orphaned[:releases].delete(release)
        orphaned[:masters].delete(release.master) if release.master
        orphaned[:albums].delete(release.album) if release.album
      end
      orphaned
    end

    def orphaned_image_files
      all_files = [@releases, @masters].map do |group|
        group.items.select(&:images).map do |release|
          release.images.map { |image| image.file.basename.to_s }
        end
      end.flatten.compact
      @images_dir.children.map(&:basename).map(&:to_s) - all_files
    end

    def link_groups
      @releases.items.each do |release|
        release.master = @masters[release.master_id] if release.master_id
        release.album = @albums[release.id]
        release.link_images(@images_dir)
        release.master&.link_images(@images_dir)
      end
      @collection.items.each do |item|
        item.release = @releases[item.id] or raise Error, "Can't find release for collection item ID #{item.id.inspect}"
        item.album = @albums[item.id]
        if item.album
          item.album.collection_item = item
          item.album.release = item.release
        else
          warn "No album: #{item.release}"
        end
      end
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