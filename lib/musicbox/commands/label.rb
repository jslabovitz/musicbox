class MusicBox

  module Commands

    class Label < Command

      attr_accessor :output_file

      def self.defaults
        {
          output_file: '/tmp/labels.pdf',
        }
      end

      def run(args)
        super
        LabelMaker.make_labels(@musicbox.find_albums(args),
          output_file: @output_file,
          open: true)
      end

    end

  end

end