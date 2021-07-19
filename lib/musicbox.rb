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
    @catalog.find(args, group: :releases).each do |release|
      album = release.album or raise Error, "Album does not exist for release #{release.id}"
      exporter.export_album(album)
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

  def formats(args)
    formats = {}
    @catalog.find(args, group: :releases).each do |release|
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
    @catalog.find(args, group: :releases).select(&:has_album?).each do |release|
      release.album.extract_cover
    end
  end

  def download_images(args)
    @catalog.find(args, group: :releases).select(&:cd?).each do |release|
      release.download_images
    end
  end

  def cover(args, prompt: false, output_file: '/tmp/cover.pdf')
    releases = []
    @catalog.find(args, group: :releases, prompt: prompt).select(&:has_album?).each do |release|
      release.select_cover unless release.album.has_cover?
      releases << release if release.album.has_cover?
    end
    CoverMaker.make_covers(*releases, output_file: output_file)
    run_command('open', output_file)
  end

  def select_cover(args, prompt: false, force: false)
    @catalog.find(args, group: :releases, prompt: prompt).select(&:has_album?).each do |release|
      release.select_cover unless release.album.has_cover? && !force
    end
  end

  def import(args)
    @catalog.dirs_for_args(@catalog.import_dir, args).each do |dir|
      begin
        Importer.new(catalog: @catalog).import_dir(dir)
      rescue Error => e
        warn "Error: #{e}"
      end
    end
  end

  def label(args)
    labels = @catalog.find(args, group: :releases, prompt: true).map(&:to_label)
    output_file = '/tmp/labels.pdf'
    label_maker = LabelMaker.new
    label_maker.make_labels(labels)
    label_maker.write(output_file)
    run_command('open', output_file)
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
    images = @catalog.orphaned_images
    unless images.empty?
      puts "Images:"
      images.sort.each do |image|
        puts "\t" + image.to_s
      end
      puts
    end
  end

  def show(args, group: nil, mode: :summary, prompt: false)
    @catalog.find(args, group: group, prompt: prompt).each do |release|
      case mode
      when :cover
        release.album.show_cover if release.album&.has_cover?
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

  def play(args, prompt: false, equalizer_name: nil, **params)
    albums = @catalog.find(args, prompt: prompt).map(&:has_album?).compact
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
      releases = @catalog.find(args, group: :releases, prompt: true) or break
      ids += releases.map(&:id)
      puts ids.join(' ')
    end
  end

  def update
    Discogs.new(catalog: @catalog).update
  end

  def update_tags(args, force: false)
    @catalog.find(args, group: :releases).select(&:has_album?).each do |release|
      puts release
      release.album.update_tags(force: force)
    end
  end

end