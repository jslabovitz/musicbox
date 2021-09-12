class MusicBox

  class Collection

    class Track

      attr_accessor :title
      attr_accessor :artist_name
      attr_accessor :track_num
      attr_accessor :disc_num
      attr_accessor :file
      attr_accessor :album

      include SetParams

      alias_method :artist=, :artist_name=
      alias_method :track=, :track_num=
      alias_method :disc=, :disc_num=

      def to_h
        {
          title: @title,
          artist: (@artist_name != @album.artist_name) ? @artist_name : nil,
          track: @track_num,
          disc: @disc_num,
          file: @file.to_s,
        }.compact
      end

      def to_info
        [
          @disc_num ? ('%1d-%02d' % [@disc_num, @track_num]) : ('%2d' % @track_num),
          @title,
        ]
      end

      def path
        @album.dir / @file
      end

      def update_cover(cover_path)
        # --replace apparently doesn't work, so must do --remove, then --add
        begin
          run_command('mp4art',
            '--quiet',
            '--remove',
            path)
        rescue RunCommandFailed => e
          # ignore
        end
        run_command('mp4art',
          '--quiet',
          '--add',
          cover_path,
          path)
      end

      def update_tags
        tags = Tags.load(path)
        tags.update(
          {
            title: @title,
            album: @album.title,
            track: @track_num,
            disc: @disc_num,
            discs: @album.discs,
            artist: @artist_name || @album.artist_name,
            album_artist: @album.artist_name,
            grouping: @album.title,
            year: @album.year,
          }.reject { |k, v| v.to_s.empty? }
        )
        tags.save(path)
      end

    end

  end

end