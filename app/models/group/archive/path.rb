#
# All paths used for archive creation
#

module Group::Archive::Path

  # directories

  def group_archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archive', group.id.to_s)
  end

  def tmp_dir
    File.join(group_archive_dir, 'tmp')
  end

  def version_dir
    File.join(group_archive_dir, self.version.to_s)
  end

  def next_version_dir
    next_version = self.version + 1
    File.join(group_archive_dir, next_version.to_s)
  end

  # paths used in the zip files

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

  def asset_path(asset_id, group)
    if group
      File.join(group_path(group), 'assets', asset_id)
    else
      File.join('assets', asset_id)
    end
  end

  def avatar_path(group)
    if self.singlepage
      'assets'
    else
      File.join(group_path(group), 'assets')
    end
  end

  def avatar_url_for(group)
    format("#{APP_ROOT}/public/avatars/%s/large.jpg", group.avatar_id || 0)
  end

  # Filenames

  def tmp_zip_file
    File.join(tmp_dir, zipname)
  end

  def zipname
    "#{group.name}.zip"
  end

  def stored_zip_file
    File.join(version_dir, zipname)
  end


end
