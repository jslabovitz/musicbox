class MusicBox

  module Commands

    class ShowReleases < SimpleCommand::Command

      attr_accessor :details

      def run(args)
        $musicbox.find_releases(args).each do |release|
          if @details
            puts release.details
            puts
          else
            puts release
          end
        end
      end

    end

  end

end