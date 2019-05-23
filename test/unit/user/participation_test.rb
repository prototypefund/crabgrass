require 'test_helper'

class User::ParticipationTest < ActiveSupport::TestCase
  def setup
    Time.zone = ActiveSupport::TimeZone['Pacific Time (US & Canada)']
  end

  def test_associations
    assert check_associations(User::Participation)
  end

  def test_name_changed
    u = users(:orange)
    p = Page.create title: 'hello', user: u
    assert_predicate p, :valid?
    u.updated(p)
    p.save
    assert_equal 'orange', p.updated_by_login,
      'cached updated_by_login should be "orange"'
    u.login = 'banana'
    assert u.save
    p.reload
    assert_equal 'banana', u.reload.login
    assert_equal 'banana', p.updated_by_login,
      'cached updated_by_login should be "banana"'
  end

  def test_updated
    g = groups(:animals)
    u = users(:blue)
    page = Page.create title: 'hello', owner: g
    assert_difference format('Page.find(%d).contributors_count', page.id) do
      u.updated(page)
      page.save
    end
  end

  def test_participations
    user = users(:blue)
    group = groups(:rainbow)

    page = Page.create title: 'zebra'

    page.add(user, star: true, access: :admin)
    page.add(group, access: :admin)
    page.save! # save required after .add()

    assert user.may?(:admin, page),
      'user must be able to admin page'
    assert page.user_participations.find_by_user_id(user.id).star,
      'user association attributes must be set'
    assert_includes user.pages, page,
      'user must have an association with page'
    assert_includes group.pages, page,
      'group must have an association with page'

    # page.users and page.groups are not updated until a reload
    page.reload
    assert_includes page.users, user,
      'page must have an association with user'
    assert_includes page.groups, group,
      'page must have an association with group'

    page.remove(user)
    page.remove(group)
    page.save!
    assert !page.users.include?(user),
      'page must NOT have an association with user'
    assert !page.groups.include?(group),
      'page must NOT have an association with group'
  end

  def test_user_destroyed
    user = users(:blue)
    page = Page.create! title: 'boing'
    page.add(user)
    page.save!
    user.destroy
    assert page.user_participations.reload.none?
  end

  def test_ids_update
    user = users(:blue)
    page = Page.create! title: 'robot tea party', user: user
    assert_equal [user.id], page.user_ids
    page.remove(user)
    page.save!
    assert_equal [], page.user_ids
  end

  def test_admin_page_without_a_particular_participation
    user = users(:blue)
    group = groups(:rainbow)

    page = Page.create! title: 'robot tea party', user: user
    assert user.may?(:admin, page)

    upart = nil
    gpart = nil
    assert_no_difference 'User::Participation.count' do
      upart = page.participation_for_user(user)
      assert !user.may_admin_page_without?(page, upart),
        'cannot remove upart and still have access'

      gpart = page.add group, access: :admin
      gpart.save!

      assert user.may_admin_page_without?(page, gpart),
        'can remove gpart'
      assert user.may_admin_page_without?(page, upart),
        'can remove upart'
    end

    page.remove(user)
    page.reload

    assert !user.may_admin_page_without?(page, gpart),
      'cannot remove gpart'
  end

  def test_stars_update
    user = users(:blue)
    page = Page.create! title: 'the moon and all the stars'

    participation = page.add(user, star: true)
    participation.save!
    assert_equal 1, page.stars_count
    assert_equal 1, page.reload.stars_count

    participation = page.add(user, star: false)
    participation.save!
    assert_equal 0, page.stars_count
    assert_equal 0, page.reload.stars_count
  end
end
