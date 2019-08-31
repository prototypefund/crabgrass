require 'zip'
require 'zipfilegenerator'

#
# HTML-Archive of group content for download
#
# creates two zip files:
#
# - singlepage: one HTML file per group or committee
# - pages: one HTML file per page
#
# Big files are not archived. For those files we show
# download links.
#
# TODO: currently we store the ids of the big files during
# archive generation and show links to the files which are
# still available. New big files will not be displayed.
#

class Group::Archive < ActiveRecord::Base
  belongs_to :group
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  validates_presence_of :group, :created_by_id
  before_destroy :delete_archive_dir
  attr_reader :excluded_assets

  ARCHIVED_TYPES = %w[WikiPage DiscussionPage AssetPage Gallery].freeze
  EXPIRY_PERIOD = 1.month.freeze

  enum state: { pending: 0, success: 1 }

  def process
    return false unless valid?
    remove_old_archive
    generator = Group::Archive::Generator.new(archive: self, types: ARCHIVED_TYPES)
    generator.generate
    self.excluded_asset_ids = generator.excluded_assets.join(',')
    self.filename = zipname
    self.state = 'success'
    save!
  rescue Exception => exc
    Rails.logger.error 'Archive could not be created: ' + exc.message
    Rails.logger.warn exc.backtrace.join("\n")
  end

  def zipfile
    File.join(archive_dir, zipname)
  end

  def zipname
    "#{group.name}.zip"
  end

  def excluded_assets
    unless excluded_asset_ids.empty?
      ids = excluded_asset_ids.split(',')
      assets = Asset.where(id: ids)
    else
      []
    end
  end

# remove self where it is not needed!
  def expires_at
    self.created_at + EXPIRY_PERIOD
  end

  def expired?
    Time.zone.now > expires_at
  end

  def archived_by
    created_by.login
  end

  def zipname_suffix
    "#{group.name}.zip"
  end

  private

  def archive_dir
    File.join(ARCHIVE_STORAGE, group.id.to_s)
  end

  def remove_old_archive
    delete_archive_dir
    Group::Archive.where(group_id: group.id).order('created_at DESC').offset(1).destroy_all
    create_archive_dir
  end

  def create_archive_dir
    FileUtils.mkdir_p(archive_dir)
  end

  def delete_archive_dir
    FileUtils.rm_r(archive_dir) if File.exist? archive_dir
  end

end
