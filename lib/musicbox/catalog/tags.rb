module MusicBox

  class Catalog

    class Tags

      TagFlags = {
        album: 'A',         # album title
        title: 's',         # track title
        artist: 'a',        # artist name
        album_artist: 'R',  # album artist name
        composer: 'w',      # composer
        grouping: 'G',      # grouping
        disc: 'd',          # disc number
        discs: 'D',         # total discs
        track: 't',         # track number
        tracks: 'T',        # total tracks
        year: 'y',          # release year
      }

      def self.load(file)
        new.tap { |t| t.load(file) }
      end

      def initialize(params={})
        @hash = {}
        @changes = {}
        params.each { |k, v| send("#{k}=", v) }
      end

      def [](key)
        @changes.has_key?(key) ? @changes[key] : @hash[key]
      end

      def []=(key, value)
        @changes[key] = value unless @hash[key] == value
      end

      def changed?
        !@changes.empty?
      end

      def changes
        @changes
      end

      def update(hash)
        hash.each { |k, v| self[k] = v }
      end

      def load(file)
        cmd = [
          'ffprobe',
          '-loglevel', 'error',
          '-show_entries', 'format',
          '-i', file,
        ].map(&:to_s)
        IO.popen(cmd, 'r') do |pipe|
          pipe.readlines.map(&:strip).each do |line|
            if line =~ /^TAG:(.*?)=(.*?)$/
              key, value = $1.to_sym, $2.strip
              info = case key
              when :date
                { year: value.to_i }
              when :track
                track, tracks = value.split('/').map(&:to_i)
                {
                  track: track,
                  tracks: tracks,
                }
              when :disc
                disc, discs = value.split('/').map(&:to_i)
                {
                  disc: disc,
                  discs: discs,
                }
              else
                { key => value }
              end
              @hash.update(info)
            end
          end
        end
        @hash[:track] ||= file.basename.to_s.to_i
      end

      def save(file)
        return unless changed?
        set_flags = {}
        remove_flags = []
        @changes.each do |key, value|
          flag = TagFlags[key] or raise
          if value
            set_flags[flag] = value
          else
            remove_flags << flag
          end
        end
        run_command('mp4tags',
          set_flags.map { |c, v| ["-#{c}", v] },
          !remove_flags.empty? ? ['-remove', remove_flags.join] : nil,
          file,
          verbose: false)
      end

    end

  end

end