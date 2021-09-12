class MusicBox

  module Commands

    class ShowReleases < SimpleCommand::Command

      option :details, default: false

      def run(args)
        if @details
          mode = :details
        else
          mode = :summary
        end
        $musicbox.show_releases(args, mode: mode)
      end

    end

  end

end