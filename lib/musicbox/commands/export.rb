class MusicBox

  module Commands

    class Export < SimpleCommand::Command

      option :dir
      option :compress, default: false
      option :force, default: false
      option :parallel, default: true

      def run(args)
        $musicbox.export(args,
          dest_dir: @dir,
          compress: @compress,
          force: @force,
          parallel: @parallel)
      end

    end

  end

end