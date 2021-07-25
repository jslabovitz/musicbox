class MusicBox

  class Catalog

    class Format

      attr_accessor :descriptions
      attr_accessor :name
      attr_accessor :qty
      attr_accessor :text

      include SetParams

      def self.to_s(formats)
        formats.map(&:short_to_s).join(', ')
      end

      def qty=(n)
        @qty = n.to_i
      end

      def to_s
        @name + descriptions_to_s + qty_to_s
      end

      def short_to_s
        @name + qty_to_s
      end

      def descriptions_to_s
        @descriptions ? " (#{@descriptions.join(', ')})" : ''
      end

      def qty_to_s
        (@qty && @qty > 1) ? " [#{@qty}]" : ''
      end

    end

  end

end