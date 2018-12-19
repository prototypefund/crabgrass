require 'javascript_integration_test'
require 'fileutils'

class GroupArchiveTest < JavascriptIntegrationTest
  fixtures :users

  def setup
    FileUtils.rm_r(Group::Archive.archive_dir) if File.directory?(Group::Archive.archive_dir)
    Group::Archive.delete_all
    Delayed::Worker.delay_jobs = false
    super
  end

  def teardown
    FileUtils.rm_r(Group::Archive.archive_dir) if File.directory?(Group::Archive.archive_dir)
    Delayed::Worker.delay_jobs = true
    super
  end

  def test_create_archive
    @user = users(:blue)
    login
    visit '/recent_group'
    click_on 'Settings'
    click_on 'Archives'
    click_on 'one file per page'
    click_on 'OK'
    sleep 2
    click_on 'Archives'
    assert_content 'Download'
  end

  def test_create_archive_with_request
    @user = users(:blue)
    login
    visit '/animals'
    click_on 'Settings'
    click_on 'Archives'
    click_link 'join pages in one file'
    assert_content 'Request to create Group Archive'
    logout
    @user = users(:penguin)
    login
    @request = Request.last
    visit "/groups/animals/requests/#{@request.id}"
    click_on 'Approve'
    sleep 2
    click_on 'Settings'
    click_on 'Archives'
    assert_content 'download'
  end

  def test_delete_archive
    @user = users(:blue)
    login
    visit '/recent_group'
    click_on 'Settings'
    click_on 'Archives'
    click_on 'one file per page'
    click_on 'OK'
    click_on 'Archives'
    sleep 2
    click_on 'Delete'
    assert_no_content 'Delete'
  end

end
