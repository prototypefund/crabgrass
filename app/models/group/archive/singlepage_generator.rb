class Group::Archive::SinglepageGenerator

  include Group::Archive::Path

  # FIXME: move to superclass

  def initialize(opts = {})
    @group = opts[:group]
    @pages = opts[:pages]
    @types = opts[:types]
  end

  def generate
    self.prepare_files
    self.create_zip_file
  end

  protected

  attr_reader :group

  def prepare_files
    create_dirs
    add_group_content
    group.committees.each do |committee|
      add_group_content(committee)
    end
  end

  def add_group_content(mygroup = group)
    add_pages(mygroup)
    add_avatar(mygroup)
  end

  def create_zip_file
    zf = ::ZipFileGenerator.new(singlepage_dir, stored_zip_file)
    zf.write()
  end

  def group_pages(group)
    group.pages_of_type(types)
  end

  # singlepage specific stuff ?

  def create_dirs
    FileUtils.rm_f(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    FileUtils.mkdir_p(singlepage_dir) unless File.exists?(singlepage_dir)
    FileUtils.mkdir_p(File.join(singlepage_dir, 'assets')) unless File.exists?(File.join(singlepage_dir, 'assets'))
    FileUtils.mkdir_p(pages_dir) unless File.exists?(pages_dir)
  end

  def add_pages(group)
    @toc = []
    pages = group_pages(group)
    return unless pages.size > 0
    content = ""
    pages.each do |page|
      content = append_to_singlepage(page, content)
    end
    return unless content
    content = toc_html(group) + content
    File.open(File.join(singlepage_dir, "#{group.name}.html"), 'w') { |file| file.write(content) }
  end

  def append_to_singlepage(page, content)
    content +=  page_content(page)
    page.assets.each do |attachment|
      add_asset(attachment)
    end
    add_asset(page.data)
    return content
  end

  def page_content(page)
    @toc << "<p><a href=\##{page.id}>#{page.title}</a></p>"
    template = File.read('app/views/group/archives/page.html.haml')
    haml_engine = Haml::Engine.new(template)
    if page.type == 'WikiPage'
      wiki_html = nil ||page.wiki.body_html.gsub('/asset', 'asset')
      haml_engine.to_html Object.new, wiki_html: fix_links(group.name, wiki_html), group: group, page: page
    else
      haml_engine.to_html Object.new, group: group, page: page, wiki_html: nil
    end
  end

  def add_avatar(group)
    begin
      FileUtils.cp avatar_url_for(group), File.join(singlepage_dir, 'assets', "#{group.name}.jpg")
    rescue Errno::ENOENT => error
      Rails.logger.error 'Avatar file missing: ' + error.message
    end
  end

  def add_asset(asset, group = nil)
    return unless asset.is_a? Asset
    begin
      asset_id = asset.id.to_s
      FileUtils.cp File.join(asset_path(asset_id, group), asset.filename.gsub(' ', '+')), asset.private_filename
      asset.thumbnails.each do |thumbnail|
        FileUtils.cp File.join(asset_path(asset_id, group), thumbnail.filename.gsub(' ', '+')), thumbnail.private_filename
      end
    rescue Errno::ENOENT => error
      Rails.logger.error 'Asset file missing: ' + error.message
    end
  end

  def page_anchor(name)
    '#' + Page.find_by(name: name).try.id.to_s
  end

  def fix_links(group_name, html)
    group_names = group.group_names
    group_names.each do |searched_name|
      res = html.match(/href=\"((\/#{searched_name}\/)([^.\"]*))\"+/)
      if res
        #<MatchData "href=\"/animals/wiki-page-with-comments\""
        #1:"/animals/wiki-page-with-comments"
        #2:"/animals/"
        #3:"wiki-page-with-comments"
        full_match = $1
        group_match = $2
        page_match = $3

        # TODO: link to pages in other (public) groups
        if searched_name == group_name # link to same group
          html = html.gsub(full_match, page_anchor(page_match))
        else
          fixed_link = searched_name + '.html' + page_anchor(page_match)
          html = html.gsub(full_match, fixed_link)
        end
      end
    end
    return html
  end

  def toc_html(group)
    toc_html = "<img src='assets/#{group.name}.jpg' alt='avatar' height='64' width='64'>"
    toc_html << "<h1>Archive of #{group.name}</h1>"
    toc_html << "<p>Created on #{Time.now.getutc}</p>"
    @toc.each do |entry|
      toc_html << entry
    end
    return toc_html
  end

  private
  attr_reader :types
  attr_writer :toc
end
