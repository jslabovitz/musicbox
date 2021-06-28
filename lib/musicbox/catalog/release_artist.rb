module MusicBox

  class Catalog

    class ReleaseArtist

      attr_accessor :active
      attr_accessor :anv
      attr_accessor :id
      attr_accessor :join
      attr_accessor :name
      attr_accessor :resource_url
      attr_accessor :role
      attr_accessor :thumbnail_url
      attr_accessor :tracks
      attr_accessor :artist    # linked on load

      def self.artists_to_s(artists)
        artists.map do |artist|
          artist.name + ((artist.join == ',') ? artist.join : (' ' + artist.join))
        end.flatten.join(' ').squeeze(' ').strip
      end

      def initialize(params={})
        params.each { |k, v| send("#{k}=", v) }
      end

      def to_s
        @name
      end

      def canonical_name
        name = (@@canonical_names[@name] || @name).sub(/\s\(\d+\)/, '')  # handle 'Nico (3)'
        if @@personal_names.include?(name)
          elems = name.split(/\s+/)
          [elems[-1], elems[0..-2].join(' ')].join(', ')
        else
          name
        end
      end

      def key
        key = ''
        tokens = canonical_name.tokenize
        while (token = tokens.shift) && key.length < 4
          if key.empty?
            key << token[0..2].capitalize
          else
            key << token[0].upcase
          end
        end
        key
      end

    end

  end

end