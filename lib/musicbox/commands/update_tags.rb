class MusicBox

  module Commands

    class UpdateTags < SimpleCommand::Command

      def run(args)
        $musicbox.update_tags(args)
      end

    end

  end

end