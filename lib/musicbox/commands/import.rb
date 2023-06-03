class MusicBox

  module Commands

    class Import < SimpleCommand::Command

      def run(args)
        importer = Importer.new(musicbox: musicbox)
        if args.empty?
          return unless @musicbox.import_dir.exist?
          dirs = @musicbox.import_dir.children.select(&:dir?).sort_by { |d| d.to_s.downcase }
        else
          dirs = args.map { |p| Path.new(p) }
        end
        dirs.each do |dir|
          begin
            importer.import_dir(dir)
          rescue Error => e
            warn "Error: #{e}"
          end
        end
      end
    end

  end

end