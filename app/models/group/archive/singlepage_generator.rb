class Group::Archive::SinglepageGenerator
  include Group::Archive::Path

  attr_reader :tmp_dir, :excluded_assets
  MAX_ASSET_SIZE = 100.megabytes

  def initialize(user:, group:, types:)
    self.user = user
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
    @group.committees.each do |committee|
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
    @toc = []
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
    layout = Haml::Engine.new(File.read('app/views/group/archives/layout.html.haml'))
    layout.render Object.new, title: group.name, css_file: css_file(group) do
      body_html = ''
      group.pages.each do |page|
        @toc << "<p><a href=\##{page.id}>#{page.title}</a></p>"
        body = Haml::Engine.new(File.read('app/views/group/archives/page.html.haml'))
        body_html += body.to_html Object.new, wiki_html: fixed_html(page), group: page.owner, page: page
      end
      toc_html(group) + body_html
    end
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

  def page_anchor(name)
    '#' + Page.find_by(name: name).try.id.to_s
  end

  def fixed_html(page)
    return nil unless page.type == 'WikiPage'
    html = page.wiki.body_html.gsub('/asset', 'asset')
    group_names.each do |name|
      name = name.sub('+', '\\\+')
      res = html.match(/href="(\/(#{name})\/([^.\"]*))"+/)
      next unless res
      # <MatchData "href=\"/animals/wiki-page-with-comments\""
      # 1:"/animals/wiki-page-with-comments"
      # 2:"animals"
      # 3:"wiki-page-with-comments"
      full_match = Regexp.last_match(1)
      group_match = Regexp.last_match(2)
      page_match = Regexp.last_match(3)
      # TODO: fix links for id-links like
      # Markup: [anchor text -> +1007]
      # HTML: <a href="/rainbow/+1007">anchor text</a>
      # Attention: group lookup is required because
      # 'rainbow' might not be the parent and not the owner
      if name == page.owner.name
        html = html.gsub(full_match, page_anchor(page_match))
      else
        fixed_link = group_match + '.html' + page_anchor(page_match)
        html = html.gsub(full_match, fixed_link)
      end
    end
    html
  end

  def toc_html(group)
    toc_html = "<img src='assets/#{group.name}.jpg' alt='avatar' height='64' width='64'>"
    toc_html << "<h1>Archive of #{group.name}</h1>"
    toc_html << "<p>Created on #{Time.now.getutc}</p>"
    @toc.each do |entry|
      toc_html << entry
    end
    toc_html
  end

  private

  attr_writer :user, :group
  attr_accessor :types
end
