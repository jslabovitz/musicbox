class MusicBox

  module Commands

    class UpdateTags < SimpleCommand::Command

      def run(args)
        @musicbox.find_albums(args).each do |album|
          puts album
          album.update_tags
        end
      end

    end

  end

end