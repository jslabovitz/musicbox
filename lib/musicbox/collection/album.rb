class MusicBox

  module Collection

    class Album < Sequel::Model

      many_to_one :artist
      one_to_many :tracks

      dataset_module do

        def search(args)
          dataset = self
          args.each do |selector|
            dataset = case selector
            when /^[\d,]+$/
              dataset.where(release_id: selector.split(',').map(&:to_i))
            else
              raise Error, "Unknown selector: #{selector}"
            end
          end
          dataset
        end

        def with_covers
          where { !cover_file.nil? }
        end

        def without_covers
          where { cover_file.nil? }
        end

        def all_albums_released_in_year(year)
          where(year: year).
          all
        end

      end

      def summary
        '%-8s | %-4s | %-4s | %-60.50s | %-60.60s' % [
          release_id,
          artist.key,
          year || '-',
          artist_name,
          title,
        ]
      end

      def dir
        Collection.albums_dir / release_id.to_s
      end

      def file_path(*parts)
        dir.join(*parts)
      end

      def cover_path
        cover_file ? file_path(cover_file) : nil
      end

      def has_cover?
        !cover_file.nil?
      end

      def to_label
        {
          artist: artist_name,
          artist_key: artist.key,
          title: title,
          year: year,
          id: release_id,
        }
      end

      def self.csv_header
        %w[ID year artist title].to_csv
      end

      def to_csv
        [release_id, year, artist_name, title].to_csv
      end

    end

  end

end