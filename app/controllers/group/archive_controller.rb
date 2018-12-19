require 'zip'
require 'fileutils'

class Group::ArchiveController < Group::BaseController

  def show;
    authorize @group, :admin?
    @archive = @group.archive
    send_file @archive.stored_zip_file, type: 'application/zip', charset: 'utf-8', status: 202
  end

  def create
    authorize @group, :create_archive?
    Delayed::Job.enqueue GroupArchiveJob.new(@group, current_user, is_true?(params[:singlepage]))
    redirect_to group_settings_url(@group)
  end

  def destroy
    authorize @group, :admin?
    @group.archive.destroy
    redirect_to group_archives_url(@group)
  end

# TODO: move to helper
  def is_true?(string)
      ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(string)
  end

end
