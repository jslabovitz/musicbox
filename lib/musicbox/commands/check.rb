class MusicBox

  module Commands

    class Check < SimpleCommand::Command

      def run(args)
        $musicbox.find_albums(args).each do |album|
          album.check
        end
      end

    end

  end

end