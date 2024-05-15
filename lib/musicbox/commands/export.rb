class MusicBox

  module Commands

    class Export < Command

      attr_accessor :dest_dir
      attr_accessor :compress
      attr_accessor :force
      attr_accessor :parallel

      def self.defaults
        {
          compress: true,
          force: false,
          parallel: true,
        }
      end

      def run(args)
        super
        raise Error, "Must specify destination directory" unless @dest_dir
        exporter = Exporter.new(
          dest_dir: @dest_dir,
          compress: @compress,
          force: @force,
          parallel: @parallel)
        exporter.export
      end

    end

  end

end