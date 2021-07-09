class MusicBox

  class CoverMaker

    attr_accessor :output_file

    def self.make_cover(release, output_file:, open: false)
      cover_maker = new(output_file: output_file)
      cover_maker << release
      cover_maker.make_covers
      cover_maker.open if open
    end

    def initialize(output_file:)
      @output_file = Path.new(output_file)
      @releases = []
    end

    def <<(release)
      @releases << release
    end

    def make_covers
      size = 4.75.in
      top = 10.in
      pdf = Prawn::Document.new
      @releases.each do |release|
        album = release.album
        unless album&.has_cover?
          puts "Release #{release.id} has no cover"
          next
        end
        pdf.fill do
          pdf.rectangle [0, top],
            size,
            size
        end
        pdf.image album.cover_file.to_s,
          at: [0, top],
          width: size,
          fit: [size, size],
          position: :center
        pdf.stroke do
          pdf.rectangle [0, top],
            size,
            size
        end
      end
      pdf.render_file(@output_file.to_s)
    end

    def open
      run_command('open', @output_file)
    end

  end

end