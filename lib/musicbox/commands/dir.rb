class MusicBox

  module Commands

    class Dir < Command

      def run(args)
        super
        @musicbox.find_albums(args).each do |album|
          puts "%-10s %s" % [album.id, album.dir]
        end
      end

    end

  end

end