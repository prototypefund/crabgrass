require 'test_helper'

class Group::ArchiveControllerTest < ActionController::TestCase

  fixtures :users, :groups

  def setup
    @user = users(:blue)
    @group = groups(:recent_group)
    Group::Archive.delete_all
    FileUtils.rm_r(Group::Archive.archive_dir) if File.directory?(Group::Archive.archive_dir)
    Delayed::Worker.delay_jobs = false
  end

  def teardown
    FileUtils.rm_r(Group::Archive.archive_dir) if File.directory?(Group::Archive.archive_dir)
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

  def test_increment_version
    login_as @user
    post :create, params: { group_id: :recent_group }
    id = Group::Archive.last.id
    version = Group::Archive.last.version
    post :create, params: { group_id: :recent_group }
    assert_equal id, Group::Archive.last.id
    assert_equal version+1, Group::Archive.last.version
  end

  def test_update_archive
    login_as @user
    post :create, params: { group_id: :recent_group }
    assert_nil Group::Archive.last.updated_by_id
    assert_no_difference 'Group::Archive.count' do
      post :create, params: { group_id: :recent_group }
      assert_equal @user.id, Group::Archive.last.updated_by_id
    end
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
