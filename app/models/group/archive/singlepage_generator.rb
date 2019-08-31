class Group::Archive::SinglepageGenerator
  include Group::Archive::Path

  attr_reader :tmp_dir, :excluded_assets
  MAX_ASSET_SIZE = 100.megabytes

  def initialize(group:, types:)
    self.group = group
    self.types = types
  end

  def generate
    @excluded_assets = []
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      prepare_files
      create_zip_file
    end
  end

  protected

  def prepare_files
    create_asset_dir # differs from pages_generator
    add_css_file
    add_group_content
    @group.real_committees.each do |committee|
      add_group_content(committee)
    end
  end

  def add_group_content(group = @group)
    add_pages(group)
    add_avatar(group)
  end

  def create_zip_file
    zf = ::ZipFileGenerator.new(tmp_dir, stored_zip_file('singlepage'))
    zf.write
  end

  def group_pages(group)
    group.pages_of_type(types)
  end

  def group_names
    @group.group_names
  end

  # singlepage specific stuff

  def create_asset_dir
    FileUtils.mkdir_p(File.join(tmp_dir, 'assets'))
  end


  def add_pages(group)
    pages = group_pages(group)
    return if pages.empty?
    content = ''
    pages.each do |page|
      add_assets(page)
    end
    content = singlepage_content(group)
    return unless content
    File.open(File.join(tmp_dir, "#{group.name}.html"), 'w') { |file| file.write(content) }
  end

  def singlepage_content(group)
    Group::ArchivesController.render :singlepage,
      assigns: {group: group, pages: group.pages},
      layout: 'archive/singlepage'
  end

  def add_assets(page)
    page.assets.each do |attachment|
      add_asset(attachment)
    end
    add_asset(page.data)
  end

  def add_css_file
    FileUtils.cp File.join(STYLES_DIR, 'archive.css'), tmp_dir
  end

  def add_avatar(group)
    FileUtils.cp avatar_url_for(group), File.join(tmp_dir, 'assets', "#{group.name}.jpg")
  rescue Errno::ENOENT => error
    Rails.logger.error 'Avatar file missing: ' + error.message
  end

  def add_to_excluded_assets(asset)
    @excluded_assets << asset.id
  end

  # TODO: add to asset class
  def big_asset?(asset)
    asset.size > MAX_ASSET_SIZE
  end


  def add_asset(asset)
    return unless asset.is_a? Asset # better check page type before?
    if big_asset?(asset)
      add_to_excluded_assets(asset)
    else
      copy_asset_files(asset)
    end
  end

  def copy_asset_files(asset)
    begin
      asset_id = asset.id.to_s
      FileUtils.mkdir(asset_path(asset_id)) unless File.exist?(asset_path(asset_id))
      FileUtils.cp asset.private_filename, File.join(asset_path(asset_id), asset.filename.tr(' ', '+'))
      asset.thumbnails.each do |thumbnail|
        FileUtils.cp thumbnail.private_filename, File.join(asset_path(asset_id), thumbnail.filename.tr(' ', '+'))
      end
    rescue Errno::ENOENT => error
      Rails.logger.error 'Asset file missing: ' + error.message
    end
  end

  private

  attr_writer :group
  attr_accessor :types
end
