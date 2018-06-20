class Group::ProfilesController < Group::BaseController
  before_filter :fetch_profile
  helper :profile

  def edit
    authorize @group, :admin?
  end

  def update
    authorize @group, :admin?
    if params[:clear_photo]
      @profile.picture.destroy
    else
      @profile.save_from_params profile_params
    end
    success :profile_saved.t
    redirect_to edit_group_profile_url(@group)
  end

  private

  def fetch_profile
    @profile = @group.profiles.public if @group
    true
  end

  def profile_params
    params.require(:profile).permit :place, :summary, picture: [:upload]
  end
end
