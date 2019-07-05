require 'test_helper'

class Group::ArchiveControllerTest < ActionController::TestCase
  fixtures :users, :groups

  def setup
    @user = users(:blue)
    @group = groups(:recent_group)
    FileUtils.rm_rf(ASSET_PRIVATE_STORAGE)
    Delayed::Worker.delay_jobs = false
  end

  def teardown
    FileUtils.rm_rf(ASSET_PRIVATE_STORAGE)
    Delayed::Worker.delay_jobs = true
  end

  def test_download_archive
    login_as @user
    post :create, params: { group_id: :recent_group }
    get :show, params: { group_id: :recent_group }
    assert_response 202 # TODO: download file
  end

  def test_show_not_logged_in
    get :show, params: { group_id: :recent_group }
    assert_not_found
  end

  def test_create_not_logged_in
    post :create, params: { group_id: :recent_group }
    assert_not_found
  end

  def test_create_archive
    login_as @user
    assert_not @group_archive
    post :create, params: { group_id: :recent_group }
    assert @group.archive
    assert_response :redirect
  end

  def test_create_archive_not_member
    login_as :red
    post :create, params: { group_id: :recent_group }
    assert_not_found
  end

  def test_destroy_archive_not_member
    login_as :red
    post :create, params: { group_id: :recent_group }
    assert_not_found
  end

  def test_destroy_archive
    login_as @user
    post :create, params: { group_id: :recent_group }
    assert @group.archive
    sleep 5
    assert_difference 'Group::Archive.count', -1 do
      post :destroy, params: { group_id: :recent_group }
    end
  end
end
