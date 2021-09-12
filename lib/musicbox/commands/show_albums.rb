class MusicBox

  module Commands

    class ShowAlbums < SimpleCommand::Command

      option :cover, default: false
      option :details, default: false

      def run(args)
        if @cover
          mode = :cover
        elsif @details
          mode = :details
        else
          mode = :summary
        end
        $musicbox.show_albums(args, mode: mode)
      end

    end

  end

end