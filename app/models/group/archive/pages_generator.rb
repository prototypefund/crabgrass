class Group::Archive::PagesGenerator

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

 # page zip specific stuff

  def create_dirs
    FileUtils.rm_f(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    #    FileUtils.mkdir_p(File.join(singlepage_dir, 'assets')) unless File.exists?(File.join(singlepage_dir, 'assets')) # FIXME: we have to do this for all groups/committees.
    FileUtils.mkdir_p(pages_dir) unless File.exists?(pages_dir)
  end


  def add_pages(group)
    @toc = []
    pages = group_pages(group)
    return unless pages.size > 0
    content = ""
    pages.each do |page|
      add_page(page, group)
    end
    File.open(index_path(group), 'w') { |file| file.write(table_of_content(group, pages)) }
  end

  def add_page(page, group)
    # TODO: write content to file
    # file_path(page, group)
    # page_content(page)

    add_asset(page.data, group)
    page.assets.each do |attachment|
      add_asset(attachment, group)
    end
  end

  def page_content(page)
    @toc << "<p><a href=\##{page.id}>#{page.title}</a></p>"
    template = File.read('app/views/group/archives/page.html.haml')
    haml_engine = Haml::Engine.new(template)
    if page.type == 'WikiPage'
      wiki_html = nil ||page.wiki.body_html.gsub('/asset', 'asset')
      haml_engine.to_html Object.new, wiki_html: fix_links(group.name, wiki_html, singlepage), group: group, page: page
    else
      haml_engine.to_html Object.new, group: group, page: page, wiki_html: nil
    end
  end

  def add_avatar(group, dir)
    begin
      FileUtils.cp avatar_url_for(group), File.join(dir, 'assets', "#{group.name}.jpg")
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

  def fix_links(group_name, htmle)
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

        html = html.gsub(full_match, full_match+'.html')
        if searched_name == group.name # link to same group
          html = html.gsub(group_match, '')
        else
          html = html.gsub(full_match, full_match[1..-1])
        end
      end
    end
    return html
  end

  # TODO: move to template
  def table_of_content(group, pages)
    public_wiki = group.public_wiki
    private_wiki = group.private_wiki
    html = "<html><head></head><meta charset='UTF-8'><body><table>"
    html << "<img src='assets/#{group.name}.jpg')} alt='avatar' height='64' width='64'>"
    html << "<h1>Archive of #{group.display_name}</h1>"
    html << "<p>Created on #{Time.now.getutc}</p>"
    html << "<h3>#{:private_wiki.t}</h3>#{private_wiki.body_html}" if private_wiki and private_wiki.has_content?
    html << "<h3>#{:public_wiki.t}</h3>#{public_wiki.body_html}" if public_wiki and public_wiki.has_content?
    pages.each do |page|
      html << "<tr><td><a href=./#{page.name_url}.html>#{page.title}</a></td><td>#{:updated_by.t} #{page.updated_by.display_name}</td><td>#{page.updated_at}</td></tr>"
    end
    html << '</table>'
    if group.council
      html << "<h3>#{:council.t}</h3>"
      if group_pages(group.council).size > 0
        html << "<p><a href=./#{group.council.name}/index.html>#{group.council.display_name}</a></p>"
      end
    end
    if group.real_committees.any?
      html << "<h3>#{:committees.t}</h3>"
      group.children.each do |committee|
        if group_pages(committee).size > 0
          html << "<p><a href=./#{committee.name}/index.html>#{committee.display_name}</a></p>"
        end
      end
    end
    html << '</html>'
  end

  private
  attr_reader :types
  attr_writer :toc
end
