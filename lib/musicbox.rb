require 'csv'
require 'discogs-wrapper'
require 'json'
require 'path'
require 'prawn'
require 'prawn/measurement_extensions'
require 'run-command'
require 'set'
require 'sixarm_ruby_unaccent'
require 'yaml'

require 'extensions/string'

require 'musicbox/version'
require 'musicbox/error'
require 'musicbox/group'
require 'musicbox/info_to_s'
require 'musicbox/prompt'

require 'musicbox/catalog'
require 'musicbox/catalog/album'
require 'musicbox/catalog/albums'
require 'musicbox/catalog/album_track'
require 'musicbox/catalog/artist'
require 'musicbox/catalog/artists'
require 'musicbox/catalog/format'
require 'musicbox/catalog/reference'
require 'musicbox/catalog/references'
require 'musicbox/catalog/release'
require 'musicbox/catalog/release_artist'
require 'musicbox/catalog/releases'
require 'musicbox/catalog/tags'
require 'musicbox/catalog/track'

require 'musicbox/discogs'
require 'musicbox/export'
require 'musicbox/importer'
require 'musicbox/labeler'