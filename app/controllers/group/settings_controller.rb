class Group::SettingsController < Group::BaseController
  def show
    authorize @group, :admin?
  end

  def update
    authorize @group, :admin?
    @group.update_attributes! group_params
    success
    redirect_to group_settings_url(@group)
  end

  protected

  def group_type
    @group.class.name.downcase.to_sym
  end
  helper_method :group_type

  def group_params
    params.require(:group).permit :name, :full_name, :language
  end
end
