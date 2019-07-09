class Group::ArchivesController < Group::BaseController

  def index
    authorize @group, :admin?
    @request = Request.to_group(@group).pending.where(type: RequestToCreateGroupArchive).last
    @archive = @group.archive
  end

end
