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

  PENDING = 'pending'.freeze # TODO: replace by enum (maybe add expired state)
  SUCCESS = 'success'.freeze

  # TODO: rename the following two methods.
  # they belong to the archive and not to path.
  def group_archive_dir
    File.join(ARCHIVE_STORAGE, group.id.to_s)
  end

  def zipname_suffix
    "#{group.name}.zip"
  end

  def pending?
    self.state == PENDING
  end

  def process
    # TODO: check if we can move this to the Job
    return false unless valid?
    delete_old_archive
    Group::Archive::SinglepageGenerator.new(user: created_by, group: group, types: ARCHIVED_TYPES).generate
    Group::Archive::PagesGenerator.new(user: created_by, group: group, types: ARCHIVED_TYPES).generate
    self.filename = zipname_suffix
    self.state = SUCCESS
    save!
  rescue Exception => exc
    Rails.logger.error 'Archive could not be created: ' + exc.message
    # TODO: we might want to delete the pending archive in case of error
  ensure
    move_tmp_dir_to_old if group
  end

  def archived_by
    created_by.login
  end

  protected

  def delete_old_archive
    delete_stored_zip_files
    Group::Archive.where(group_id: group.id).order('created_at DESC').offset(1).destroy_all # delete old archives
  end

  def delete_stored_zip_files
    FileUtils.rm(stored_zip_file('singlepage')) if File.exist? stored_zip_file('singlepage')
    FileUtils.rm(stored_zip_file('pages')) if File.exist? stored_zip_file('pages')
  end

  def delete_group_archive_dir
    FileUtils.rm_f(group_archive_dir) if File.exist? group_archive_dir
  end

  # FIXME: deleting the tmp dir does not work - so we move it to 'old' -
  # which is messy, because the first mv will create the dir and the
  # subsequent will add content to it
  def move_tmp_dir_to_old
    tmp_dir = File.join(group_archive_dir, 'tmp')
    #FileUtils.rm_f(tmp_dir) if File.exist? tmp_dir # FIXME: this is not working!
    FileUtils.mv tmp_dir, File.join(group_archive_dir, 'old'), :force => true if File.exist? tmp_dir
  end
end
