class MusicBox

  class Catalog

    attr_accessor :root_dir
    attr_accessor :images_dir
    attr_accessor :collection
    attr_accessor :releases
    attr_accessor :masters

    def initialize(root_dir:)
      @root_dir = Path.new(root_dir)
      raise Error, "#{@root_dir} doesn't exist" unless @root_dir.exist?
      @collection = Collection.new(root: @root_dir / 'collection')
      @releases = Releases.new(root: @root_dir / 'releases')
      @masters = Releases.new(root: @root_dir / 'masters')
      @images_dir = @root_dir / 'images'
      link_groups
    end

    def orphaned
      orphaned = {
        releases: @releases.items.dup,
        masters: @masters.items.dup,
      }
      @collection.items.each do |item|
        release = item.release or raise Error, "No release for collection item ID #{item.id}"
        orphaned[:releases].delete(release)
        orphaned[:masters].delete(release.master) if release.master
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
        collection_item = @collection[release.id] or raise
        collection_item.release = release
      end
    end

  end

end