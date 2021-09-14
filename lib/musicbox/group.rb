class MusicBox

  class Group

    attr_accessor :root

    InfoFileName = 'info.json'

    def self.item_class
      Item
    end

    def self.search_fields
      []
    end

    def initialize(root:)
      @root = Path.new(root).expand_path
      @items = {}
      if @root.exist?
        @root.glob("*/#{InfoFileName}").each do |info_file|
          raise Error, "Info file does not exist: #{info_file}" unless info_file.exist?
          item = self.class.item_class.new(json_file: info_file, **JSON.load(info_file.read))
          @items[item.id] = item
        end
        ;;warn "* loaded #{@items.length} items from #{@root}"
      end
    end

    def items
      @items.values
    end

    def [](id)
      @items[id]
    end

    def find(*selectors)
      ;;puts "searching #{self.class}"
      selectors = [selectors].compact.flatten
      if selectors.empty?
        selected = items
      else
        selected = []
        selectors.each do |selector|
          case selector.to_s
          when /^:(.*)$/
            begin
              selected += send("#{$1}?").call
            rescue NameError => e
              raise Error, "Unknown selector #{selector.inspect} in #{self.class}"
            end
          when /^-?\d+$/
            n = selector.to_i
            item = self[n.abs] or raise Error, "Can't find item #{selector.inspect} in #{self.class}"
            if n > 0
              selected += [item]
            else
              selected -= [item]
            end
          else
            selected += search(selector)
          end
        end
        selected.uniq!
      end
      selected.sort
    end

    def search(query)
      words = [query].flatten.join(' ').tokenize.sort.uniq - ['-']
      words.map do |word|
        regexp = Regexp.new(Regexp.quote(word), true)
        @items.values.select do |item|
          self.class.search_fields.find do |field|
            case (value = item.send(field))
            when Array
              value.find { |v| v.to_s =~ regexp }
            else
              value.to_s =~ regexp
            end
          end
        end
      end.flatten.compact.uniq
    end

    def json_file_for_id(id)
      @root / id / InfoFileName
    end

    def save_item(item)
      item.json_file = json_file_for_id(item.id)
      ;;warn "* saving item to #{item.json_file}"
      json = JSON.pretty_generate(item)
      item.json_file.dirname.mkpath unless item.json_file.dirname.exist?
      item.json_file.write(json)
      @items[item.id] ||= item
    end

    def save_hash(hash)
      raise Error, "Hash does not have ID" unless hash[:id]
      json_file = json_file_for_id(hash[:id])
      ;;warn "* saving item to #{json_file}"
      json = JSON.pretty_generate(hash)
      json_file.dirname.mkpath unless json_file.dirname.exist?
      json_file.write(json)
    end

    def has_item?(id)
      @items.has_key?(id)
    end

    def destroy!
      @items.values.each { |item| @items.delete(item.id) }
      @root.rmtree if @root.exist?
    end

    def destroy_item!(item)
      @items.delete(item.id)
      dir = json_file_for_id(item.id).dirname
      dir.rmtree if dir.exist?
    end

    class Item

      attr_accessor :json_file
      attr_accessor :id

      include SetParams

      def dir
        @json_file.dirname
      end

      def to_h
        {
          id: @id,
        }
      end

      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      def as_json(*options)
        to_h.compact
      end

      def fields(keys)
        keys.map { |k| send(k) }
      end

      def <=>(other)
        @id <=> other.id
      end

    end

  end

end