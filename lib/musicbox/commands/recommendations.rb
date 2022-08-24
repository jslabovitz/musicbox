class MusicBox

  module Commands

    class Recommendations < SimpleCommand::Command

      def run(args)
        @listen_brainz = ListenBrainz.new
        @listen_brainz.recommendations.sort.each do |name, info|
          puts "%-30s | %-10s | %-20s | %4s | %s" % [
            name,
            info.type,
            info.area,
            info.begin_year,
            info.streaming_url,
          ]
        end
      end

    end

  end

end