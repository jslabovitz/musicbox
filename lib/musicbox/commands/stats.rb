class MusicBox

  module Commands

    class Stats < Command

      attr_accessor :details

      def run(args)
        super
        by_year = {}
        @musicbox.find_albums(args).each do |album|
          unless album.year
            warn "No year: #{album.summary}"
            next
          end
          by_year[album.year] ||= []
          by_year[album.year] << album
        end
        by_year.sort.each do |year, albums|
          if @details
            puts; puts "*** #{year}:"; puts
            albums.each { |a| puts a.summary }
          else
            puts [year, albums.count].join("\t")
          end
        end
      end

    end

  end

end