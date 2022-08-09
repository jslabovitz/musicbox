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

      def <=>(other)
        @name <=> other.name
      end

    end

  end

end