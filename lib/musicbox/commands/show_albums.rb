class MusicBox

  module Commands

    class ShowAlbums < SimpleCommand::Command

      option :cover, default: false
      option :details, default: false

      def run(args)
        $musicbox.find_albums(args).each do |album|
          if @cover
            if album.has_cover?
              MusicBox.show_image(file: album.cover_file)
            else
              puts "[no cover file]"
            end
          elsif @details
            puts album.details
            puts
          else
            puts album.summary
          end
        end
      end

    end

  end

end