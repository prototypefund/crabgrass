require 'zip'

Zip.setup do |c|
  c.on_exists_proc = true
  c.continue_on_exists_proc = true
  c.unicode_names = true
  c.force_entry_names_encoding = 'UTF-8'
  c.default_compression = Zlib::BEST_COMPRESSION
end
