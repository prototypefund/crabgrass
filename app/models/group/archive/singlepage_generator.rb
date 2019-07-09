class Group::Archive::SinglepageGenerator
  include Group::Archive::Path

  def initialize(user: nil, group: nil, types: nil)
    self.user = user
    self.group = group
    self.types = types
  end

  def generate
    prepare_files
    create_zip_file
  end

  protected

  def prepare_files
    create_dirs
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
    zf = ::ZipFileGenerator.new(singlepage_dir, stored_zip_file('singlepage'))
    zf.write
  end

  def group_pages(group)
    group.pages_of_type(types)
  end

  def group_names
    @group.group_names
  end

  # singlepage specific stuff

  def create_dirs
    FileUtils.rm_f(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    FileUtils.mkdir_p(singlepage_dir) unless File.exist?(singlepage_dir)
    FileUtils.mkdir_p(File.join(singlepage_dir, 'assets')) unless File.exist?(File.join(singlepage_dir, 'assets'))
  end

  def add_pages(group)
    @toc = []
    pages = group_pages(group)
    return if pages.empty?
    content = ''
    pages.each do |page|
      content = append_to_singlepage(page, content) if @user.may?(:admin, page)
    end
    return unless content
    content = toc_html(group) + content
    File.open(File.join(singlepage_dir, "#{group.name}.html"), 'w') { |file| file.write(content) }
  end

  def append_to_singlepage(page, content)
    content += page_content(page)
    page.assets.each do |attachment|
      add_asset(attachment)
    end
    add_asset(page.data)
    content
  end

  def page_content(page)
    @toc << "<p><a href=\##{page.id}>#{page.title}</a></p>"
    template = File.read('app/views/group/archives/page.html.haml')
    haml_engine = Haml::Engine.new(template)
    # FIXME: link stuff not working yet.
    if page.type == 'WikiPage'
      wiki_html = nil || page.wiki.body_html.gsub('/asset', 'asset')
      haml_engine.to_html Object.new, wiki_html: fix_links(page.owner.name, wiki_html), group: page.owner, page: page
    else
      haml_engine.to_html Object.new, group: page.owner, page: page, wiki_html: nil
    end
  end

  def add_avatar(group)
    FileUtils.cp avatar_url_for(group), File.join(singlepage_dir, 'assets', "#{group.name}.jpg")
  rescue Errno::ENOENT => error
    Rails.logger.error 'Avatar file missing: ' + error.message
  end

  def add_asset(asset, _group = @group)
    return unless asset.is_a? Asset # page.assets also contains wikis!
    begin
      asset_id = asset.id.to_s
      FileUtils.mkdir(asset_path_singlepage(asset_id)) unless File.exist?(asset_path_singlepage(asset_id))
      FileUtils.cp asset.private_filename, File.join(asset_path_singlepage(asset_id), asset.filename.tr(' ', '+'))
      asset.thumbnails.each do |thumbnail|
        FileUtils.cp thumbnail.private_filename, File.join(asset_path_singlepage(asset_id), thumbnail.filename.tr(' ', '+'))
      end
    rescue Errno::ENOENT => error
      Rails.logger.error 'Asset file missing: ' + error.message
    end
  end

  def page_anchor(name)
    '#' + Page.find_by(name: name).try.id.to_s
  end

  def fix_links(group_name, html)
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
      if name == group_name
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

  attr_writer :toc
end
