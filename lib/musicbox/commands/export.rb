class MusicBox

  module Commands

    class Export < SimpleCommand::Command

      attr_accessor :dest_dir
      attr_accessor :compress
      attr_accessor :force
      attr_accessor :parallel

      def self.defaults
        {
          parallel: true,
        }
      end

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