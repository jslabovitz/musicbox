class MusicBox

  class Discogs

    AppName = 'musicbox-discogs'
    ResultsPerPage = 100

    def initialize(catalog:)
      @catalog = catalog
      @user, @token = @catalog.config.values_at('user', 'token')
      @ignore_folder_id = @catalog.config['ignore_folder_id']
      @discogs = ::Discogs::Wrapper.new(AppName, user_token: @token)
    end

    def update
      @catalog.collection.destroy!
      page = 1
      loop do
        result = discogs_do(:get_user_collection, @user, page: page, per_page: ResultsPerPage)
        result.releases.each do |release|
          begin
            update_release(release) unless @ignore_folder_id && release.folder_id == @ignore_folder_id
          rescue Error => e
            warn "Error: #{e}"
          end
        end
        page = result.pagination.page + 1
        break if page > result.pagination.pages
      end
    end

    def update_release(release)
      @catalog.collection.save_item(id: release.id, item: release)
      info = release.basic_information
      @catalog.releases.save_item_if_new(id: info.id) { discogs_do(:get_release, info.id) }
      if info.master_id && info.master_id > 0
        @catalog.masters.save_item_if_new(id: info.master_id) { discogs_do(:get_master_release, info.master_id) }
      end
    end

    def discogs_do(command, *args)
      sleep(1)
;;pp(command: command, args: args)
      result = @discogs.send(command, *args)
      raise Error, "Bad result: #{result.inspect}" if result.nil? || result.message
      result
    end

  end

end