require 'test_helper'

class Asset::PdfTest < ActiveSupport::TestCase
  def setup
    setup_assets
  end

  def teardown
    teardown_assets
  end

  def test_corrupt_file_upload
    @asset = Asset.create_from_params uploaded_data: upload_data('corrupt.jpg')
    @asset.generate_thumbnails
    @asset.thumbnails.each do |thumb|
      refute thumb.ok?, format('thumbnail "%s" should have failed for corrupt file', thumb.name)
      assert thumb.private_filename, format('thumbnail "%s" should exist', thumb.name)
    end
  end
end
