require 'csv'
require 'base64'
require 'discogs-wrapper'
require 'http'
require 'io-dispatcher'
require 'json'
require 'mime-types'
require 'mpv_client'
require 'path'
require 'prawn'
require 'prawn/measurement_extensions'
require 'run-command'
require 'set'
require 'set_params'
require 'sixarm_ruby_unaccent'
require 'tty-prompt'
require 'yaml'

require 'extensions/path'
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
require 'musicbox/catalog/basic_information'
require 'musicbox/catalog/format'
require 'musicbox/catalog/image'
require 'musicbox/catalog/collection_item'
require 'musicbox/catalog/collection'
require 'musicbox/catalog/release'
require 'musicbox/catalog/releases'
require 'musicbox/catalog/tags'
require 'musicbox/catalog/track'

require 'musicbox/cover_maker'
require 'musicbox/discogs'
require 'musicbox/equalizer'
require 'musicbox/exporter'
require 'musicbox/importer'
require 'musicbox/label_maker'
require 'musicbox/player'

class MusicBox

  attr_accessor :catalog

  def initialize(root:)
    @catalog = Catalog.new(root: root)
    @prompt = TTY::Prompt.new
  end

  def export(args, **params)
    exporter = Exporter.new(catalog: @catalog, **params)
    @catalog.releases.find(args).each do |release|
      album = release.album or raise Error, "Album does not exist for release #{release.id}"
      exporter.export_album(album)
    end
  end

  def fix(args)
  end

  def diff_info(args)
    key_map = {
      :title => :title,
      :artist => :artist,
      :original_release_year => :year,
      :format_quantity => :discs,
    }
    @catalog.releases.find(args).select(&:has_album?).each do |release|
      diffs = {}
      key_map.each do |release_key, album_key|
        release_value = release.send(release_key)
        album_value = release.album.send(album_key)
        if album_value && release_value != album_value
          diffs[release_key] = [release_value, album_value]
        end
      end
      unless diffs.empty?
        puts release
        diffs.each do |key, values|
          puts "\t" + '%s: %p != %p' % [key, *values]
        end
        puts
        if @prompt.yes?('Update?')
          release.album.update_info
          release.album.update_tags
        end
      end
    end
  end

  def formats(args)
    formats = {}
    @catalog.releases.find(args).each do |release|
      release.formats.each do |format|
        formats[format.name] ||= 0
        formats[format.name] += 1
      end
    end
    formats.each do |name, count|
      puts '%5d %s' % [count, name]
    end
  end

  def extract_cover(args)
    @catalog.albums.find(args).each do |album|
      album.extract_cover
    end
  end

  def download_images(args)
    @catalog.releases.find(args).each do |release|
      release.download_images
    end
  end

  def cover(args, prompt: false, output_file: '/tmp/cover.pdf')
    releases = []
    @catalog.releases.find(args, prompt: prompt).select(&:has_album?).each do |release|
      release.select_cover unless release.album.has_cover?
      releases << release if release.album.has_cover?
    end
    CoverMaker.make_covers(*releases, output_file: output_file)
    run_command('open', output_file)
  end

  def select_cover(args, prompt: false, force: false)
    @catalog.releases.find(args, prompt: prompt).select(&:has_album?).each do |release|
      release.select_cover unless release.album.has_cover? && !force
    end
  end

  def import(args)
    @catalog.dirs_for_args(@catalog.import_dir, args).each do |dir|
      begin
        Importer.new(catalog: @catalog, source_dir: dir).import
      rescue Error => e
        warn "Error: #{e}"
      end
    end
  end

  def label(args)
    labels = @catalog.releases.find(args, prompt: true).map(&:to_label)
    output_file = '/tmp/labels.pdf'
    label_maker = LabelMaker.new
    label_maker.make_labels(labels)
    label_maker.write(output_file)
    run_command('open', output_file)
  end

  def dir(args)
    @catalog.albums.find(args).each do |album|
      puts "%-10s %s" % [album.id, album.dir]
    end
  end

  def open(args)
    @catalog.albums.find(args).each do |album|
      run_command('open', album.dir)
    end
  end

  def orphaned
    @catalog.orphaned.each do |group_name, items|
      unless items.empty?
        puts "#{group_name}:"
        items.sort.each do |item|
          puts item
        end
        puts
        if @prompt.yes?("Remove orphaned items from #{group_name}?")
          group = @catalog.send(group_name)
          items.each { |item| group.destroy_item!(item) }
        end
      end
    end
    images = @catalog.orphaned_images
    unless images.empty?
      puts "Images:"
      images.sort.each do |image|
        puts "\t" + image.to_s
      end
      puts
      if @prompt.yes?('Remove orphaned images?')
        images.each do |image|
          (@catalog.images_dir / images.file).unlink
        end
      end
    end
  end

  def show_albums(args, mode: :summary)
    @catalog.albums.find(args).each do |album|
      case mode
      when :cover
        album.show_cover if album.has_cover?
      when :details
        puts album.details_to_s
        puts
      when :summary
        puts album
      end
    end
  end

  def show_releases(args, mode: :summary)
    @catalog.releases.find(args).each do |release|
      case mode
      when :details
        puts release.details_to_s
        puts
      when :summary
        puts release
      end
    end
  end

  def csv(args)
    print Catalog::Release.csv_header
    @catalog.releases.find(args).each do |release|
      print release.to_csv
    end
  end

  def dups(args)
    dups = @catalog.find_dups(@catalog.releases.find(args))
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

  def play(args, prompt: false, equalizer_name: nil, **params)
    albums = @catalog.albums.find(args, prompt: prompt).compact
    if equalizer_name
      equalizers = Equalizer.load_equalizers(
        dir: Path.new(@catalog.config['equalizers_dir']),
        name: equalizer_name)
    else
      equalizers = nil
    end
    player = MusicBox::Player.new(
      albums: albums,
      equalizers: equalizers,
      **params)
    player.play
  end

  def select(args)
    ids = []
    loop do
      releases = @catalog.releases.find(args, prompt: true) or break
      ids += releases.map(&:id)
      puts ids.join(' ')
    end
  end

  def update
    Discogs.new(catalog: @catalog).update
  end

  def update_tags(args, force: false)
    @catalog.releases.find(args).select(&:has_album?).each do |release|
      puts release
      release.album.update_tags(force: force)
    end
  end

  def update_info(args, force: false)
    @catalog.albums.find(args).each do |album|
      puts album
      album.update_info
    end
  end

end