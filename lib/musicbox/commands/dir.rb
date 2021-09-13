class MusicBox

  module Commands

    class Dir < SimpleCommand::Command

      def run(args)
        $musicbox.find_albums(args).each do |album|
          puts "%-10s %s" % [album.id, album.dir]
        end
      end

    end

  end

end