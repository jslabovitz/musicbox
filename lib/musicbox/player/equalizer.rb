class MusicBox

  # https://ffmpeg.org/ffmpeg-filters.html
  # https://github.com/jaakkopasanen/AutoEq
  
  class Equalizer

    attr_accessor :name
    attr_accessor :volume_filter
    attr_accessor :equalizer_filters

    include SetParams

    def self.load_equalizers(dir:, name:)
      dir.glob("**/*#{name}*/*ParametricEQ.txt").map do |file|
        name = '%s (%s)' % [file.dirname.basename, file.dirname.dirname.basename]
        new(name: name).tap { |e| e.load(file) }
      end.sort
    end

    def initialize(params={})
      @equalizer_filters = []
      set(params)
    end

    def load(file)
      file.readlines.map { |l| l.sub(/#.*/, '') }.map(&:strip).reject(&:empty?).each do |line|
        key, _ = line.split(/:\s+/, 1)
        case key
        when /^Preamp: ([-.\d]+) dB$/
          @volume_filter = VolumeFilter.new($1.to_f)
        when /^Filter \d+: ON PK Fc (\d+) Hz Gain ([-.\d]+) dB Q ([-.\d]+)$/
          @equalizer_filters << ParametricEqualizerFilter.new($1.to_i, $2.to_f, $3.to_f, 'q')
        else
          warn "Ignoring eq line: #{line.inspect}"
        end
      end
    end

    def <=>(other)
      @name <=> other.name
    end

    def to_af(enabled)
      [@volume_filter, enabled ? @equalizer_filters : nil].flatten.compact.map(&:to_af).join(',')
    end

    class VolumeFilter < Struct.new(:volume)

      def to_af
        "volume=#{volume}dB"
      end

    end

    class ParametricEqualizerFilter < Struct.new(:f, :g, :w, :t)

      def to_af
        "equalizer=%s" % %w[f g w t].map { |k| '%s=%s' % [k, send(k)] }.join(':')
      end

    end

  end

end