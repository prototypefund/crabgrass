require 'integration_test'

class GroupDestructionTest < IntegrationTest
  def test_visit_own_group
    @user = users(:blue)
    login
    visit '/animals'
    click_on 'Settings'
    click_on 'Structure'
    click_on 'Destroy animals'
    assert_content 'Request to Destroy Group was sent to animals'
    assert_no_content 'Approve'
    logout
    @user = users(:penguin)
    login
    click_on 'Show Request'
    click_on 'Approve'
    click_on 'Groups'
    assert_no_content 'animals'
  end

  def test_visit_asset_page_owned_by_group_after_group_destruction
    @user = users(:blue)
    login
    visit '/animals'
    click_on 'Settings'
    click_on 'Structure'
    click_on 'Destroy animals'
    logout
    @user = users(:penguin)
    login
    visit '/me'
    assert_content 'sunset'
    click_on 'Show Request'
    click_on 'Approve'
    visit '/me'
    assert_no_content 'sunset'
    visit pages(:asset_sunset).uri
    assert_not_found
  end

  def test_visit_wiki_page_owned_by_group_after_group_destruction
    @user = users(:blue)
    login
    visit '/rainbow'
    click_on 'Settings'
    click_on 'Structure'
    click_on 'Destroy rainbow'
    logout
    @user = users(:yellow)
    login
    visit '/me'
    assert_content 'page owned by rainbow'
    click_on 'Show Request'
    click_on 'Approve'
    visit '/me'
    assert_no_content 'page owned by rainbow'
    visit pages(:rainbow_page).uri
    assert_not_found
  end

  def test_visit_wiki_page_owned_by_group
    @user = users(:blue)
    login
    visit pages(:rainbow_page).uri+'+'+pages(:rainbow_page).id.to_s
    assert_equal 200, status_code
  end

  def test_visit_asset_page_owned_by_group_with_user_participation_after_group_destruction
    @user = users(:blue)
    pages(:asset_sunset).add(users(:penguin), access: :admin)
    pages(:asset_sunset).save!
    assert pages(:asset_sunset).owner == groups(:animals)
    login
    visit '/animals'
    click_on 'Settings'
    click_on 'Structure'
    click_on 'Destroy animals'
    logout
    @user = users(:penguin)
    login
    visit '/me'
    assert_content 'sunset'
    click_on 'Show Request'
    click_on 'Approve'
    visit '/me'
    #assert_no_content 'sunset' # hidden because of https://0xacab.org/riseuplabs/crabgrass/merge_requests/139/diffs
    visit pages(:asset_sunset).uri
    assert_not_found
  end

  def test_visit_wiki_page_owned_by_group_with_user_participation_after_group_destruction
    @user = users(:red)
    pages(:rainbow_page).add(users(:yellow), access: :admin)
    pages(:rainbow_page).save!
    assert pages(:rainbow_page).owner == groups(:rainbow)
    login
    visit '/rainbow'
    click_on 'Settings'
    click_on 'Structure'
    click_on 'Destroy rainbow'
    logout
    @user = users(:yellow)
    login
    visit '/me'
    assert_content 'page owned by rainbow'
    click_on 'Show Request'
    click_on 'Approve'
    visit '/me'
    #assert_no_content 'sunset' # hidden because of https://0xacab.org/riseuplabs/crabgrass/merge_requests/139/diffs
    #visit pages(:rainbow_page).uri # TEST will pass if we do this
    #before (migth be related to caching)
    visit pages(:rainbow_page).uri+'+'+pages(:rainbow_page).id.to_s
    assert_not_found
  end
end
