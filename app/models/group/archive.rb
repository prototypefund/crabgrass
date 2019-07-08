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
  belongs_to :group
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id' # not sure if we need this
  validates_presence_of :group, :user
  before_destroy :delete_group_archive_dir

  ARCHIVED_TYPES = %w[WikiPage DiscussionPage AssetPage Gallery].freeze

  PENDING = 'pending'.freeze # TODO: replace by enum (maybe add expired state)
  SUCCESS = 'success'.freeze

  attr_accessor :user


  # TODO: check if we can use Group::Archive::Path instead

  def self.archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archives')
  end

  def group_archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archives', group.id.to_s)
  end

  def zipname_suffix
    "#{group.name}.zip"
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

  # end paths

  def pending?
    self.state == PENDING
  end

  def process
    return false unless self.valid?
    self.created_by_id = user.id
    self.state = PENDING
    save!
    delete_old_archive
    Group::Archive::SinglepageGenerator.new(user: user, group: group, types: ARCHIVED_TYPES).generate
    Group::Archive::PagesGenerator.new(user: user, group: group, types: ARCHIVED_TYPES).generate
    self.state = SUCCESS
    self.filename = zipname_suffix
    save!
  rescue Exception => exc
    byebug
    Rails.logger.error 'Archive could not be created: ' + exc.message
  ensure
    move_tmp_dir_to_old if group
  end

  def archived_by
    User.find_by_id(created_by_id).login
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
