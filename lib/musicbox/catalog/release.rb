class MusicBox

  class Catalog

    class Release < Group::Item

      attr_accessor :artists
      attr_accessor :artists_sort
      attr_accessor :blocked_from_sale
      attr_accessor :community
      attr_accessor :companies
      attr_accessor :country
      attr_accessor :data_quality
      attr_accessor :date_added
      attr_accessor :date_changed
      attr_accessor :estimated_weight
      attr_accessor :extraartists
      attr_accessor :format_quantity
      attr_accessor :formats
      attr_accessor :genres
      attr_accessor :identifiers
      attr_accessor :images
      attr_accessor :labels
      attr_accessor :lowest_price
      attr_accessor :main_release
      attr_accessor :main_release_url
      attr_accessor :master_id
      attr_accessor :master_url
      attr_accessor :most_recent_release
      attr_accessor :most_recent_release_url
      attr_accessor :notes
      attr_accessor :num_for_sale
      attr_accessor :released
      attr_accessor :released_formatted
      attr_accessor :resource_url
      attr_accessor :series
      attr_accessor :status
      attr_accessor :styles
      attr_accessor :thumb
      attr_accessor :tracklist
      attr_accessor :title
      attr_accessor :uri
      attr_accessor :versions_url
      attr_accessor :videos
      attr_accessor :year
      attr_accessor :master    # linked on load
      attr_accessor :album     # linked on load

      def self.csv_header
        %w[ID year artist title].to_csv
      end

      def artists=(artists)
        @artists = artists.map { |a| ReleaseArtist.new(a) }
      end

      def extraartists=(artists)
        @extraartists = artists.map { |a| ReleaseArtist.new(a) }
      end

      def date_added=(date)
        @date_added = DateTime.parse(date.to_s)
      end

      def date_changed=(date)
        @date_changed = DateTime.parse(date.to_s)
      end

      def formats=(formats)
        @formats = formats.map { |f| Format.new(f) }
      end

      def tracklist=(tracklist)
        @tracklist = tracklist.map { |t| Track.new(t) }
      end

      def primary_format
        @formats&.first
      end

      def primary_format_name
        primary_format&.name
      end

      def release_year
        if @year && @year != 0
          @year
        elsif @released
          @released.to_s.split('-').first&.to_i
        end
      end

      def original_release_year
        @master&.release_year || release_year
      end

      def multidisc?
        @formats.find(&:multidisc?) != nil
      end

      def cd?
        primary_format_name == 'CD'
      end

      def artist
        ReleaseArtist.artists_to_s(@artists)
      end

      def artist_key
        @artists.first.key
      end

      def <=>(other)
        sort_tuple <=> other.sort_tuple
      end

      def sort_tuple
        [artist_key, original_release_year || 0, @title]
      end

      def images_dir
        @dir / 'images'
      end

      def to_csv
        [@id, original_release_year, artist, @title].to_csv
      end

      def to_s
        summary_to_s
      end

      def summary_to_s
        '%-8s | %-4s %4s | %-50.50s | %-60.60s | %-6s | %1s' % [
          @id,
          artist_key,
          original_release_year || '-',
          artist,
          @title,
          primary_format_name,
          @album ? '*' : '',
        ]
      end

      def details_to_s
        info = [
          ['ID', @id],
          ['Master ID', @master_id],
          ['Artist', ReleaseArtist.artists_to_s(@artists)],
          ['Title', @title],
          ['Formats', Format.to_s(@formats)],
          ['Released', release_year || '-'],
          ['Originally released', original_release_year || '-'],
          ['Dir', @dir || '-'],
          ['Tracks', nil, tracklist_to_info],
        ]
        MusicBox.info_to_s(info)
      end

      def tracklist_flattened(tracklist=nil)
        tracklist ||= @tracklist
        tracks = []
        tracklist.each do |track|
          tracks << track
          tracks += tracklist_flattened(track.sub_tracks) if track.type == 'index'
        end
        tracks
      end

      def tracklist_to_info(tracklist=nil)
        tracklist ||= @tracklist
        max_position_length = tracklist.select(&:position).map { |t| t.position.to_s.length }.max
        tracklist.map do |track|
          [
            track.type,
            [
              !track.position.to_s.empty? ? ('%*s:' % [max_position_length, track.position]) : nil,
              track.title || '-',
              track.artists ? "(#{ReleaseArtist.artists_to_s(track.artists)})" : nil,
              !track.duration.to_s.empty? ? "[#{track.duration}]" : nil,
            ].compact.join(' '),
            track.sub_tracks ? tracklist_to_info(track.sub_tracks) : nil,
          ]
        end
      end

      def to_label
        {
          artist: artist,
          title: title,
          key: artist_key,
          year: original_release_year,
          format: primary_format_name,
          id: id,
        }
      end

      def get_images
        images_dir.mkpath unless images_dir.exist?
        @images.each do |image|
          uri = URI.parse(image['uri'])
          name = Path.new(uri.path).basename.to_s
          image_file = images_dir / name
          unless image_file.exist?
            puts "\t" + image_file.to_s
            image_file.write(HTTP.get(uri))
            sleep(1)
          end
        end
      end

    end

  end

end