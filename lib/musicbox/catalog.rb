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
      link_albums
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
      end
      @albums.items.each do |album|
        orphaned[:albums].delete(album) if @releases[album.id]
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
        release.link_images(@images_dir)
        release.master&.link_images(@images_dir)
        if (album = @albums[release.id])
          album.release = release
        else
          warn "No album for release ID #{release.id.inspect}"
        end
        collection_item = @collection[release.id] or raise
        collection_item.release = release
      end
    end

    def link_albums
      @albums.items.each do |album|
        album.release = @releases[album.id] or raise Error, "No release for album ID #{album.id}"
      end
    end

  end

end