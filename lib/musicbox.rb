require 'autoeq_loader'
require 'discogs-collection'
require 'io-dispatcher'
require 'iterm-show-image-file'
require 'mime-types'
# require 'mp4tags'
require 'mpv_client'
require 'path'
require 'prawn'
require 'prawn/measurement_extensions'
require 'run-command'
require 'set_params'
require 'simple-command'
require 'simple-group'
require 'simple-printer'
require 'sixarm_ruby_unaccent'
require 'tty-config'
require 'tty-prompt'

require 'extensions/path'
require 'extensions/string'

require 'musicbox/error'

require 'musicbox/collection'
require 'musicbox/collection/album'
require 'musicbox/collection/albums'
require 'musicbox/collection/artist'
require 'musicbox/collection/artists'
require 'musicbox/collection/track'

require 'musicbox/player'
require 'musicbox/player/players/console'
require 'musicbox/player/listens'
require 'musicbox/player/listen'
require 'musicbox/player/playlist'
require 'musicbox/player/playlists'

require 'musicbox/printer'
require 'musicbox/printer/cover_maker'
require 'musicbox/printer/label_maker'

require 'musicbox/commands/check'
require 'musicbox/commands/cover'
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
require 'musicbox/commands/update_discogs'
require 'musicbox/commands/update_tags'

class MusicBox

  attr_accessor :root_dir
  attr_accessor :import_dir
  attr_accessor :archive_dir
  attr_accessor :discogs_dir
  attr_accessor :playlists_dir
  attr_accessor :listens_dir
  attr_accessor :collection_dir
  attr_accessor :collection

  def initialize(root_dir: nil)
    @root_dir = Path.new(root_dir || ENV['MUSICBOX_ROOT'] || '~/Music/MusicBox').expand_path
    @import_dir = @root_dir / 'import'
    @archive_dir = @root_dir / 'import-done'
    @discogs_dir = @root_dir / 'discogs'
    @playlists_dir = @root_dir / 'playlists'
    @listens_dir = @root_dir / 'listens'
    @collection_dir = @root_dir / 'collection'
    @collection = Collection.new(root_dir: @collection_dir)
  end

  def inspect
    "<#{self.class}>"
  end

  def config
    unless @config
      @config = TTY::Config.new
      @config.append_path(@root_dir)
      @config.set(:root_dir, value: @root_dir)
      @config.env_prefix = 'MUSICBOX'
      @config.autoload_env
      @config.read
    end
    @config
  end

  def find_albums(*args)
    @collection.albums.find(*args)
  end

  def find_artists(*args)
    @collection.artists.find(*args)
  end

  def equalizers_dir
    Path.new(config.fetch(:equalizers_dir))
  end

  def discogs_user
    config.fetch(:discogs, :user)
  end

  def discogs_token
    config.fetch(:discogs, :token)
  end

  def discogs_ignore_folder_id
    config.fetch(:discogs, :ignore_folder_id)
  end

  def canonical_names
    config.fetch(:canonical_names)
  end

  def personal_names
    config.fetch(:personal_names)
  end

end