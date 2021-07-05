module MusicBox

  class Group

    attr_accessor :root
    attr_accessor :mode

    InfoFileName = 'info.json'

    def self.item_class
      Item
    end

    def initialize(root:, mode: nil)
      @root = Path.new(root).expand_path
      @mode = mode || :dir
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
        paths = case @mode
        when :dir
          @root.glob("*/#{InfoFileName}")
        when :file
          @root.glob('*.json')
        end
        paths.each do |path|
          # ;;warn "** loading: #{path}"
          add_item(item_class.load(path))
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

    def search(query:, fields:, limit: nil)
      found = []
      words = query.tokenize.sort.uniq - ['-']
      words.each do |word|
        regexp = Regexp.new(Regexp.quote(word), true)
        found += @items.values.select do |item|
          fields.find do |field|
            case (value = item.send(field))
            when Array
              value.find { |v| v.to_s =~ regexp }
            else
              value.to_s =~ regexp
            end
          end
        end
      end
      found = found.flatten.compact.uniq
      found = found[0..limit - 1] if limit
      found
    end

    def path_for_id(id)
      path = @root / id
      case @mode
      when :dir
        path / InfoFileName
      when :file
        path.add_extension('.json')
      end
    end

    def new_item(id, args={})
      item = item_class.new(
        {
          id: id,
          path: path_for_id(id),
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
      path = path_for_id(id)
      path.dirname.mkpath unless path.dirname.exist?
;;warn "writing to #{path}"
      path.write(JSON.pretty_generate(item))
    end

    def save_item_if_new(id:, item: nil, &block)
      unless has_item?(id)
        save_item(id: id, item: item, &block)
      end
    end

    def destroy_item(item)
      path = path_for_id(id)
      if path.exist?
        case @mode
        when :dir
          path.rmtree
        when :file
          path.unlink
        end
      end
      delete_item(item)
    end

    def destroy!
      @root.rmtree if @root.exist?
    end

    class Item

      attr_accessor :id
      attr_accessor :path

      def self.load(path, params={})
        path = Path.new(path)
        raise Error, "Path does not exist: #{path}" unless path.exist?
        new(JSON.load(path.read).merge(path: path).merge(params))
      end

      def initialize(params={})
        params.each { |k, v| send("#{k}=", v) }
      end

      def path=(path)
        @path = Path.new(path)
      end

      def save
        ;;warn "* saving item to #{@path}"
        @path.dirname.mkpath unless @path.dirname.exist?
        @path.write(JSON.pretty_generate(serialize))
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