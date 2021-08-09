class MusicBox

  class Album < Group::Item

    attr_accessor :title
    attr_accessor :artist
    attr_accessor :artist_key
    attr_accessor :year
    attr_accessor :discs
    attr_accessor :tracks

    def self.csv_header
      %w[ID year artist title].to_csv
    end

    def tracks=(tracks)
      @tracks = tracks.map { |h| Track.new(h.merge(album: self)) }
    end

    def cover_file
      files = dir.glob('cover.{jpg,png}')
      raise Error, "Multiple cover files: #{files.join(', ')}" if files.length > 1
      files.first
    end

    def has_cover?
      !cover_file.nil?
    end

    def to_s
      summary
    end

    def summary
      '%-8s | %1s | %-4s | %-4s | %-50.50s | %-60.60s | %-6s' % [
        @id,
        has_cover? ? 'C' : '',
        @artist_key,
        @year || '-',
        @artist,
        @title,
        @discs || '-',
      ]
    end

    def to_label
      {
        artist: @artist,
        artist_key: @artist_key,
        title: @title,
        year: @year,
        id: @id,
      }
    end

    def to_csv
      [@id, @year, @artist, @title].to_csv
    end

    def validate_logs
      log_files = dir.glob('*.log')
      raise Error, "No rip logs" if log_files.empty?
      state = :initial
      log_files.each do |log_file|
        log_file.readlines.map(&:chomp).each do |line|
          case state
          when :initial
            if line =~ /^AccurateRip Summary/
              state = :accuraterip_summary
            end
          when :accuraterip_summary
            if line =~ /^\s+Track \d+ : (\S+)/
              raise Error, "Not accurately ripped" unless $1 == 'OK'
            else
              break
            end
          end
        end
      end
    end

    InfoKeyMap = {
      :title => :title,
      :artist => :artist,
      :artist_key => :artist_key,
      :original_release_year => :year,
      :format_quantity => :discs,
    }

    def diff_info(release)
      diffs = {}
      InfoKeyMap.each do |release_key, album_key|
        release_value = release.send(release_key)
        album_value = send(album_key)
        if album_value && release_value != album_value
          diffs[release_key] = [release_value, album_value]
        end
      end
      diffs
    end

    def update_info(release)
      InfoKeyMap.each do |release_key, album_key|
        send("#{album_key}=", release.send(release_key))
      end
      save
    end

    def update_tags(force: false)
      changed_tracks = []
      @tracks.each do |track|
        track.update_tags
        changed_tracks << track if track.tags.changed?
      end
      unless changed_tracks.empty?
        puts
        puts "#{@title} [#{dir}]"
        changed_tracks.each do |track|
          puts "\t" + track.file.to_s
          track.tags.changes.each do |key, change|
            puts "\t\t%s: %p => %p" % [key, *change]
          end
        end
        if force || TTY::Prompt.new.yes?('Update track files?')
          changed_tracks.each do |track|
            track.save_tags
          end
        end
      end
      if has_cover?
        # --replace apparently doesn't work, so must do --remove, then --add
        @tracks.each do |track|
          begin
            run_command('mp4art',
              '--quiet',
              '--remove',
              track.path)
          rescue RunCommandFailed => e
            # ignore
          end
          run_command('mp4art',
            '--quiet',
            '--add',
            cover_path,
            track.path)
        end
      end
    end

    def to_h
      %i[title artist artist_key year discs].map { |k| [k, send(k) ] }.to_h.compact
    end

    def as_json(*options)
      super(*options).merge(
        title: @title,
        artist: @artist,
        artist_key: @artist_key,
        year: @year,
        discs: @discs,
        tracks: @tracks&.map(&:to_h)).compact
    end

  end

end