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
require 'tty-config'
require 'tty-prompt'
require 'yaml'

require 'extensions/path'
require 'extensions/string'

require 'musicbox/version'
require 'musicbox/error'
require 'musicbox/group'
require 'musicbox/info_to_s'

require 'musicbox/discogs'
require 'musicbox/discogs/artist'
require 'musicbox/discogs/basic_information'
require 'musicbox/discogs/format'
require 'musicbox/discogs/image'
require 'musicbox/discogs/collection_item'
require 'musicbox/discogs/collection'
require 'musicbox/discogs/release'
require 'musicbox/discogs/releases'
require 'musicbox/discogs/track'

require 'musicbox/cover_maker'
require 'musicbox/equalizer'
require 'musicbox/exporter'
require 'musicbox/importer'
require 'musicbox/label_maker'
require 'musicbox/player'
require 'musicbox/album'
require 'musicbox/track'
require 'musicbox/albums'
require 'musicbox/tags'

class MusicBox

  attr_accessor :discogs
  attr_accessor :albums

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

  def self.config
    unless @config
      @config = TTY::Config.new
      root_dir = Path.new(ENV['MUSICBOX_ROOT'] || '~/Music/MusicBox')
      @config.set(:root_dir, value: root_dir)
      @config.set(:import_dir, value: root_dir / 'import')
      @config.set(:import_done_dir, value: root_dir / 'import-done')
      @config.append_path(root_dir.to_s)
      @config.env_prefix = 'MUSICBOX'
      @config.autoload_env
      @config.read
    end
    @config
  end

  def initialize
    @root_dir = Path.new(config.fetch(:root_dir))
    @albums = Albums.new(root: @root_dir / 'albums')
    @prompt = TTY::Prompt.new
  end

  def inspect
    "<#{self.class}>"
  end

  def config
    self.class.config
  end

  def load_discogs
    @discogs ||= Discogs.new(
      root_dir: @root_dir / 'discogs',
      user: config.fetch(:discogs, :user),
      token: config.fetch(:discogs, :token),
      ignore_folder_id: config.fetch(:discogs, :ignore_folder_id),
    )
  end

  def export(args, **params)
    exporter = Exporter.new(params)
    @albums.find(args).each do |album|
      exporter.export_album(album)
    end
  end

  def fix(args)
  end

  def cover(args, prompt: false, output_file: '/tmp/cover.pdf')
    cover_files = []
    @albums.find(args, prompt: prompt).each do |album|
      unless album.has_cover?
        release = @discogs.releases[album.id] or raise Error, "No release for album ID #{album.id}"
        album.select_cover(release)
      end
      cover_files << album.cover_file if album.has_cover?
    end
    CoverMaker.make_covers(cover_files,
      output_file: output_file,
      open: true)
  end

  def select_cover(args, prompt: false, force: false)
    @albums.find(args, prompt: prompt).each do |album|
      unless album.has_cover? && !force
        release = @discogs.releases[album.id] or raise Error, "No release for album ID #{album.id}"
        album.select_cover(release)
      end
    end
  end

  def import(args)
    load_discogs
    if args.empty?
      import_dir = Path.new(config.fetch(:import_dir))
      return unless import_dir.exist?
      dirs = import_dir.children.select(&:dir?).sort_by { |d| d.to_s.downcase }
    else
      dirs = args.map { |p| Path.new(p) }
    end
    dirs.each do |dir|
      begin
        Importer.import(
          discogs: @discogs,
          albums: @albums,
          source_dir: dir,
          archive_dir: Path.new(config.fetch(:import_done_dir)))
      rescue Error => e
        warn "Error: #{e}"
      end
    end
  end

  def label(args, prompt: false, output_file: '/tmp/labels.pdf')
    labels = @albums.find(args, prompt: prompt).map(&:to_label)
    LabelMaker.make_labels(labels,
      output_file: output_file,
      open: true)
  end

  def dir(args)
    @albums.find(args).each do |album|
      puts "%-10s %s" % [album.id, album.dir]
    end
  end

  def open(args)
    @albums.find(args).each do |album|
      run_command('open', album.dir)
    end
  end

  def orphaned
    load_discogs
    @discogs.orphaned.each do |group_name, items|
      unless items.empty?
        puts "#{group_name}:"
        items.sort.each { |i| puts i }
        puts
        if @prompt.yes?("Remove orphaned items from #{group_name}?")
          group = @discogs.send(group_name)
          items.each { |item| group.destroy_item!(item) }
        end
      end
    end
    unless (orphaned = orphaned_albums).empty?
      puts 'Albums:'
      orphaned.sort.each { |a| puts a }
      puts
    end
    image_files = @discogs.orphaned_image_files
    unless image_files.empty?
      puts "Images:"
      image_files.sort.each do |file|
        puts "\t" + file.to_s
      end
      puts
      if @prompt.yes?('Remove orphaned images?')
        image_files.each do |file|
          (@discogs.images_dir / file).unlink
        end
      end
    end
  end

  def show_albums(args, mode: :summary)
    @albums.find(args).each do |album|
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
    load_discogs
    @discogs.releases.find(args).each do |release|
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
    print Album.csv_header
    @albums.find(args).each do |album|
      print album.to_csv
    end
  end

  def artist_keys
    load_discogs
    artists = (@discogs.releases.items + @discogs.masters.items).map(&:artists).flatten
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
    albums = @albums.find(args, prompt: prompt).compact
    if equalizer_name
      equalizers = Equalizer.load_equalizers(
        dir: Path.new(config.fetch(:equalizers_dir)),
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
      albums = @albums.find(args, prompt: true) or break
      ids += albums.map(&:id)
      puts ids.join(' ')
    end
  end

  def update
    load_discogs
    @discogs.update
  end

  def update_tags(args, force: false)
    @albums.find(args).each do |album|
      puts album
      album.update_tags(force: force)
    end
  end

  def update_info(args, force: false)
    @albums.find(args).each do |album|
      release = @discogs.releases[album.id] or raise Error, "No release for album ID #{album.id}"
      diffs = album.diff_info(release)
      unless diffs.empty?
        puts album
        diffs.each do |key, values|
          puts "\t" + '%s: %p != %p' % [key, *values]
        end
        puts
        if force || @prompt.yes?('Update?')
          album.update_info(release)
          album.update_tags
        end
      end
    end
  end

  def orphaned_albums
    @albums.items.reject { |a| @discogs.releases[a.id] }
  end

end