class MusicBox

  module Commands

    class Import < SimpleCommand::Command

      def run(args)
        importer = $musicbox.make_importer
        if args.empty?
          return unless $musicbox.import_dir.exist?
          dirs = $musicbox.import_dir.children.select(&:dir?).sort_by { |d| d.to_s.downcase }
        else
          dirs = args.map { |p| Path.new(p) }
        end
        dirs.each do |dir|
          query = dir.basename.to_s
          puts "Finding: #{query.inspect}"
          releases = $musicbox.find_releases(query)
          release = TTY::Prompt.new.select('Item?', releases, filter: true, per_page: 25, quiet: true)
          release.print
          begin
            importer.import(source_dir: dir, release: release)
          rescue Error => e
            warn "Error: #{e}"
          end
        end
      end
    end

  end

end