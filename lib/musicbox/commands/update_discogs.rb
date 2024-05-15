class MusicBox

  module Commands

    class UpdateDiscogs < Command

      def run(args)
        super
        importer = Importer.new(musicbox: @musicbox)
        importer.update_discogs
      end

    end

  end

end