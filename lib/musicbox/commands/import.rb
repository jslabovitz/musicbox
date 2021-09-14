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
          releases = $musicbox.find_releases(dir.basename.to_s)
          release = TTY::Prompt.new.select('Item?', releases, filter: true, per_page: 50, quiet: true)
          print release.details
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