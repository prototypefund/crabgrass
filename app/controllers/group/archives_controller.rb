class Group::ArchivesController < Group::BaseController

  def index
    authorize @group, :admin?
    @archive = @group.archive
  end

end
