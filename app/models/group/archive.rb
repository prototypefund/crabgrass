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
  validates :group, presence: true # do we need this?
  after_validation :process # Todo: replace with before_save + do not store pending archive.
  before_destroy :delete_group_archive_dir

  ARCHIVED_TYPES = %w[WikiPage DiscussionPage AssetPage Gallery]
  PENDING = 'pending'.freeze
  SUCCESS = 'success'.freeze

  attr_accessor :user

  # FIXME: find out which paths belong to the archive and which belong
  # to the generator

  def self.archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archives')
  end

  def group_archive_dir
    File.join(ASSET_PRIVATE_STORAGE, 'archives', group.id.to_s)
  end

  def zipname
    "#{group.name}.zip"
  end

  def stored_zip_file
     File.join(group_archive_dir, zipname)
  end

  def process
    begin
      self.state = PENDING
      gen = Group::Archive::SinglepageGenerator.new(group: group, types: ARCHIVED_TYPES)
      #gen = Group::Archive::PagesGenerator.new(group: group, types: ARCHIVED_TYPES)
      gen.generate
      self.state = SUCCESS
      self.save!
    rescue Exception => exc
      Rails.logger.error 'Archive could not be created: ' + exc.message
    end
  end

  def archived_by
    User.find_by_id(created_by_id).login
  end

  protected


  def delete_group_archive_dir
    FileUtils.rm_f(group_archive_dir)
  end

end
