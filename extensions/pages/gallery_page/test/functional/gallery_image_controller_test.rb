require 'test_helper'

class GalleryImageControllerTest < ActionController::TestCase
  def setup
    # let's make some gallery
    # there are no galleries in fixtures yet.
    #
    @gallery = Gallery.create! title: 'gimme pictures', user: users(:blue)
    @asset = @gallery.add_image! uploaded_data: upload_data('photo.jpg')
    users(:blue).updated(@gallery)
    @gallery.save!
    @asset.save!
  end

  def test_show
    login_as :blue
    assert @asset.id, 'image should not be nil'
    get :show, params: { id: @asset.id, page_id: @gallery.id }, xhr: true
    assert_response :success
    assert assigns(:showing)
  end

  def test_show_not_found
    login_as :blue
    assert @asset.id, 'image should not be nil'
    get :show, params: { id: 111, page_id: @gallery.id }, xhr: true
    assert_not assigns(:showing)
    assert_response 404
  end

  def test_show_as_html
    login_as :blue
    assert @asset.id, 'image should not be nil'
    get :show, params: { id: @asset.id, page_id: @gallery.id }
    assert_response :success
    assert assigns(:showing)
  end

  def test_may_not_show
    login_as :red
    get :show, params: { id: @asset.id, page_id: @gallery.id }, xhr: true
    assert_response 404
  end

  def test_may_show
    @gallery.add(groups(:rainbow), access: :view).save!
    @gallery.save!
    login_as :red
    get :show, params: { id: @asset.id, page_id: @gallery.id }, xhr: true
    assert_response :success
    assert assigns(:showing)
  end

  def test_sort
    # we need two images
    @asset2 = Asset.create_from_params(uploaded_data: upload_data('photo.jpg')) do |asset|
      asset.parent_page = @gallery
    end
    @gallery.add_image!(@asset2, users(:blue))
    @asset2.save!
    login_as :blue
    post :sort, params: { page_id: @gallery.id, assets_list: [@asset2.id, @asset.id] }, xhr: true
    assert_response :success
    assert_equal [@asset2.id, @asset.id], @gallery.reload.images.map(&:id)
  end
end
