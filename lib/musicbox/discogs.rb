class MusicBox

  class Discogs

    attr_accessor :catalog
    attr_accessor :user
    attr_accessor :token
    attr_accessor :ignore_folder_id

    AppName = 'musicbox-discogs'
    ResultsPerPage = 100

    include SetParams

    def initialize(params={})
      set(params)
      raise Error, "Must specify catalog" unless @catalog
      raise Error, "Must specify user/token" unless @user && @token
      @discogs = ::Discogs::Wrapper.new(AppName, user_token: @token)
    end

    def update
      @catalog.collection.destroy!
      page = 1
      loop do
        result = discogs_do(:get_user_collection, @user, page: page, per_page: ResultsPerPage)
        result.releases.each do |hash|
          item = Catalog::CollectionItem.new(hash)
          if @ignore_folder_id && item.folder_id == @ignore_folder_id
            puts "ignoring collection item #{item.id}"
            next
          end
          if @catalog.collection[item.id]
            puts "skipping duplicate collection item #{item.id}"
            next
          end
          puts "updating collection item #{item.id}"
          @catalog.collection.save_hash(hash)
          release_id = item.basic_information.id
          master_id = item.basic_information.master_id
          begin
            unless @catalog.releases[release_id]
              @catalog.releases.save_hash(discogs_do(:get_release, release_id))
            end
            if master_id && master_id > 0 && !@catalog.masters[master_id]
              @catalog.masters.save_hash(discogs_do(:get_master_release, master_id))
            end
          rescue Error => e
            warn "Error: #{e}"
          end
        end
        page = result.pagination.page + 1
        break if page > result.pagination.pages
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