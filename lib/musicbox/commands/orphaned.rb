class MusicBox

  module Commands

    class Orphaned < Command

      def run(args)
        super
        @musicbox.orphaned
      end

    end

  end

end