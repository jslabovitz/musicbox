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
          add_item(item_class.load(info_file.dirname))
        end
        ;;warn "* loaded #{@items.length} items from #{@root}"
      end
    end

    def [](id)
      @items[id]
    end

    def <<(item)
      add_item(item)
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
        found += @items.values.select do |item|
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

    def new_item(id, args={})
      item = item_class.new(
        {
          id: id,
          dir: dir_for_id(id),
        }.merge(args)
      )
      add_item(item)
      item
    end

    def add_item(item)
      raise Error, "Item does not have ID" if item.id.nil?
      raise Error, "Item already exists in #{@root}: #{item.id.inspect}" if @items[item.id]
      @items[item.id] = item
    end

    def has_item?(id)
      @items.has_key?(id)
    end

    def delete_item(item)
      @items.delete(item.id)
    end

    def save_item(id:, item: nil, &block)
      raise Error, "ID is nil" unless id
      item = yield if block_given?
      raise Error, "Item is nil" unless item
      dir = dir_for_id(id)
      info_file = dir / InfoFileName
      dir.mkpath unless dir.exist?
;;warn "writing to #{info_file}"
      info_file.write(JSON.pretty_generate(item))
    end

    def save_item_if_new(id:, item: nil, &block)
      unless has_item?(id)
        save_item(id: id, item: item, &block)
      end
    end

    def destroy_item(item)
      dir = dir_for_id(id)
      dir.rmtree if dir.exist?
      delete_item(item)
    end

    def destroy!
      @root.rmtree if @root.exist?
    end

    class Item

      attr_accessor :id
      attr_accessor :dir

      include SetParams

      def self.load(dir, params={})
        dir = Path.new(dir)
        info_file = dir / Group::InfoFileName
        raise Error, "Info file does not exist: #{info_file}" unless info_file.exist?
        new(JSON.load(info_file.read).merge(dir: dir).merge(params))
      end

      def info_file
        @dir / Group::InfoFileName
      end

      def save
        ;;warn "* saving item to #{@dir}"
        raise Error, "dir not defined" unless @dir
        @dir.mkpath unless @dir.exist?
        info_file.write(JSON.pretty_generate(serialize))
      end

      def serialize(args={})
        { id: @id }.merge(args).compact
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