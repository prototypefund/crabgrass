require 'test_helper'

class PostPolicyTest < ActiveSupport::TestCase

  def test_admin_may_delete_visitor_comment
    admin = users(:blue)
    visitor = users(:penguin)
    page = FactoryBot.create :page, created_by: admin,
      owner: groups(:rainbow),
      public: true
    visitor_comment = page.add_post visitor,
      body: 'test comment by penguin on public page'
    policy = Pundit.policy!(admin, visitor_comment)
    assert policy.destroy?
  end

end
