require 'integration_test'

class ImageTest < IntegrationTest
  def setup
    super
    FileUtils.mkdir_p(ASSET_PRIVATE_STORAGE)
    FileUtils.mkdir_p(ASSET_PUBLIC_STORAGE)
  end

  def test_get_asset
    asset = FactoryBot.create :image_asset
    visit asset.url
    assert_equal 200, status_code
  end

  def test_file_removed_before_first_visit
    asset = FactoryBot.create :image_asset
    asset.send :destroy_file
    visit asset.url
    assert_equal 404, status_code
  end

  def test_file_removed
    asset = FactoryBot.create :image_asset
    visit asset.url
    asset.send :destroy_file
    visit asset.url
    assert_equal 404, status_code
  end

  # we used to have some iso encoding so links would escape to
  # strings include %F3.
  # Now this old link will lead to utf-8 errors as the chars > \xF0 are
  # invalid. Let's make sure the old link still works...
  def test_get_asset_with_strange_char
    asset = FactoryBot.create :image_asset
    visit asset.url.sub('.jpg', '%F3.jpg')
    assert_equal 200, status_code
  end
end
