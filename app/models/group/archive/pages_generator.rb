class Group::Archive::PagesGenerator
  include Group::Archive::Path

  # FIXME: move to superclass

  def initialize(opts = {})
    @group = opts[:group]
    @user = opts[:user]
    @types = opts[:types]
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
    zf = ::ZipFileGenerator.new(pages_dir, stored_zip_file('pages'))
    zf.write
  end

  def group_pages(group)
    group.pages_of_type(types)
  end

  def group_names
    @group.group_names
  end

  # page zip specific stuff

  def create_dirs
    FileUtils.rm_f(tmp_dir)
    FileUtils.mkdir_p(pages_dir) unless File.exist?(pages_dir)
    create_group_dirs
  end

  # tree structure with group directory at the top
  def create_group_dirs
    FileUtils.mkdir_p(asset_dir(@group))
    @group.committees.each do |committee|
      FileUtils.mkdir_p(asset_dir(committee))
    end
  end

  def add_pages(group)
    @toc = []
    pages = group_pages(group)
    return if pages.empty?
    content = ''
    pages.each do |page|
      add_page(page, group) if @user.may?(:admin, page)
    end
    File.open(index_path(group), 'w') { |file| file.write(table_of_content(group, pages)) }
  end

  def add_page(page, group)
    File.open(file_path(page, group), 'w') { |file| file.write(page_content(page)) }
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
      wiki_html = nil || page.wiki.body_html.gsub('/asset', 'asset')
      # FIXME: not sure if page.owner is the right choice here - it was
      # @group before which seemed wrong.
      haml_engine.to_html Object.new, wiki_html: fix_links(page.owner.name, wiki_html), group: page.owner, page: page
    else
      haml_engine.to_html Object.new, group: page.owner, page: page, wiki_html: nil
    end
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
      FileUtils.mkdir(asset_path(asset_id, group)) unless File.exist?(asset_path(asset_id, group))
      FileUtils.cp asset.private_filename, File.join(asset_path(asset_id, group), asset.filename.tr(' ', '+'))
      asset.thumbnails.each do |thumbnail|
        FileUtils.cp thumbnail.private_filename, File.join(asset_path(asset_id, group), thumbnail.filename.tr(' ', '+'))
      end
    rescue Errno::ENOENT => error
      Rails.logger.error 'Asset file missing: ' + error.message
    end
  end

  def fix_links(group_name, html)
    group_names.each do |searched_name|
      res = html.match(/href=\"((\/#{searched_name}\/)([^.\"]*))\"+/)
      next unless res
      # <MatchData "href=\"/animals/wiki-page-with-comments\""
      # 1:"/animals/wiki-page-with-comments"
      # 2:"/animals/"
      # 3:"wiki-page-with-comments"
      full_match = Regexp.last_match(1)
      group_match = Regexp.last_match(2)
      page_match = Regexp.last_match(3)

      html = html.gsub(full_match, full_match + '.html')
      html = if searched_name == group_name # link to same group
               html.gsub(group_match, '')
             else
               html.gsub(full_match, full_match[1..-1])
             end
    end
    html
  end

  # TODO: move to template
  def table_of_content(group, pages)
    public_wiki = group.public_wiki
    private_wiki = group.private_wiki
    html = "<html><head></head><meta charset='UTF-8'><body><table>"
    html << "<img src='assets/#{group.name}.jpg')} alt='avatar' height='64' width='64'>"
    html << "<h1>Archive of #{group.display_name}</h1>"
    html << "<p>Created on #{Time.now.getutc}</p>"
    html << "<h3>#{:private_wiki.t}</h3>#{private_wiki.body_html}" if private_wiki&.has_content?
    html << "<h3>#{:public_wiki.t}</h3>#{public_wiki.body_html}" if public_wiki&.has_content?
    pages.each do |page|
      html << "<tr><td><a href=./#{page.name_url}.html>#{page.title}</a></td><td>#{:updated_by.t} #{page.updated_by.display_name}</td><td>#{page.updated_at}</td></tr>"
    end
    html << '</table>'
    if group.council
      html << "<h3>#{:council.t}</h3>"
      unless group_pages(group.council).empty?
        html << "<p><a href=./#{group.council.name}/index.html>#{group.council.display_name}</a></p>"
      end
    end
    if group.real_committees.any?
      html << "<h3>#{:committees.t}</h3>"
      group.children.each do |committee|
        unless group_pages(committee).empty?
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
