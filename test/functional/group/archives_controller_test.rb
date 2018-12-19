require 'test_helper'

class Group::ArchivesControllerTest < ActionController::TestCase

  fixtures :users, :groups

  def setup
    @user = users(:blue)
    @group = groups(:recent_group)
  end

  def test_access_archive_page
    login_as @user
    get :index, group_id: :recent_group
    assert_response :success
    assert_select '.btn-primary'
  end

  def test_not_logged_in
    assert_not_found do
      get :index, group_id: @group.to_param
    end
  end

  def test_no_member
    login_as :red
    assert_not_found do
      get :index, group_id: @group.to_param
    end
  end

end
