class MusicBox

  class Discogs

    class Image

      attr_accessor :type
      attr_reader   :uri
      attr_reader   :uri150
      attr_accessor :width
      attr_accessor :height
      attr_reader   :file  # synthetic

      include SetParams

      def uri=(uri)
        @uri = URI.parse(uri)
      end

      def uri150=(uri)
        @uri150 = URI.parse(uri)
      end

      def file=(file)
        @file = Path.new(file)
      end

      def resource_url=(url)
        # ignored -- deprecated?
      end

      def primary?
        @type == 'primary'
      end

      def secondary?
        @type == 'secondary'
      end

    end

  end

end