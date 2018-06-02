require 'test_helper'

##
## All these tests are disabled, because Group::WikiController is now
## much more simple and these tests do not apply. I am keeping these here
## in case some of this logic is put back into Group::WikiController.
##

# FIXME: tests are not running - magiX involved???
class Group::WikisControllerTest < ActionController::TestCase
  def setup
    @user = FactoryBot.create(:user)
    @group = FactoryBot.create(:group)
    @group.add_user!(@user)
  end

  # TODO: check if we want to test negative case as well
  def xtest_new
    login_as @user
    xhr :get, :new, group_id: @group.to_param
    assert_response :success
    assert assigns['wiki'].new_record?
  end

  def xtest_new_private_wiki
    login_as @user
    xhr :get, :new, group_id: @group.to_param, private: true
    assert_response :success
    assert assigns['wiki'].new_record?
    assert_select 'input#wiki_private[type="hidden"][value="true"]'
  end

  def xtest_new_with_existing_wiki
    login_as @user
    @wiki = @group.profiles.public.create_wiki body: 'init'
    xhr :get, :new, group_id: @group.to_param
    assert_response :success
    assert !assigns['wiki'].new_record?
    assert_template 'groups/home/reload'
    assert_equal 'text/javascript', @response.content_type
  end

  def xtest_new_with_existing_private_wiki
    login_as @user
    @wiki = @group.profiles.private.create_wiki body: 'init'
    xhr :get, :new, group_id: @group.to_param, private: true
    assert_response :success
    assert !assigns['wiki'].new_record?
    assert_template 'groups/home/reload'
    assert_equal 'text/javascript', @response.content_type
  end

  def xtest_new_private_with_existing_public_wiki
    login_as @user
    @wiki = @group.profiles.public.create_wiki body: 'init'
    xhr :get, :new, group_id: @group.to_param, private: true
    assert_response :success
    assert assigns['wiki'].new_record?
    assert_select 'input#wiki_private[type="hidden"][value="true"]'
  end

  # TODO: check if we want to test negative case as well
  def xtest_create_private
    login_as @user
    xhr :post, :create,
        group_id: @group.to_param,
        wiki: { body: '_created_', private: true }
    wiki = Wiki.last
    assert '<em>created</em>', wiki.body_html
    assert wiki.profile.private?
    assert_equal @user, wiki.versions.last.user
    assert_response :redirect
    assert_redirected_to group_home_url(@group, wiki_id: wiki.id)
  end

  # TODO: check if we want to test negative case as well
  def xtest_create_public
    login_as @user
    xhr :post, :create,
        group_id: @group.to_param,
        wiki: { body: '_created_', private: false }
    wiki = Wiki.last
    assert '<em>created</em>', wiki.body_html
    assert wiki.profile.public?
    assert_response :redirect
    assert_redirected_to group_home_url(@group, wiki_id: wiki.id)
  end

  def xtest_create_with_existing_wiki
    @wiki = @group.profiles.public.create_wiki body: 'init'
    login_as @user
    assert_difference '@wiki.versions.count' do
      xhr :post, :create,
          group_id: @group.to_param,
          wiki: { body: '_created_', private: false }
    end
    wiki = Wiki.last
    assert '<em>created</em>', wiki.body_html
    assert wiki.profile.public?
    assert_response :redirect
    assert_redirected_to group_home_url(@group, wiki_id: wiki.id)
  end
end
