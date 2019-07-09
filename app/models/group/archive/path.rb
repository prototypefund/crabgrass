#
# All paths used for archive creation
#

module Group::Archive::Path
  # directories

  def group_archive_dir(group = @group)
    File.join(ARCHIVE_STORAGE, group.id.to_s)
  end

  def tmp_dir
    File.join(group_archive_dir, 'tmp')
  end

  def singlepage_dir
    File.join(tmp_dir, 'singlepage')
  end

  # TODO: rename - it is not clear that this is for pages_html and not
  # for singlepages
  def pages_dir
    File.join(tmp_dir, 'pages')
  end

  # for pages_zip only

  def group_path(group)
    if !group.parent_id
      File.join(pages_dir, group.name)
    else
      File.join(pages_dir, group.parent.name, group.name)
    end
  end

  def index_path(group)
    File.join(group_path(group), 'index.html')
  end

  def file_path(page, group)
    file_name = "#{page.name_url}.html"
    File.join(group_path(group), file_name)
  end

  def asset_path(asset_id, group)
    File.join(group_path(group), 'assets', asset_id)
  end

  def asset_dir(group = @group)
    File.join(group_path(group), 'assets')
  end

  def avatar_url_for(group)
    format("#{APP_ROOT}/public/avatars/%s/large.jpg", group.avatar_id || 0)
  end

  def asset_path_singlepage(asset_id)
    File.join(singlepage_dir, 'assets', asset_id)
  end

  # Filenames

  def tmp_zip_file
    File.join(tmp_dir, zipname)
  end

  def zipname_suffix
    "#{@group.name}.zip"
  end

  def zipname(type)
    if type == 'singlepage'
      'singlepage_' + zipname_suffix
    else
      'pages_' + zipname_suffix
    end
  end

  def stored_zip_file(type)
    File.join(group_archive_dir, zipname(type))
  end

end
