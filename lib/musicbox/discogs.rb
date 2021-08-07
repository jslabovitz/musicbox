class MusicBox

  class Discogs

    attr_accessor :user
    attr_accessor :token
    attr_accessor :ignore_folder_id
    attr_accessor :root_dir
    attr_accessor :images_dir
    attr_accessor :collection
    attr_accessor :releases
    attr_accessor :masters

    AppName = 'musicbox-discogs'
    ResultsPerPage = 100

    include SetParams

    def initialize(params={})
      set(params)
      @root_dir = Path.new(@root_dir)
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

    def update
      raise Error, "Must specify user" unless @user
      @collection.destroy!
      page = 1
      loop do
        result = discogs_do(:get_user_collection, @user, page: page, per_page: ResultsPerPage)
        result.releases.each do |hash|
          item = CollectionItem.new(hash)
          if @ignore_folder_id && item.folder_id == @ignore_folder_id
            puts "ignoring collection item #{item.id}"
            next
          end
          if @collection[item.id]
            puts "skipping duplicate collection item #{item.id}"
            next
          end
          puts "updating collection item #{item.id}"
          @collection.save_hash(hash)
          release_id = item.basic_information.id
          master_id = item.basic_information.master_id
          begin
            unless @releases[release_id]
              @releases.save_hash(discogs_do(:get_release, release_id))
            end
            if master_id && master_id > 0 && !@masters[master_id]
              @masters.save_hash(discogs_do(:get_master_release, master_id))
            end
          rescue Error => e
            warn "Error: #{e}"
          end
        end
        page = result.pagination.page + 1
        break if page > result.pagination.pages
      end
      [@releases, @masters].each do |group|
        group.items.each do |release|
          release.download_images
        end
      end
    end

    def discogs_do(command, *args)
      sleep(1)
;;pp(command: command, args: args)
      raise Error, "Must specify user token" unless @token
      @wrapper ||= ::Discogs::Wrapper.new(AppName, user_token: @token)
      result = @wrapper.send(command, *args)
      raise Error, "Bad result: #{result.inspect}" if result.nil? || result.message
      result
    end

  end

end