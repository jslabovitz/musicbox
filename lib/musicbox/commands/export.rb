class MusicBox

  module Commands

    class Export < SimpleCommand::Command

      option :dest_dir
      option :compress, default: false
      option :force, default: false
      option :parallel, default: true

      def run(args)
        raise Error, "Must specify destination directory" unless @dest_dir
        @dest_dir = Path.new(@dest_dir).expand_path
        $musicbox.find_albums(args).each do |album|
          album.export(
            dest_dir: @dest_dir / album.description,
            compress: @compress,
            force: @force,
            parallel: @parallel)
        end
      end

    end

  end

end