class MusicBox

  module Commands

    class Label < SimpleCommand::Command

      option :output_file, default: '/tmp/labels.pdf'

      def run(args)
        labels = $musicbox.find_albums(args).map(&:to_label)
        LabelMaker.make_labels(labels,
          output_file: @output_file,
          open: true)
      end

    end

  end

end