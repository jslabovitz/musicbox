class MusicBox

  class Discogs

    class Release < Simple::Group::Item

      include Simple::Printer::Printable

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

      def artists=(artists)
        @artists = ArtistList.new(artists.map { |a| Artist.new(a) })
      end

      def extraartists=(artists)
        @extraartists = artists.map { |a| Artist.new(a) }
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

      def images=(images)
        @images = images.map { |i| Image.new(i) }
      end

      def tracklist=(tracklist)
        @tracklist = TrackList.new(tracklist.map { |t| Track.new(t) })
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

      def odd_positions?
        @tracklist.flatten.find { |t| t.position !~ /^\d+$/ }
      end

      def artist
        @artists.to_s
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

      def inspect
        "\#<#{self.class}:#{'0x%x' % object_id}>"
      end

      def to_s
        summary
      end

      def summary
        '%-8s | %-4s %4s | %-50.50s | %-50.50s | %-6s' % [
          @id,
          artist_key,
          original_release_year || '-',
          artist,
          @title,
          @formats ? Format.to_s(@formats) : '-',
        ]
      end

      def printable
        [
          [:id, 'ID', @id],
          [:master_id, 'Master ID', @master_id || '-'],
          [:artists, 'Artist', @artists.to_s],
          :title,
          [:formats, 'Formats', Format.to_s(@formats)],
          [:release_year, 'Released', release_year || '-'],
          [:original_release_year, 'Originally released', original_release_year || '-'],
          [:uri, 'Discogs URI', @uri || '-'],
          [:tracklist, 'Tracks'],
        ]
      end

      def find_track_for_title(title)
        normalized_title = title.normalize
        @tracklist.flatten.find { |t| t.title.normalize == normalized_title }
      end

      def link_images(images_dir)
        if @images
          @images.each do |image|
            image.file = images_dir / Path.new(image.uri.path).basename
          end
        end
      end

      def download_images
        if @images
          image = @images.find(&:primary?)
          if image
            download_image(uri: image.uri, file: image.file)
          else
            @images.each do |image|
              download_image(uri: image.uri, file: image.file)
            end
          end
        end
        @master.download_images if @master
      end

      def download_image(uri:, file:)
        if uri && file
          unless file.exist?
            puts "#{@id}: downloading #{uri}"
            file.dirname.mkpath unless file.dirname.exist?
            file.write(HTTP.get(uri))
            sleep(1)
          end
        end
      end

    end

  end

end