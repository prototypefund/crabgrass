# encoding: utf-8

require 'javascript_integration_test'

class PageSidebarJavascriptTest < JavascriptIntegrationTest

  fixtures :users, :groups, 'group/memberships', :pages

  def setup
    super
    @user = users(:blue)
    own_page
    login
    click_on own_page.title
  end

  def test_watch
    watch_page
    assert_page_watched
    unwatch_page
    assert_page_not_watched
  end

  def test_stars
    star_page
    assert_page_starred
    remove_star_from_page
    assert_page_not_starred
  end

  def test_public
    make_page_public
    assert_page_public
    make_page_private
    assert_page_private
  end

  def test_share_with_user
    share_page_with users(:red)
    assert_page_users user, users(:red)
  end

  def test_share_with_group
    share_page_with groups(:animals)
    assert_page_groups groups(:animals)
  end

  def test_share_with_committee
    share_page_with groups(:cold)
    assert_page_groups groups(:cold)
  end

  # regression test for #7834
  def test_sharing_preserves_stars
    star_page
    assert_page_starred
    share_page_with users(:red)
    assert_page_starred
  end

  def test_remove_user_from_page
    @page.add(users(:red), access: :admin)
    @page.save!
    visit current_url # reload
    assert_page_users users(:blue), users(:red)
    change_access_to 'No Access'
    assert_page_users users(:blue)
    logout
    @user = users(:red)
    login
    assert_no_content @page.title
  end

  def test_change_user_access
    @page.add(users(:red), access: :admin)
    @page.save!
    visit current_url # reload
    assert_selector '.tiny_wrench_16', text: 'Red!'
    assert_page_users users(:blue), users(:red)
    change_access_to 'Read Only'
    assert_no_selector '.tiny_wrench_16', text: 'Red!'
    assert_page_users users(:blue), users(:red)
  end

  def test_trash
    path = current_path
    delete_page
    assert_content 'Notices'
    assert_no_content own_page.title
    assert_equal '/me', current_path
    visit path
    undelete_page
    assert_content 'Delete Page'
    click_on 'Me'
    assert_content own_page.title
  end

  def test_destroy
    path = current_path
    click_on 'Delete Page'
    choose 'Destroy Immediately'
    click_button 'Delete'
    # finish deleting...
    assert_content 'Notices'
    assert_no_content own_page.title
  end

  def test_history
    create_page title: "Test page"
    click_on 'Page Details'
    find('a', text: 'History').click
    assert_content 'Blue! has created the page'
  end

  def test_tag
    tags = %w[Some tags for this páge a.tag]
    tag_page tags
    assert_page_tags 'some'
    assert_page_tags 'páge'
    assert_page_tags 'a.tag'
    remove_page_tag 'a.tag'
    assert_no_page_tags 'a.tag'
  end

  def test_long_tags
    tags = ["number one: this is a long tag -  we will have many of them to make sure that we can deal with them.",
            "number two: this is a long tag -  we will have many of them to make sure that we can deal with them.",
            "number three: this is a long tag - we will have many of them to make sure that we can deal with them.",
            "number four: this is a long tag - we will have many of them to make sure that we can deal with them.",
            "number five: this is a long tag - we will have many of them to make sure that we can deal with them.",
            "number six: this is a long tag - we will have many of them to make sure that we can deal with them."]
    tag_page tags
    sleep 1
    assert_page_tags 'number three: this is a long tag'
  end

  def test_too_long_tag
    long_tag = ["this is a very long tag which is far too long - a tag should not exceed 190 characters in the future and this string is definitely longer. if people use longer tags there will be an error message. this string is exactly 258 characters long which is too long"]
    tag_page long_tag
    sleep 1
    assert_no_page_tags 'this is a very long tag which is far too long'
    assert_content "Changes could not be saved" # FIXME: Wrong error message displayed: Tag can't be blank
  end

  def test_attach_file
    assert_no_selector '#attachments a.attachment'
    attach_file_to_page
    check_attachment_thumbnail
    assert_selector '#attachments a.attachment'
    remove_file_from_page
    assert_no_selector '#attachments a.attachment'
  end
end
