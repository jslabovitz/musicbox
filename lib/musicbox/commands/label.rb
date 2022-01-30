class MusicBox

  module Commands

    class Label < SimpleCommand::Command

      attr_accessor :output_file

      def self.defaults
        {
          output_file: '/tmp/labels.pdf',
        }
      end

      def run(args)
        labels = $musicbox.find_albums(args).map(&:to_label)
        LabelMaker.make_labels(labels,
          output_file: @output_file,
          open: true)
      end

    end

  end

end