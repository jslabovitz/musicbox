require 'csv'
require 'discogs-wrapper'
require 'http'
require 'io-dispatcher'
require 'json'
require 'mpv_client'
require 'path'
require 'prawn'
require 'prawn/measurement_extensions'
require 'run-command'
require 'set'
require 'sixarm_ruby_unaccent'
require 'tty-prompt'
require 'yaml'

require 'extensions/string'

require 'musicbox/version'
require 'musicbox/error'
require 'musicbox/group'
require 'musicbox/info_to_s'

require 'musicbox/catalog'
require 'musicbox/catalog/album'
require 'musicbox/catalog/album_track'
require 'musicbox/catalog/albums'
require 'musicbox/catalog/artist'
require 'musicbox/catalog/artists'
require 'musicbox/catalog/format'
require 'musicbox/catalog/collection_item'
require 'musicbox/catalog/collection'
require 'musicbox/catalog/release'
require 'musicbox/catalog/release_artist'
require 'musicbox/catalog/releases'
require 'musicbox/catalog/tags'
require 'musicbox/catalog/track'

require 'musicbox/discogs'
require 'musicbox/exporter'
require 'musicbox/extractor'
require 'musicbox/importer'
require 'musicbox/labeler'
require 'musicbox/player'

class MusicBox

  attr_accessor :catalog

  def initialize(root:)
    @catalog = Catalog.new(root: root)
  end

  def export(args, **params)
    exporter = Exporter.new(catalog: @catalog, **params)
    @catalog.find(args, group: :releases).each do |release|
      album = release.album or raise Error, "Album does not exist for release #{release.id}"
      exporter.export_album(album)
    end
  end

  def extract(args)
    extractor = Extractor.new(catalog: @catalog)
    @catalog.dirs_for_args(@catalog.extract_dir, args).each do |dir|
      extractor.extract_dir(dir)
    end
  end

  def fix(args)
    # key_map = {
    #   :title => :title,
    #   :artist => :artist,
    #   :original_release_year => :year,
    #   :format_quantity => :discs,
    # }
    # find(args, group: :releases).select(&:cd?).each do |release|
    #   diffs = {}
    #   key_map.each do |release_key, album_key|
    #     release_value = release.send(release_key)
    #     album_value = release.album.send(album_key)
    #     if album_value && release_value != album_value
    #       diffs[release_key] = [release_value, album_value]
    #     end
    #   end
    #   unless diffs.empty?
    #     puts release
    #     diffs.each do |key, values|
    #       puts "\t" + '%s: %p => %p' % [key, *values]
    #     end
    #     puts
    #   end
    # end
  end

  def extract_cover(args)
    @catalog.find(args, group: :releases).select(&:album).each do |release|
      release.album.extract_cover
    end
  end

  def get_cover(args)
    @catalog.find(args, group: :releases).select(&:cd?).each do |release|
      puts release
      [release, release.master].compact.each do |r|
        r.get_images
        run_command('open', r.dir)
      end
      run_command('open', release.album.dir)
    end
  end

  def cover(args, output_file: '/tmp/cover.pdf')
    albums = @catalog.find(args, group: :releases).map(&:album).compact.select(&:has_cover?)
    size = 4.75.in
    top = 10.in
    Prawn::Document.generate(output_file) do |pdf|
      albums.each do |album|
        puts album
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
    end
    run_command('open', output_file)
  end

  def import(args)
    importer = Importer.new(catalog: @catalog)
    @catalog.dirs_for_args(@catalog.import_dir, args).each do |dir|
      begin
        importer.import_dir(dir)
      rescue Error => e
        warn "Error: #{e}"
      end
    end
  end

  def label(args)
    labeler = Labeler.new
    @catalog.prompt_releases(args).each { |r| labeler << r.to_label }
    labeler.make_labels('/tmp/labels.pdf', open: true)
  end

  def dir(args, group: nil)
    @catalog.find(args, group: group).each do |release|
      puts "%-10s %s" % [release.id, release.dir]
    end
  end

  def open(args, group: nil)
    @catalog.find(args, group: group).each do |release|
      run_command('open', release.dir)
    end
  end

  def orphaned
    @catalog.orphaned.each do |group, items|
      unless items.empty?
        puts "#{group}:"
        items.sort.each do |item|
          puts item
        end
        puts
      end
    end
  end

  def show(args, group: nil, show_details: false)
    @catalog.find(args, group: group).each do |release|
      if show_details
        puts release.details_to_s
        puts
      else
        puts release
      end
    end
  end

  def csv(args)
    print Catalog::Release.csv_header
    @catalog.find(args, group: :releases).each do |release|
      print release.to_csv
    end
  end

  def dups(args)
    dups = @catalog.find_dups(@catalog.find(args, group: :releases))
    dups.each do |id, formats|
      formats.each do |format, releases|
        if releases.length > 1
          puts
          releases.each { |r| puts r }
        end
      end
    end
  end

  def artist_keys(args)
    if args.empty?
      args = @catalog.releases.items.map { |r| r.artists.map(&:name) }.flatten
    end
    ;;pp @catalog.artist_keys(args)
  end

  def play(args, **params)
    releases = args.empty? ? @catalog.releases.items.select(&:album) : @catalog.prompt_releases(args)
    albums = releases.map(&:album).compact
    player = MusicBox::Player.new(albums: albums, **params)
    player.play
  end

  def select(args)
    ids = []
    loop do
      releases = @catalog.prompt_releases(args) or break
      ids += releases.map(&:id)
      puts ids.join(' ')
    end
  end

  def update
    Discogs.new(catalog: @catalog).update
  end

  def update_tags(args, force: false)
    @catalog.find(args, group: :releases).each do |release|
      album = release.album or raise
      album.update_tags(force: force)
    end
  end

end