class MusicBox

  module Commands

    class UpdateTags < Command

      def run(args)
        super
        @musicbox.find_albums(args).each do |album|
          puts album
          album.update_tags
        end
      end

    end

  end

end