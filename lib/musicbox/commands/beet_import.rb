class MusicBox

  module Commands

    class BeetImport < SimpleCommand::Command

      def run(args)
        $musicbox.find_albums(args).each do |album|
;;system('clear'); puts
          puts album.summary
          Beets.import(album.dir, incremental: nil)
        end
      end

    end

  end

end