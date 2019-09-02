require 'integration_test'
require 'fileutils'

class GroupArchiveTest < IntegrationTest

  def setup
    FileUtils.mkdir_p(ASSET_PRIVATE_STORAGE)
    Group::Archive.delete_all # FIXME: we should not need this!
    Delayed::Worker.delay_jobs = false
    super
  end

  def teardown
    #FileUtils.rm_rf(ASSET_PRIVATE_STORAGE)
    Delayed::Worker.delay_jobs = true
    super
  end

  def test_create_archive
    @user = users(:blue)
    login
    visit '/recent_group'
    click_on 'Settings'
    click_on 'Archive'
    click_on 'Create a new Archive'
    # sleep 2
    click_on 'Archive'
    assert_content 'Download'
  end

  def test_create_archive_with_request
    @user = users(:blue)
    login
    visit '/animals'
    click_on 'Settings'
    click_on 'Archive'
    click_link 'Create a new Archive'
    assert_content 'Request to create Group Archive'
    logout
    @user = users(:penguin)
    login
    @request = Request.last
    visit "/groups/animals/requests/#{@request.id}"
    click_on 'Approve'
    # sleep 2
    click_on 'Settings'
    click_on 'Archive'
    assert_content 'animals.zip'
  end

  def test_delete_archive
    @user = users(:blue)
    login
    visit '/recent_group'
    click_on 'Settings'
    click_on 'Archive'
    click_on 'Create a new Archive'
    click_on 'Archive'
    # sleep 2
    click_on 'Destroy'
    assert_no_content 'Destroy'
  end

  def test_re_create_archive
    @user = users(:blue)
    login
    visit '/recent_group'
    click_on 'Settings'
    click_on 'Archive'
    click_on 'Create a new Archive'
    click_on 'Archive'
    # sleep 2
    click_on 'Destroy'
    assert_no_content 'Destroy'
    click_on 'Create a new Archive'
    # sleep 2
    click_on 'Archive'
    assert_content 'Download'
  end
end
