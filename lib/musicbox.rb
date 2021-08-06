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

  def self.show_image(file:, width: nil, height: nil, preserve_aspect_ratio: nil)
    # see https://iterm2.com/documentation-images.html
    data = Base64.strict_encode64(file.read)
    args = {
      name: Base64.strict_encode64(file.to_s),
      size: data.length,
      width: width,
      height: height,
      preserveAspectRatio: preserve_aspect_ratio,
      inline: 1,
    }.compact
    puts "\033]1337;File=%s:%s\a" % [
      args.map { |a| a.join('=') }.join(';'),
      data,
    ]
  end

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
    image_files = @catalog.orphaned_image_files
    unless image_files.empty?
      puts "Images:"
      image_files.sort.each do |file|
        puts "\t" + file.to_s
      end
      puts
      if @prompt.yes?('Remove orphaned images?')
        image_files.each do |file|
          (@catalog.images_dir / file).unlink
        end
      end
    end
  end

  def show_albums(args, mode: :summary)
    @catalog.albums.find(args).each do |album|
      case mode
      when :cover
        MusicBox.show_image(file: album.cover_file) if album.has_cover?
      when :details
        puts album.details
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
        puts release.details
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

  def artist_keys
    artists = (@catalog.releases.items + @catalog.masters.items).map(&:artists).flatten
    # for some reason #uniq doesn't do the job
    artists = artists.map { |a| [a.id, a] }.to_h.values.sort
    keys = {}
    names = {}
    non_personal_names = Set.new
    artists.each do |artist|
      name, key = artist.name, artist.key
      non_personal_names << name if name == artist.canonical_name
      (keys[key] ||= Set.new) << name
      if names[name] && names[name] != key
        raise Error, "Name #{name.inspect} maps to different key #{key.inspect}"
      end
      names[name] = key
    end
    puts "Non-personal names:"
    non_personal_names.sort.each { |n| puts "\t" + n }
    puts "Keys:"
    keys.sort.each do |key, names|
      puts "\t" + key
      names.each { |n| puts "\t\t" + n }
    end
    puts "Artists:"
    artists.each do |artist|
      puts artist.summary
    end
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