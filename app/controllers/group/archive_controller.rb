require 'zip'
require 'fileutils'

class Group::ArchiveController < Group::BaseController

  def show
    authorize @group, :admin?
    redirect_to group_archives_url(@group) unless @group.archive
    send_file @group.archive.zipfile,
      type: 'application/zip',
      charset: 'utf-8',
      status: 202
  end

  def create
    authorize @group, :create_archive?
    Delayed::Job.enqueue GroupArchiveJob.new(@group, current_user, I18n.locale)
    redirect_to group_archives_url(@group)
  end

  def destroy
    authorize @group, :admin?
    @group.archive.destroy
    redirect_to group_archives_url(@group)
  end

end
