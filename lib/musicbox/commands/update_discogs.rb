class MusicBox

  module Commands

    class UpdateDiscogs < SimpleCommand::Command

      def run(args)
        @musicbox.update_discogs
      end

    end

  end

end