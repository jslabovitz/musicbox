class MusicBox

  class Collection

    class Artist < Group::Item

      attr_accessor :id
      attr_accessor :name
      attr_accessor :aliases
      attr_accessor :personal

      def initialize(**)
        @aliases = []
        super
      end

    end

  end

end