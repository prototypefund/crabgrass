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

  def group_names
    @group.group_names
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
    layout = Haml::Engine.new(File.read('app/views/group/archives/layout_pages.html.haml'))
    layout.render Object.new, title: page.title, css_file: css_file(page.owner) do
      body = Haml::Engine.new(File.read('app/views/group/archives/page.html.haml'))
      body.to_html Object.new, wiki_html: fixed_html(page), group: page.owner, page: page, type: :pages
    end
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

  def fixed_html(page)
    return nil unless page.type == 'WikiPage'
    html = page.wiki.body_html.gsub('/asset', 'asset')
    group_names.each do |name|
      name = name.sub('+', '\\\+')
      res = html.match(/href=\"((\/#{name}\/)([^.\"]*))\"+/)
      next unless res
      # <MatchData "href=\"/animals/wiki-page-with-comments\""
      # 1:"/animals/wiki-page-with-comments"
      # 2:"/animals/"
      # 3:"wiki-page-with-comments"
      full_match = Regexp.last_match(1)
      group_match = Regexp.last_match(2)
      page_match = Regexp.last_match(3)
      # TODO: fix links for id-links like (see SinglepageGenerator)
      html = html.gsub(full_match, full_match + '.html')
      html = if name == page.owner.name # link to same group
               html.gsub(group_match, '')
             else
               if name.include? '+'
                 html.gsub(full_match, "../#{full_match[1..-1]}")
               else
                 html.gsub(full_match, "../../#{full_match[1..-1]}")
               end
             end
    end
    html
  end


  private

  attr_writer :user, :group
  attr_accessor :types
end
