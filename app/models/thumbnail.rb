#
#  create_table "thumbnails", :force => true do |t|
#    t.integer "parent_id",    :limit => 11
#    t.string  "parent_type"
#    t.string  "content_type"
#    t.string  "filename"
#    t.string  "name"
#    t.integer "size",         :limit => 11
#    t.integer "width",        :limit => 11
#    t.integer "height",       :limit => 11
#    t.integer "job_id",
#    t.boolean "failure"
#  end
#
class Thumbnail < ActiveRecord::Base
  #
  # Our parent could be the main asset, or it could be a *version* of the
  # asset.
  # If we are a thumbnail of the main asset:
  #   self.parent_id = id of asset
  #   self.parent_type = "Asset"
  # If we are the thumbnail of an asset version:
  #   self.parent_id = id of the version
  #   self.parent_type = "Asset::Version"
  #
  belongs_to :parent, polymorphic: true

  after_destroy :rm_file
  def rm_file
    unless proxy?
      fname = path.private_filename(filename)
      FileUtils.rm(fname) if File.exist?(fname) and File.file?(fname)
    end
  end

  # returns the thumbnail object that we depend on, if any.
  def depends_on
    @depends ||= parent.thumbnail(thumbdef.try.depends, true)
  end

  # finds or initializes a Thumbnail
  def self.find_or_init(thumbnail_name, parent_id, asset_class)
    find_or_initialize_by name: thumbnail_name.to_s,
                          parent_id: parent_id,
                          parent_type: asset_class
  end

  def self.clone(orig, options = {})
    create orig.attributes.except('id').merge(options)
  end

  #
  # generates the thumbnail file for this thumbnail object.
  #
  # if force is true, then generate the thumbnail even if it already
  # exists.
  #
  def generate(force = false)
    if proxy?
      nil
    elsif !force and File.exist?(private_filename) and File.size(private_filename) > 0
      nil
    else
      if depends_on
        depends_on.generate(force)
        input_type  = depends_on.content_type
        input_file  = depends_on.private_filename
      else
        input_type  = parent.content_type
        input_file  = parent.private_filename
      end
      output_type = thumbdef.mime_type
      output_file = private_filename

      options = {
        size: thumbdef.size,
        input_file: input_file, input_type: input_type,
        output_file: output_file, output_type: output_type
      }

      generate_now(options)
      save if changed?
    end
  end

  def versioned
    unless parent.is_version?
      asset = parent.versions.detect { |v| v.version == parent.version }
      asset.thumbnail(name) if asset
    end
  end

  def small_icon
    "mime/small/#{Media::MimeType.icon_for(content_type)}"
  end

  def title
    thumbdef.try.title || Media::MimeType.description_from_mime_type(content_type)
  end

  # delegate path stuff to the parent
  delegate :path, to: :parent

  def private_filename
    path.private_filename filename
  end

  def public_filename
    path.public_filename filename
  end

  def url
    path.url filename
  end

  def exists?
    parent.thumbnail_exists?(name)
  end

  def thumbdef
    definition = parent.thumbdefs[name.to_sym]
    if definition.blank?
      logger.error "Error: No thumbnail definition found for #{name} #{id}"
    end
    definition
  end

  def ok?
    !failure?
  end

  #
  # returns true if this thumbnail is a proxy AND
  # the main asset file is the same content type as
  # this thumbnail.
  #
  # when true, we skip all processing of this thumbnail
  # and just proxy to the main asset.
  #
  # For example, in the Asset::Doc, if the uploaded file is a microsoft word
  # file, then we first convert it to a libreoffice document before converting
  # to a pdf. However, If the uploaded file is already libreoffice, then
  # the libreoffice thumbnail is just proxied to the original uploaded file.
  #
  # This seems messy to me, there is probably a cleaner way.
  #
  def proxy?
    thumbdef.try.proxy && parent.content_type == thumbdef.mime_type
  end

  private

  def generate_now(options)
    trans = Media.transmogrifier(options)
    # trans can be nil for old assets that still have a thumbnail
    # were we currently do not have a transmogrifier.
    # Observed this for .xcf - but probably better to be save anyway.
    # So using try here.
    if trans.try.run == :success
      update_metadata(options)
      self.failure = false
    else
      self.failure = true
    end
    save if changed?
  end

  def update_metadata(options)
    # dimensions
    if Media.has_dimensions?(options[:output_type]) and thumbdef.try.size.present?
      self.width, self.height = Media.dimensions(options[:output_file])
    end
    # size
    self.size = File.size(options[:output_file])

    # by the time we figure out what the thumbnail dimensions are,
    # the duplicate thumbnails for the version have already been created.
    # so, when our dimensions change, update the versioned thumb as well.
    if (vthumb = versioned).present?
      vthumb.width = width
      vthumb.height = height
      vthumb.save
    end
  end
end
