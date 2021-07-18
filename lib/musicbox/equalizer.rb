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
        key, value = line.split(/:\s+/, 1)
        case key
        when /^Preamp: ([-.\d]+) dB$/
          @volume_filter = VolumeFilter.new(volume: $1.to_f)
        when /^Filter \d+: ON PK Fc (\d+) Hz Gain ([-.\d]+) dB Q ([-.\d]+)$/
          @equalizer_filters << EqualizerFilter.new(
            frequency: $1.to_i,
            gain: $2.to_f,
            width: $3.to_f,
            type: 'q')
        else
          warn "Ignoring eq line: #{line.inspect}"
        end
      end
    end

    def <=>(other)
      @name <=> other.name
    end

    def to_s(enabled: true)
      [@volume_filter, enabled ? @equalizer_filters : nil].flatten.compact.join(',')
    end

    class VolumeFilter

      attr_accessor :volume

      include SetParams

      def to_s
        "volume=#{@volume}dB"
      end

    end

    class EqualizerFilter

      attr_accessor :frequency
      attr_accessor :gain
      attr_accessor :width
      attr_accessor :type

      include SetParams

      def to_s
        "equalizer=%s" % {
          f: @frequency,
          g: @gain,
          w: @width,
          t: @type,
        }.map { |kv| kv.join('=') }.join(':')
      end

    end

  end

end