class MusicBox

  module Commands

    class Check < Command

      def run(args)
        super
        @musicbox.find_albums(args).each do |album|
          album.check
        end
      end

    end

  end

end