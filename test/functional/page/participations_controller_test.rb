require 'test_helper'

class Page::ParticipationsControllerTest < ActionController::TestCase
  def setup
    @user = FactoryBot.create :user
    @page = FactoryBot.create :page
    @upart = @page.add(@user, access: :admin)
    @upart.save
    login_as @user
  end

  def test_star
    assert_difference 'Page::History::AddStar.count' do
      post :update, params: { page_id: @page, id: @upart, star: true }, xhr: true
    end
    assert @upart.reload.star
  end

  def test_star_as_create
    @other = FactoryBot.create :user
    login_as @other
    @page.update_attribute :public, true
    assert_difference 'User::Participation.count' do
      post :create, params: { page_id: @page, star: true }, xhr: true
    end
    assert @other.participations.last.star
  end

  def test_watch
    assert_difference 'Page::History::StartWatching.count' do
      post :update, params: { page_id: @page, id: @upart, watch: true }, xhr: true
    end
    assert @upart.reload.watch
  end

  def test_prevent_increasing_access
    @upart.access = :view
    @upart.save
    assert_no_difference 'Page::History.count' do
      assert_permission_denied do
        post :update, params: { page_id: @page, id: @upart, access: :admin }, xhr: true
      end
    end
    assert_equal :view, @upart.reload.access_sym
  end

  def test_destroy_user_participation
    other_user = FactoryBot.create :user
    other_upart = @page.add(other_user, access: :view)
    other_upart.save
    assert_difference 'Page::History.count' do
      post :update, params: { page_id: @page, id: other_upart, access: :remove }, xhr: true
      assert_response :success
    end
  end

  def test_destroy_group_participation
    group = FactoryBot.create :group
    gpart = @page.add(group, access: :view)
    gpart.save
    assert_difference 'Page::History.count' do
      post :update, params: { page_id: @page, id: gpart, group: true, access: :remove }, xhr: true
    end
  end
end
