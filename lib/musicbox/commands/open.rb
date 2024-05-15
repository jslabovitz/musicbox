class MusicBox

  module Commands

    class Open < Command

      def run(args)
        super
        @musicbox.find_albums(args).each do |album|
          run_command('open', album.dir)
        end
      end

    end

  end

end