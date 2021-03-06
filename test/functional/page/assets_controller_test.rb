require 'test_helper'

class Page::AssetsControllerTest < ActionController::TestCase
  def setup
    @page = FactoryBot.create :page, created_by: users(:blue)
    @asset = @page.add_attachment! uploaded_data: upload_data('photo.jpg')
    users(:blue).updated(@page)
    login_as :blue
  end

  def test_index
    get :index, params: { page_id: @page.id }
    assert_response :success
  end

  def test_may_create
    @page.add(groups(:rainbow), access: :edit).save!
    @page.save!
    login_as :red
    assert_difference '@page.assets.count' do
      post :create, params: { page_id: @page.id, asset: { uploaded_data: upload_data("photo.jpg") } }, xhr: true
    end
    assert_equal @page.id, Asset.last.page_id
  end

  def test_may_not_create
    @page.add(groups(:rainbow), access: :view).save!
    @page.save!
    login_as :red
    assert_no_difference '@page.assets.count' do
      post :create, params: { page_id: @page.id, asset: { uploaded_data: upload_data('photo.jpg') } }
      assert_permission_denied
    end
  end
end
