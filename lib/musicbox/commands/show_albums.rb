class MusicBox

  module Commands

    class ShowAlbums < SimpleCommand::Command

      attr_accessor :cover
      attr_accessor :details

      def run(args)
        @musicbox.find_albums(args).sort.each do |album|
          if @cover
            if album.has_cover?
              print ITerm.show_image_file(album.cover_file)
            else
              puts "[no cover file]"
            end
          elsif @details
            album.print
            puts
          else
            puts album.summary
          end
        end
      end

    end

  end

end