class MusicBox

  module Commands

    class Open < SimpleCommand::Command

      def run(args)
        @musicbox.find_albums(args).each do |album|
          run_command('open', album.dir)
        end
      end

    end

  end

end