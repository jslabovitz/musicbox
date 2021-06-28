module MusicBox

  class Discogs

    AppName = 'musicbox-discogs'
    ResultsPerPage = 100

    def initialize(catalog:)
      @catalog = catalog
      @user, @token = @catalog.config.values_at('user', 'token')
      @discogs = ::Discogs::Wrapper.new(AppName, user_token: @token)
    end

    def update
      update_group(:collection)
      update_group(:wantlist)
    end

    def update_group(group)
      clean(group)
      page = 1
      loop do
        ;;warn "** getting #{group}, page #{page}"
        sleep(1)
        result = @discogs.send(:"get_user_#{group}", @user, page: page, per_page: ResultsPerPage)
        raise "Bad result: #{result.inspect}" if result.nil? || result.message
        releases = case group
        when :collection
          result.releases
        when :wantlist
          result.wants
        end
        releases.each do |release|
          store(group, release.id, release)
          update_release(release)
        end
        page = result.pagination.page + 1
        break if page > result.pagination.pages
      end
    end

    def update_release(release)
      info = release.basic_information
      store(:releases, info.id) { @discogs.get_release(info.id) }
      if info.master_id && info.master_id > 0
        store(:masters, info.master_id) { @discogs.get_master_release(info.master_id) }
      end
      info.artists.each do |artist|
        store(:artists, artist.id) { @discogs.get_artist(artist.id) }
      end
    end

    def clean(group)
      dir = @catalog.catalog_dir / group
      dir.rmtree if dir.exist?
    end

    def store(group, id, result=nil, &block)
      dir = @catalog.catalog_dir / group
      dir.mkpath unless dir.exist?
      file = (dir / id).add_extension('.json')
      unless file.exist?
        ;;warn "=> #{file}"
        if block_given?
          sleep(1)
          result = yield
        end
        if result && !result.message
          file.write(JSON.pretty_generate(result))
        else
          warn result.inspect
        end
      end
    end

  end

end