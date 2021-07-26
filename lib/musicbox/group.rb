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
      reset
      load
    end

    def items
      @items.values
    end

    def item_class
      self.class.item_class
    end

    def reset
      @items = {}
    end

    def load
      reset
      if @root.exist?
        @root.glob("*/#{InfoFileName}").each do |info_file|
          @items[item.id] = item_class.load(info_file)
        end
        ;;warn "* loaded #{@items.length} items from #{@root}"
      end
    end

    def [](id)
      @items[id]
    end

    def find(*selectors, prompt: false, multiple: true)
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
      end
      selected.uniq.sort!
      if prompt
        choices = selected.map { |i| [i.to_s, i.id] }.to_h
        if multiple
          ids = TTY::Prompt.new.multi_select('Item?', filter: true, per_page: 50, quiet: true) do |menu|
            choices.each do |name, value|
              menu.choice name, value
            end
          end
          selected = ids.map { |id| self[id] }
        else
          id = TTY::Prompt.new.select('Item?', choices, filter: true, per_page: 50, quiet: true)
          selected = [self[id]] if id
        end
      end
      selected
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

    def dir_for_id(id)
      @root / id
    end

    def save_item(item)
      item.json_file = dir_for_id(item.id) / InfoFileName
      item.save
      @items[item.id] = item unless @items[item.id]
      item
    end

    def save_hash(hash)
      raise Error, "Hash does not have ID" unless hash[:id]
      json_file = dir_for_id(hash[:id]) / InfoFileName
      ;;warn "* saving item to #{json_file}"
      json_file.dirname.mkpath unless json_file.dirname.exist?
      json_file.write(JSON.pretty_generate(hash))
    end

    def has_item?(id)
      @items.has_key?(id)
    end

    def destroy!
      @root.rmtree if @root.exist?
    end

    def destroy_item!(item)
      @items.delete(item.id)
      dir = dir_for_id(id)
      dir.rmtree if dir.exist?
    end

    class Item

      attr_accessor :json_file
      attr_accessor :id

      include SetParams

      def self.load(json_file)
        raise Error, "Info file does not exist: #{json_file}" unless json_file.exist?
        new(json_file: json_file, **JSON.load(json_file.read))
      end

      def dir
        @json_file.dirname
      end

      def save
        ;;warn "* saving item to #{@json_file}"
        @json_file.dirname.mkpath unless @json_file.dirname.exist?
        @json_file.write(JSON.pretty_generate(item))
      end

      def as_json(*)
        {
          id: @id,
        }
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