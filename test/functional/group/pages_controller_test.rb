require 'test_helper'

class Group::PagesControllerTest < ActionController::TestCase
  def test_index
    user = users(:penguin)
    group = groups(:rainbow)
    login_as user
    get :index, params: { group_id: group }
    assert_response :success
    assert assigns('pages').any?
    assert assigns('pages').all? { |p| p.public? || user.may?(:view, p) }
  end
end
