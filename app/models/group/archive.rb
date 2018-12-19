require 'zip'

class Group::Archive < ActiveRecord::Base

  acts_as_versioned
  belongs_to :group
  before_destroy :delete_group_archive_dir
  validates :group, presence: true
  validates :version, numericality: { greater_than: 0 }

  attr_accessor :user, :singlepage, :toc

  ARCHIVED_TYPES = %w[WikiPage DiscussionPage AssetPage Gallery]

  def self.find_or_create(attrs)
    archive = Group::Archive.where(group: attrs[:group]).first
    if archive
      archive.update(updated_by_id: attrs[:user].id, singlepage: attrs[:singlepage])
    else
      archive = Group::Archive.create(group: attrs[:group], created_by_id: attrs[:user].id, singlepage: attrs[:singlepage])
    end
    return archive
  end

  def create_archive
    FileUtils.rm_r(tmp_dir) if File.directory?(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    FileUtils.rm_r(next_version_dir) if File.directory?(next_version_dir)
    FileUtils.mkdir_p(next_version_dir)

    Zip::File.open(tmp_zip_file, Zip::File::CREATE) do |zipfile|
      add_pages(group, zipfile)
      add_avatar(group, zipfile)
      group.committees.each do |committee|
        add_pages(committee, zipfile)
        add_avatar(committee, zipfile)
      end
    end
    FileUtils.mv(tmp_zip_file, next_version_dir)
    self.version += 1
    FileUtils.rm_r(tmp_dir) if File.directory?(tmp_dir)
    self.state = 'success'
  rescue Exception => exc
    # FIXME: error handling and correct state
    self.state = 'failed'
    Rails.logger.error "Error creating archive " + exc.message
    return false
  end

  def archived_by
    id = updated_by_id || created_by_id
    User.find_by_id(id).login
  end

  def tmp_zip_file
    File.join(self.tmp_dir, self.zipname)
  end

  def stored_zip_file
    File.join(self.version_dir, self.zipname)
  end

  def self.archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archive')
  end

  protected

  before_validation :create_archive

  def group_pages group
    group.pages.where(owner_id: group.id).where(type: ARCHIVED_TYPES).order('type desc').order('updated_at DESC')
  end

  def group_archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archive', group.id.to_s)
  end

  def tmp_dir
    File.join(group_archive_dir, 'tmp')
  end

  def version_dir
    @version_dir = File.join(group_archive_dir, self.version.to_s)
  end

  def next_version_dir
    next_version = self.version + 1
    @next_version_dir = File.join(group_archive_dir, next_version.to_s)
  end

  def zipname
    return "#{group.name}.zip"
  end

  def group_path(group)
    if !group.parent_id
      group.name
    else
      File.join(group.parent.name, group.name)
    end
  end

  def index_path(group)
    File.join(group_path(group), "index.html")
  end

  def file_path(page, group)
    file_name = "#{page.name_url}.html"
    File.join(group_path(group), file_name)
  end

  def asset_path(asset, group)
    if group
      File.join(group_path(group), 'assets', asset.id.to_s)
    else
      File.join('assets', asset.id.to_s)
    end
  end

  def avatar_url_for(group)
    format("#{APP_ROOT}/public/avatars/%s/large.jpg", group.avatar_id || 0)
  end

  def avatar_path(group)
    if self.singlepage
     path = 'assets'
    else
      path = File.join(group_path(group), 'assets')
    end
    return path
  end

  def delete_group_archive_dir
    FileUtils.rm_r(group_archive_dir) if File.directory?(group_archive_dir)
  end

  def add_pages(group, zipfile)
    @toc = []
    pages = group_pages(group)
    return zipfile unless pages.size > 0
    content = ""
    pages.each do |page|
      if @singlepage
        content, zipfile = append_to_singlepage(page, zipfile, content)
      else
        zipfile = add_page(page, group, zipfile)
      end
    end
    if @singlepage
      content = toc_html(group) + content
      zipfile.get_output_stream("#{group.name}.html") { |f|
        f.write content if content }
    else
      zipfile.get_output_stream(index_path(group)) { |f|
        f.write table_of_content(group, pages) }
    end
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

  def append_to_singlepage(page, zipfile, content)
    content +=  page_content(page)
    page.assets.each do |attachment|
      add_asset(attachment, zipfile, thumbnails?(page))
    end
    add_asset(page.data, zipfile, false)
    return [content, zipfile]
  end

  def add_page(page, group, zipfile)
    zipfile.get_output_stream(file_path(page, group)) { |f|
      f.write page_content(page) }
    add_asset(page.data, zipfile, false, group)
    page.assets.each do |attachment|
      add_asset(attachment, zipfile, thumbnails?(page), group)
    end
    return zipfile
  end

  def page_content(page)
    @toc << "<p><a href=\##{page.id}>#{page.title}</a></p>"
    template = File.read('app/views/group/archives/page.html.haml')
    haml_engine = Haml::Engine.new(template)
    if page.type == 'WikiPage'
      wiki_html = nil ||page.wiki.body_html.gsub('/asset', 'asset')
      haml_engine.to_html Object.new, wiki_html: fix_links(page, wiki_html, singlepage), group: group, page: page
    else
      haml_engine.to_html Object.new, group: group, page: page, wiki_html: nil
    end
  end

  # Thumbnails might bei linked in wiki pages
  def thumbnails?(page)
    return page.type == 'WikiPage'
  end

  def add_avatar(group, zipfile)
    begin
      zipfile.add(File.join(avatar_path(group), "#{group.name}.jpg"), avatar_url_for(group))
    rescue Errno::ENOENT => e
      Rails.logger.error 'Avatar file missing: ' + e.message
    end
    return zipfile
  end

  def add_asset(asset, zipfile, thumbnails, group = nil)
    return if !asset.is_a? Asset
    begin
      zipfile.add(File.join(asset_path(asset, group), asset.filename.gsub(' ', '+')), asset.private_filename)
      if thumbnails
        asset.thumbnails.each do |thumbnail|
          zipfile.add(File.join(asset_path(asset, group), thumbnail.filename.gsub(' ', '+')), thumbnail.private_filename)
        end
      end
      rescue Errno::ENOENT => e
      Rails.logger.error 'Asset file missing: ' + e.message
    end
    return zipfile
  end

  def group_names(group)
    names = []
    if group.parent_id
      names << group.parent.name
    else
      names << group.name
    end
    if group.children.any?
      names += group.children.pluck(:name)
    end
    return names
  end

  def page_anchor(name)
    '#' + Page.find_by(name: name).try.id.to_s
  end

  # FIXME: only works for links to pages with names
  # and not for pages with id suffix like pagename+1000
  def fix_links(page, html, singlepage)
    groups = group_names(group)
    groups.each do |name|
      name_escaped = name.sub('+', '\\\+')
      res = html.match(/href=\"((\/#{name_escaped}\/)([^.\"]*))\"+/)
      if res
        #<MatchData "href=\"/animals/wiki-page-with-comments\""
        #1:"/animals/wiki-page-with-comments"
        #2:"/animals/"
        #3:"wiki-page-with-comments"
        full_match = $1
        group_match = $2
        page_match = $3

        if singlepage
          # TODO: link to pages in other (archived) groups
          if page.group.name == name # link to same group
            html = html.gsub(full_match, page_anchor(page_match))
          elsif group_names(page.group).include? name
            fixed_link = name + '.html' + page_anchor(page_match)
            html = html.gsub(full_match, fixed_link)
          end
        else
          html = html.gsub(full_match, full_match+'.html')
          if page.group.name == name # link to same group
            html = html.gsub(group_match, '')
          else
            html = html.gsub(full_match, full_match[1..-1])
          end
        end
      end
    end
    return html
  end

  # TODO: move to template
  def table_of_content(group, pages)
    html = "<html><head></head><meta charset='UTF-8'><body><table>"
    html << "<img src='assets/#{group.name}.jpg')} alt='avatar' height='64' width='64'>"
    html << "<h1>Archive of #{pages.first.owner.display_name}</h1>"
    html << "<p>Created on #{Time.now.getutc}</p>"
    html << "<h3>#{:private_wiki.t}</h3>#{group.private_wiki.body_html}" if group.private_wiki
    html << "<h3>#{:public_wiki.t}</h3>#{group.public_wiki.body_html}" if group.public_wiki
    pages.each do |page|
      html << "<tr><td><a href=./#{page.name_url}.html>#{page.title}</a></td><td>#{:updated_by.t} #{page.updated_by.display_name}</td><td>#{page.updated_at}</td></tr>"
    end
    html << '</table>'
    if group.children.any?
      html << "<h3>#{:committees.t}</h3>"
      group.children.each do |child|
        html << "<p><a href=./#{child.name}/index.html>#{child.display_name}</a></p>"
      end
    end
    html << '</html>'
  end

end
