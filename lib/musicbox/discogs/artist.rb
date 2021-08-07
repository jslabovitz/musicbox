class MusicBox

  class Discogs

    class Artist

      attr_accessor :active
      attr_accessor :anv
      attr_accessor :id
      attr_accessor :join
      attr_accessor :name
      attr_accessor :resource_url
      attr_accessor :role
      attr_accessor :thumbnail_url
      attr_accessor :tracks

      include SetParams

      def self.join(artists)
        artists.map(&:name_for_join).join(' ').squeeze(' ').strip
      end

      def <=>(other)
        @name <=> other.name
      end

      def name_for_join
        [@name, (@join == ',' ? '' : ' '), @join].join
      end

      def summary
        cname = canonical_name
        '%8s | %-6s | %-40s | %-40s' % [
          @id,
          key,
          @name,
          (cname == @name) ? '-' : cname,
        ]
      end

      def canonical_name
        name = (MusicBox.config.fetch(:canonical_names)[@name] || @name).sub(/\s\(\d+\)/, '')  # handle 'Nico (3)'
        if MusicBox.config.fetch(:personal_names).include?(name)
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