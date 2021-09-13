class MusicBox

  module Commands

    class Cover < SimpleCommand::Command

      option :output_file, default: '/tmp/cover.pdf'

      def run(args)
        albums = $musicbox.find_albums(args).select(&:has_cover?)
        raise Error, "No matching albums" if albums.empty?
        CoverMaker.make_covers(albums.map(&:cover_file),
          output_file: output_file,
          open: true)
      end

    end

  end

end