class MusicBox

  class Printer

    class CoverMaker

      def self.make_covers(*cover_files, output_file:, open: false)
        cover_maker = new
        cover_maker.make_covers(cover_files)
        cover_maker.write(output_file)
        run_command('open', output_file) if open
      end

      def initialize
        @pdf = Prawn::Document.new
      end

      def make_covers(*cover_files)
        size = 4.75.in
        top = 10.in
        cover_files.flatten.each_with_index do |cover_file, i|
          raise Error, "Cover file #{cover_file.to_s.inspect} does not exist" unless cover_file.exist?
          @pdf.start_new_page if i > 0
          @pdf.fill do
            @pdf.rectangle [0, top],
              size,
              size
          end
          @pdf.image cover_file.to_s,
            at: [0, top],
            width: size,
            fit: [size, size],
            position: :center
          @pdf.stroke do
            @pdf.rectangle [0, top],
              size,
              size
          end
        end
      end

      def make_album_cover(album:)
        make_covers(album.cover_file,
          output_file: '/tmp/covers.pdf',
          open: true)
      end

      def write(output_file)
        @pdf.render_file(output_file.to_s)
      end

    end

  end

end