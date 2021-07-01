module MusicBox

  class Extractor

    def initialize(catalog:)
      @catalog = catalog
    end

    def extract_dir(source_dir)
      puts "Extracting #{source_dir}"
      files = @catalog.categorize_files(source_dir)
      cue_file = files[:cue]&.shift or raise Error, "No cue file found"
      bin_file = files[:audio]&.shift or raise Error, "No bin file found"
      dest_dir = @catalog.import_dir / source_dir.basename
      raise Error, "Extraction directory already exists: #{dest_dir}" if dest_dir.exist?
      dest_dir.mkpath
      xld_extract(cue_file: cue_file, bin_file: bin_file, dest_dir: dest_dir)
      files.values.flatten.each { |p| p.cp_r(dest_dir) }
      @catalog.extract_done_dir.mkpath unless @catalog.extract_done_dir.exist?
      source_dir.rename(@catalog.extract_done_dir / source_dir.basename)
    end

    def xld_extract(cue_file:, bin_file:, dest_dir:)
      dest_dir.chdir do
        run_command('xld',
          '-c', cue_file,
          '-f', 'alac',
          '--filename-format', '%D-%n - %t',
          bin_file)
      end
    end

  end

end