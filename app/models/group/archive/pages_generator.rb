class Group::Archive::PagesGenerator
  include Group::Archive::Path

  attr_reader :tmp_dir

  def initialize(user:, group:, types:)
    self.user = user
    self.group = group
    self.types = types
  end

  def generate
    Dir.mktmpdir do |dir|
      @tmp_dir = dir
      prepare_files
      create_zip_file
    end
  end

  protected

  def prepare_files
    create_group_dirs
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
    zf = ::ZipFileGenerator.new(tmp_dir, stored_zip_file('pages'))
    zf.write
  end

  def group_pages(group)
    group.pages_of_type(types)
  end

  # page zip specific stuff

  # tree structure with group directory at the top
  def create_group_dirs
    FileUtils.mkdir_p(asset_dir(@group))
    @group.committees.each do |committee|
      FileUtils.mkdir_p(asset_dir(committee))
    end
  end

  def add_pages(group)
    pages = group_pages(group)
    return if pages.empty?
    content = ''
    pages.each do |page|
      add_page(page, group) if @user.may?(:admin, page)
    end
    File.open(index_path(group), 'w') { |file| file.write(indexpage_content(group, pages)) }
  end

  def add_page(page, group)
    File.open(file_path(page, group), 'w') { |file| file.write(page_content(page)) }
    add_asset(page.data, group)
    page.assets.each do |attachment|
      add_asset(attachment, group)
    end
  end

  def page_content(page)
    Group::ArchivesController.render :page,
      assigns: page_assigns(page),
      layout: 'archive/pages'
  end

  def page_assigns(page)
    {
      page: page,
      title: page.title,
      css_file: css_file(page.owner)
    }
  end

  def indexpage_content(group, pages)
    template = File.read('app/views/group/archives/indexpage.html.haml')
    haml_engine = Haml::Engine.new(template)
    haml_engine.to_html Object.new, group: group, pages: pages, css_file: css_file(group)
  end

  def add_css_file
    FileUtils.cp File.join(STYLES_DIR, 'archive.css'), group_path(@group)
  end

  def add_avatar(group)
    FileUtils.cp avatar_url_for(group), File.join(asset_dir(group), "#{group.name}.jpg")
  rescue Errno::ENOENT => error
    Rails.logger.error 'Avatar file missing: ' + error.message
  end

  def add_asset(asset, group = @group)
    return unless asset.is_a? Asset
    begin
      asset_id = asset.id.to_s
      FileUtils.mkdir(asset_group_path(asset_id, group)) unless File.exist?(asset_group_path(asset_id, group))
      FileUtils.cp asset.private_filename, File.join(asset_group_path(asset_id, group), asset.filename.tr(' ', '+'))
      asset.thumbnails.each do |thumbnail|
        FileUtils.cp thumbnail.private_filename, File.join(asset_group_path(asset_id, group), thumbnail.filename.tr(' ', '+'))
      end
    rescue Errno::ENOENT => error
      Rails.logger.error 'Asset file missing: ' + error.message
    end
  end




  private

  attr_writer :user, :group
  attr_accessor :types
end
