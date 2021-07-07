module MusicBox

  class Labeler

    def self.make_label(label, output_file:, open: false)
      labeler = new
      labeler << label
      labeler.make_labels(output_file, open: open)
    end

    def initialize
      @font_dir = Path.new('~/Fonts/D/DejaVu Sans')
      @labels = []
    end

    def <<(label)
      @labels << label
    end

    def make_labels(output_file, open: false)
      pdf = Prawn::Document.new(page_size: [3.5.in, 1.14.in], margin: 0)
      pdf.font_families.update(font_families)
      pdf.font('DejaVuSans')
      pdf.font_size(12)
      @labels.sort_by { |l| l.values_at(:key, :year) }.each_with_index do |label, i|
        pdf.start_new_page if i > 0
        pdf.bounding_box([0, 1.in], width: 2.5.in, height: 1.in) do
          # ;;pdf.transparent(0.5) { pdf.stroke_bounds }
          pdf.text_box <<~END, inline_format: true
            <b>#{label[:artist]}</b>
            <i>#{label[:title]}</i>
          END
        end
        pdf.bounding_box([2.7.in, 1.in], width: 0.8.in, height: 1.in) do
          # ;;pdf.transparent(0.5) { pdf.stroke_bounds }
          pdf.text_box <<~END, align: :right, inline_format: true
            <b>#{label[:key]}
            #{label[:year]}</b>

            #{label[:format]}
            #{label[:id]}
          END
        end
      end
      pdf.render_file(output_file.to_s)
      run_command('open', output_file) if open
    end

    def font_families
      {
        'DejaVuSans' => {
          normal: 'DejaVuSans',
          italic: 'DejaVuSans-Oblique',
          bold: 'DejaVuSans-Bold',
          bold_italic: 'DejaVuSans-BoldOblique',
        }.map { |style, file|
          [style, (@font_dir / file).add_extension('.ttf').realpath.to_s ]
        }.to_h
      }
    end

  end

end