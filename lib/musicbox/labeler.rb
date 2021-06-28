module MusicBox

  class Labeler

    class Error < Exception; end

    def initialize(catalog:)
      @catalog = catalog
      @font_dir = Path.new('~/Fonts/D/DejaVu Sans')
      @pdf = Prawn::Document.new(page_size: [3.5.in, 1.14.in], margin: 0)
    end

    def label(args)
      labels = @catalog.prompt_releases(args).map do |release|
        {
          artist: release.artist,
          title: release.title,
          key: release.artist_key,
          year: release.original_release_year,
          format: release.primary_format_name,
          id: release.id,
        }
      end.sort_by { |l| ;;pp l; l.values_at(:key, :year) }
  # ;;pp labels
      make_labels(labels)
    end

    private

    class Error < Exception; end

    def make_labels(labels)
      @pdf.font_families.update(font_families)
      @pdf.font('DejaVuSans')
      @pdf.font_size(12)
      labels.each_with_index do |label, i|
        @pdf.start_new_page if i > 0
        make_label(label)
      end
      @pdf.render_file('/tmp/labels.pdf')
    end

    def make_label(label)
      @pdf.bounding_box([0, 1.in], width: 2.5.in, height: 1.in) do
        # ;;@pdf.transparent(0.5) { @pdf.stroke_bounds }
        @pdf.text_box <<~END, inline_format: true
          <b>#{label[:artist]}</b>
          <i>#{label[:title]}</i>
        END
      end
      @pdf.bounding_box([2.7.in, 1.in], width: 0.8.in, height: 1.in) do
        # ;;@pdf.transparent(0.5) { @pdf.stroke_bounds }
        @pdf.text_box <<~END, align: :right, inline_format: true
          <b>#{label[:key]}
          #{label[:year]}</b>

          #{label[:format]}
          #{label[:id]}
        END
      end
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