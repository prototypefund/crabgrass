class WikiPage < Page
  include Page::RssData

  def title=(value)
    write_attribute(:title, value)
    write_attribute(:name, value.nameize) if value
  end

  # for fulltext index
  def body_terms
    return '' unless data and data.body
    data.body
  end

  def wiki(*args)
    data(*args) or begin
      newwiki = Wiki.new do |w|
        w.user = created_by
        w.body = ''
      end
      self.data = newwiki
      return newwiki if new_record?
      save
      newwiki.reload
    end
  end

  def archive_html(archive_type)
    html = wiki.body_html.gsub('/asset', 'asset')
    owner.group_names.each do |name|
      name = name.sub('+', '\\\+')
      res = html.match(/href=\"((\/#{name}\/)([^.\"]*))\"+/)
      next unless res
      if archive_type == 'singlepage'
        html = singlepage_replace_links(html, res)
      else
        html = replace_links(html, res)
      end
    end
    html
  end

  def singlepage_replace_links(html, res)
    # <MatchData "href=\"/animals/wiki-page-with-comments\""
    # 1:"/animals/wiki-page-with-comments"
    # 2:"/animals/"
    # 3:"wiki-page-with-comments"
    full_match = res[1]
    group_match = res[2]
    page_match = res[3]
    # TODO: fix links for id-links like
    # Markup: [anchor text -> +1007]
    # HTML: <a href="/rainbow/+1007">anchor text</a>
    # Attention: group lookup is required because
    # 'rainbow' might not be the parent and not the owner
    if name == owner.name
      html = html.gsub(full_match, page_anchor(page_match))
    else
      fixed_link = group_match + '.html' + page_anchor(page_match)
      html = html.gsub(full_match, fixed_link)
    end
  end

  def page_anchor(name)
    '#' + Page.find_by(name: name).try.id.to_s
  end

  def replace_links(html, res)
    # <MatchData "href=\"/animals/wiki-page-with-comments\""
    # 1:"/animals/wiki-page-with-comments"
    # 2:"/animals/"
    # 3:"wiki-page-with-comments"
    full_match = res[1]
    group_match = res[2]
    page_match = res[3]
    # TODO: fix links for id-links like (see SinglepageGenerator)
    html = html.gsub(full_match, full_match + '.html')
    html = if name == owner.name # link to same group
             html.gsub(group_match, '')
           else
             if name.include? '+'
               html.gsub(full_match, "../#{full_match[1..-1]}")
             else
               html.gsub(full_match, "../../#{full_match[1..-1]}")
             end
           end
    html
  end

  protected

  before_save :update_wiki_group
  def update_wiki_group
    if owner_name_changed?
      wiki.clear_html if wiki
    end
  end
end
