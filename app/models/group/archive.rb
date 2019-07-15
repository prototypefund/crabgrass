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

class Group::Archive < ActiveRecord::Base
  include Group::Archive::Path
  belongs_to :group
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  validates_presence_of :group, :created_by_id
  before_destroy :delete_group_archive_dir

  ARCHIVED_TYPES = %w[WikiPage DiscussionPage AssetPage Gallery].freeze

  enum state: { pending: 0, success: 1 }

  def process
    return false unless valid?
    remove_old_archive
    Group::Archive::SinglepageGenerator.new(user: created_by, group: group, types: ARCHIVED_TYPES).generate
    Group::Archive::PagesGenerator.new(user: created_by, group: group, types: ARCHIVED_TYPES).generate
    self.filename = zipname_suffix
    self.state = 'success'
    save!
  rescue Exception => exc
    Rails.logger.error 'Archive could not be created: ' + exc.message
  end

  def archived_by
    created_by.login
  end

  def zipname_suffix
    "#{group.name}.zip"
  end

  private

  def group_archive_dir
    File.join(ARCHIVE_STORAGE, group.id.to_s)
  end

  def remove_old_archive
    delete_group_archive_dir
    Group::Archive.where(group_id: group.id).order('created_at DESC').offset(1).destroy_all
    create_group_archive_dir
  end

  def create_group_archive_dir
    FileUtils.mkdir_p(group_archive_dir)
  end

  def delete_group_archive_dir
    FileUtils.rm_r(group_archive_dir) if File.exist? group_archive_dir
  end

end
