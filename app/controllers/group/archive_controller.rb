require 'zip'
require 'fileutils'

class Group::ArchiveController < Group::BaseController

  def show
    authorize @group, :admin?
    @request = RequestToCreateGroupArchive.to_group(@group).pending.last
    @archive = @group.archive
    respond_to do |format|
      format.html
      format.zip do
        send_file @archive.zipfile, type: 'application/zip', charset: 'utf-8'
      end
    end
  end

  def create
    authorize @group, :create_archive?
    Delayed::Job.enqueue GroupArchiveJob.new(@group, current_user, I18n.locale)
    redirect_to group_archive_url(@group)
  end

  def destroy
    authorize @group, :admin?
    @group.archive.destroy
    redirect_to group_archive_url(@group)
  end

end
