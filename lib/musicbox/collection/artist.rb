class MusicBox

  class Collection

    class Artist < Simple::Group::Item

      attr_accessor :id
      attr_accessor :name
      attr_accessor :aliases
      attr_accessor :personal

      def initialize(**)
        @aliases = []
        super
      end

      def personal?
        @personal == true
      end

      def <=>(other)
        @id <=> other.id
      end

      def to_h
        super.merge(
          name: @name,
          aliases: @aliases,
          personal: @personal,
        )
      end

      def summary
        '%-4s | %-30s | %-90s | %1s' % [
          @id,
          @name,
          @aliases.join('; '),
          @personal ? 'Y' : 'N',
        ]
      end

      def printable
        [
          [:id, 'ID'],
          [:name, 'Name'],
          [:aliases, 'Aliases', @aliases],
          :personal,
        ]
      end

    end

  end

end