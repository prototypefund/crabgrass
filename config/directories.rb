require 'pathname'
#
# All the magic directory constants should live here.
#

dirs = []

APP_ROOT = Pathname.new(File.dirname(__FILE__)) + '..'

# config

dirs << CRABGRASS_CONFIG_DIRECTORY = APP_ROOT + 'config/crabgrass'

# extensions

dirs << EXTENSION_DIRECTORY       = APP_ROOT + 'extensions'
dirs << THEMES_DIRECTORY          = EXTENSION_DIRECTORY + 'themes'
dirs << SEARCH_FILTERS_DIRECTORY  = EXTENSION_DIRECTORY + 'search_filters'
dirs << LOCALE_OVERRIDE_DIRECTORY = EXTENSION_DIRECTORY + 'locales'

# plugins

dirs << PAGES_DIRECTORY             = EXTENSION_DIRECTORY + 'pages'
dirs << CRABGRASS_PLUGINS_DIRECTORY = APP_ROOT + 'vendor/crabgrass_plugins'

# tmp

dirs << TMP_DIRECTORY   = APP_ROOT + 'tmp'
dirs << CACHE_DIRECTORY = TMP_DIRECTORY + 'cache'

# stylesheets and javascript

dirs << STATIC_JS_SRC_DIR        = APP_ROOT + 'app/assets/javascripts'
dirs << AS_NEEDED_JS_SRC_DIR     = APP_ROOT + 'app/assets/javascripts/as_needed'
dirs << STATIC_JS_DEST_DIR       = APP_ROOT + 'public/static'
dirs << AS_NEEDED_JS_DEST_DIR    = APP_ROOT + 'public/static/as_needed'
dirs << STYLES_DIR               = APP_ROOT + 'app/assets/stylesheets' # TODO: check if there is a Rails constant for this.

# assets

if Rails.env == 'test'
  dirs << ASSET_PRIVATE_STORAGE   = APP_ROOT + 'tmp/private_assets'
  dirs << ASSET_PUBLIC_STORAGE    = APP_ROOT + 'tmp/public_assets'
  dirs << PICTURE_PRIVATE_STORAGE = APP_ROOT + 'tmp/private_pictures'
  dirs << PICTURE_PUBLIC_STORAGE  = APP_ROOT + 'tmp/public_pictures'
  dirs << KEYRING_STORAGE         = APP_ROOT + 'tmp/private_assets/keyrings'
  dirs << ARCHIVE_STORAGE         = APP_ROOT + 'tmp/private_assets/archives'
else
  dirs << ASSET_PRIVATE_STORAGE   = APP_ROOT + 'assets'
  dirs << ASSET_PUBLIC_STORAGE    = APP_ROOT + 'public/assets'
  dirs << PICTURE_PRIVATE_STORAGE = APP_ROOT + 'assets/pictures'
  dirs << PICTURE_PUBLIC_STORAGE  = APP_ROOT + 'public/pictures'
  dirs << KEYRING_STORAGE         = APP_ROOT + 'assets/keyrings'
  dirs << ARCHIVE_STORAGE         = APP_ROOT + 'assets/archives'
end

#
# ensure the directories exist
#

require 'fileutils'

dirs.each do |dir|
  resolved = File.symlink?(dir) ? File.readlink(dir) : dir
  next if File.directory?(resolved)
  if File.exist?(resolved)
    msg = 'ERROR: %s is supposed to be a directory, but file already exists'
    raise format(msg, resolved)
  end
  FileUtils.mkdir_p(resolved)
end
