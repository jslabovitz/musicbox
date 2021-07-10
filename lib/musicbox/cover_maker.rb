class MusicBox

  class CoverMaker

    def self.make_covers(*releases, output_file:)
      cover_maker = new
      cover_maker.make_covers(releases)
      cover_maker.write(output_file)
    end

    def initialize
      @pdf = Prawn::Document.new
    end

    def make_covers(releases)
      size = 4.75.in
      top = 10.in
      releases.each do |release|
        album = release.album
        unless album&.has_cover?
          puts "Release #{release.id} has no cover"
          next
        end
        @pdf.fill do
          @pdf.rectangle [0, top],
            size,
            size
        end
        @pdf.image album.cover_file.to_s,
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

    def write(output_file)
      @pdf.render_file(output_file.to_s)
    end

  end

end