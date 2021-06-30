module MusicBox

  class Catalog

    def export(args, dir:, threaded: true)
      dir = Path.new(dir).expand_path
      dir.mkpath unless dir.exist?
      find_releases(args).each do |release|
        name = '%s - %s (%s)' % [release.artist, release.title, release.original_release_year]
        album = release.album or raise Error, "Album does not exist for release #{release.id} (#{name})"
        album.export(dir / name, threaded: threaded)
      end
    end

  end

end