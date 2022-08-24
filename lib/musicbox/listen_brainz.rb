class MusicBox

  class ListenBrainz

    def initialize
      @user = $musicbox.config.fetch(:musicbrainz, :user)
      @token = $musicbox.config.fetch(:musicbrainz, :token)
    end

    def submit_listen(submission)
      request(:post, '/1/submit-listens', submission)
    end

    def listens
      request(:get, "/1/user/#{@user}/listens")
    end

    def similar_users
      request(:get, "/1/user/#{@user}/similar-users")
    end

    def recommendations
      request(:get, "/1/cf/recommendation/user/#{@user}/recording", artist_type: :similar)
    end

    private

    def request(method, url, request=nil)
# ;;pp(method: method, url: url, request: request)
      sleep(1)
      conn = Faraday.new('https://api.listenbrainz.org') do |c|
        c.adapter  :net_http
        # c.response :logger
        c.response :raise_error
      end
      conn.headers[:authorization] = "Token #{@token}"
      begin
        json = case method
        when :get
          conn.get(url, request)
        when :post
          conn.post(url, request.to_json)
        else
          raise
        end.body
      rescue Faraday::BadRequestError => e
        raise "bad request: #{e}"
      end
# ;;pp(json: json)
      if json.empty?
        nil
      else
        JSON.parse(json, symbolize_names: true)
      end
    end

  end

end