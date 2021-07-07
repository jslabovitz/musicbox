class MusicBox

  class Catalog

    class Artist < Group::Item

      attr_accessor :aliases
      attr_accessor :data_quality
      attr_accessor :groups
      attr_accessor :images   #FIXME: make Image class?
      attr_accessor :members
      attr_accessor :name
      attr_accessor :namevariations
      attr_accessor :profile
      attr_accessor :realname
      attr_accessor :releases_url
      attr_accessor :resource_url
      attr_accessor :uri
      attr_accessor :urls

      def aliases=(aliases)
        @aliases = aliases.map { |a| ReleaseArtist.new(a) }
      end

      def groups=(groups)
        @groups = groups.map { |a| ReleaseArtist.new(a) }
      end

      def members=(members)
        @members = members.map { |a| ReleaseArtist.new(a) }
      end

      def to_s
        @name
      end

      def summary_to_s
        '%-8s | %s' % [
          @id,
          @name,
        ]
      end

      def <=>(other)
        @name <=> other.name
      end

    end

  end

end