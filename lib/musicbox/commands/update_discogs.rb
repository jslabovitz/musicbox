class MusicBox

  module Commands

    class UpdateDiscogs < SimpleCommand::Command

      def run(args)
        importer = Importer.new(musicbox: @musicbox)
        importer.update_discogs
      end

    end

  end

end