class MusicBox

  class LabelMaker

    def self.make_label(album, **params)
      make_labels([album], **params)
    end

    def self.make_labels(albums, output_file:, open: false)
      label_maker = new
      label_maker.make_labels(albums)
      label_maker.write(output_file)
      run_command('open', output_file) if open
    end

    def initialize
      @font_dir = Path.new('~/Fonts/D/DejaVu Sans')
      @pdf = Prawn::Document.new(page_size: [3.5.in, 1.14.in], margin: 0)
      @pdf.font_families.update(font_families)
      @pdf.font('DejaVuSans')
      @pdf.font_size(12)
    end

    def make_labels(albums)
      albums.sort.each_with_index do |album, i|
        @pdf.start_new_page if i > 0
        album.make_label(@pdf)
      end
    end

    def write(output_file)
      @pdf.render_file(output_file.to_s)
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