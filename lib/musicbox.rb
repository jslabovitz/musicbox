require 'csv'
require 'base64'
require 'discogs-wrapper'
require 'faraday'
require 'http'
require 'io-dispatcher'
require 'json'
require 'logger'
require 'mime-types'
require 'mpv_client'
require 'path'
require 'prawn'
require 'prawn/measurement_extensions'
require 'run-command'
require 'set'
require 'set_params'
require 'simple-command'
require 'simple-group'
require 'simple-printer'
require 'sixarm_ruby_unaccent'
require 'tty-config'
require 'tty-prompt'
require 'yaml'

require 'extensions/path'
require 'extensions/string'

require 'musicbox/version'
require 'musicbox/error'

require 'musicbox/collection'
require 'musicbox/collection/album'
require 'musicbox/collection/albums'
require 'musicbox/collection/artist'
require 'musicbox/collection/artists'
require 'musicbox/collection/track'

require 'musicbox/commands/check'
require 'musicbox/commands/cover'
require 'musicbox/commands/csv'
require 'musicbox/commands/dir'
require 'musicbox/commands/export'
require 'musicbox/commands/fix'
require 'musicbox/commands/import'
require 'musicbox/commands/label'
require 'musicbox/commands/open'
require 'musicbox/commands/orphaned'
require 'musicbox/commands/play'
require 'musicbox/commands/save_albums'
require 'musicbox/commands/show_albums'
require 'musicbox/commands/show_artists'
require 'musicbox/commands/show_releases'
require 'musicbox/commands/update'
require 'musicbox/commands/update_tags'

require 'musicbox/discogs'
require 'musicbox/discogs/artist'
require 'musicbox/discogs/artist_list'
require 'musicbox/discogs/basic_information'
require 'musicbox/discogs/format'
require 'musicbox/discogs/image'
require 'musicbox/discogs/collection_item'
require 'musicbox/discogs/collection'
require 'musicbox/discogs/release'
require 'musicbox/discogs/releases'
require 'musicbox/discogs/track'
require 'musicbox/discogs/track_list'

require 'musicbox/cover_maker'
require 'musicbox/equalizer'
require 'musicbox/importer'
require 'musicbox/label_maker'
require 'musicbox/listens'
require 'musicbox/listen'
require 'musicbox/player'
require 'musicbox/playlist'
require 'musicbox/playlists'
require 'musicbox/tags'

class MusicBox

  attr_accessor :discogs
  attr_accessor :collection
  attr_accessor :playlists
  attr_accessor :listens
  attr_accessor :import_dir
  attr_accessor :import_done_dir
  attr_accessor :collection_dir
  attr_accessor :discogs_dir
  attr_accessor :refs_dir
  attr_accessor :equalizers_dir
  attr_accessor :playlists_dir

  def self.show_image(file:, width: nil, height: nil, preserve_aspect_ratio: nil)
    file = Path.new(file)
    raise Error, "Cover image file #{file.to_s.inspect} doesn't exist" unless file.exist?
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
      root_dir = ENV['MUSICBOX_ROOT'] || '~/Music/MusicBox'
      @config.append_path(root_dir)
      @config.set(:root_dir, value: Path.new(root_dir).expand_path)
      @config.env_prefix = 'MUSICBOX'
      @config.autoload_env
      @config.read
    end
    @config
  end

  def initialize
    @root_dir = config.fetch(:root_dir)
    @import_dir = @root_dir / 'import'
    @import_done_dir = @root_dir / 'import-done'
    @collection_dir = @root_dir / 'collection'
    @discogs_dir = @root_dir / 'discogs'
    @refs_dir = @root_dir / 'refs'
    @playlists_dir = @root_dir / 'playlists'
    @listens_dir = @root_dir / 'listens'
    @collection = Collection.new(root_dir: @collection_dir, refs_dir: @refs_dir)
    @playlists = Playlists.new(root: @playlists_dir)
    @listens = Listens.new(root: @listens_dir)
    @equalizers_dir = Path.new(config.fetch(:equalizers_dir))
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
      root_dir: @discogs_dir,
      user: config.fetch(:discogs, :user),
      token: config.fetch(:discogs, :token),
      ignore_folder_id: config.fetch(:discogs, :ignore_folder_id),
    )
  end

  def make_importer
    load_discogs
    Importer.new(
      discogs: @discogs,
      collection: @collection,
      archive_dir: @import_done_dir)
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

  def find_releases(args)
    load_discogs
    @discogs.releases.find(args)
  end

  def find_albums(args)
    @collection.albums.find(args)
  end

  def find_artists(args)
    @collection.artists.find(args)
  end

  def update_discogs
    load_discogs
    @discogs.update
  end

  def orphaned_albums
    load_discogs
    @collection.albums.items.reject { |a| @discogs.releases[a.id] }
  end

end