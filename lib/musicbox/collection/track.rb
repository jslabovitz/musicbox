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
          artist: @artist_name,
          track: @track_num,
          disc: @disc_num,
          file: @file,
        }.compact
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
            @path)
        rescue RunCommandFailed => e
          # ignore
        end
        run_command('mp4art',
          '--quiet',
          '--add',
          cover_path,
          @path)
      end

      def load_tags
        @tags ||= Tags.load(path)
      end

      def save_tags
        @tags.save(path)
      end

      def update_tags
        load_tags
        @tags.update(
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
      end

    end

  end

end