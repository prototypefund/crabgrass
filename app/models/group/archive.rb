require 'zip'

#
# HTML-Archive of group content for download
#

class Group::Archive < ActiveRecord::Base

  include Group::Archive::Path

  belongs_to :group
  before_destroy :delete_group_archive_dir
  validates :group, presence: true

  attr_accessor :user
  attr_reader :singlepage, :toc

  ARCHIVED_TYPES = %w[WikiPage DiscussionPage AssetPage Gallery]

  def self.find_or_create(attrs)
    archive = Group::Archive.where(group: attrs[:group]).first
    if archive
      archive.update(updated_by_id: attrs[:user].id)
    else
      archive = Group::Archive.create(group: attrs[:group], created_by_id: attrs[:user].id)
    end
    return archive
  end

  def self.archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archive')
  end

  def create_archives
    #self.singlepage = true # TODO: create two zip files
    FileUtils.rm_f(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)

    FileUtils.rm_f(next_version_dir)
    FileUtils.mkdir_p(next_version_dir)

    Zip::File.open(tmp_zip_file, Zip::File::CREATE) do |zipfile|
      add_content(group, zipfile)
      group.committees.each do |committee|
        add_content(committee, zipfile)
      end
    end
    FileUtils.mv(tmp_zip_file, next_version_dir)
    self.version += 1
    FileUtils.rm_f(tmp_dir)
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


  protected

  before_validation :create_archives

  def delete_group_archive_dir
    FileUtils.rm_f(group_archive_dir)
  end

  def group_pages(group)
    group.pages_of_type(ARCHIVED_TYPES)
  end

  def add_content(group, zipfile)
    add_pages(group, zipfile)
    add_avatar(group, zipfile)
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
      zipfile.get_output_stream("#{group.name}.html") { |file|
        file.write content if content }
    else
      zipfile.get_output_stream(index_path(group)) { |file|
        file.write table_of_content(group, pages) }
    end
  end

  def add_page(page, group, zipfile)
    zipfile.get_output_stream(file_path(page, group)) { |file|
      file.write page_content(page) }
    add_asset(page.data, zipfile, group)
    page.assets.each do |attachment|
      add_asset(attachment, zipfile, group)
    end
    return zipfile
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

  def add_avatar(group, zipfile)
    begin
      zipfile.add(File.join(avatar_path(group), "#{group.name}.jpg"), avatar_url_for(group))
    rescue Errno::ENOENT => error
      Rails.logger.error 'Avatar file missing: ' + error.message
    end
    return zipfile
  end

  def add_asset(asset, zipfile, group = nil)
    return unless asset.is_a? Asset
    begin
      asset_id = asset.id.to_s
      zipfile.add(File.join(asset_path(asset_id, group), asset.filename.gsub(' ', '+')), asset.private_filename)
      asset.thumbnails.each do |thumbnail|
        zipfile.add(File.join(asset_path(asset_id, group), thumbnail.filename.gsub(' ', '+')), thumbnail.private_filename)
      end
      rescue Errno::ENOENT => error
      Rails.logger.error 'Asset file missing: ' + error.message
    end
    return zipfile
  end


  def page_anchor(name)
    '#' + Page.find_by(name: name).try.id.to_s
  end

  def fix_links(group_name, html, singlepage)
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

        if singlepage
          # TODO: link to pages in other (archived) groups
          if searched_name == group_name # link to same group
            html = html.gsub(full_match, page_anchor(page_match))
          else
            fixed_link = searched_name + '.html' + page_anchor(page_match)
            html = html.gsub(full_match, fixed_link)
          end
        else
          html = html.gsub(full_match, full_match+'.html')
          if searched_name == group.name # link to same group
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
      add_asset(attachment, zipfile)
    end
    add_asset(page.data, zipfile)
    return [content, zipfile]
  end

  private
  attr_writer :singlepage, :toc
end
