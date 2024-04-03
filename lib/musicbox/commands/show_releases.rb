class MusicBox

  module Commands

    class ShowReleases < SimpleCommand::Command

      attr_accessor :details

      def run(args)
        importer = Importer.new(musicbox: @musicbox)
        importer.find_releases(args).each do |release|
          if @details
            release.print
            puts
          else
            puts release
          end
        end
      end

    end

  end

end