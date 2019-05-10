# encoding: utf-8

require 'test_helper'

class Page::TermsTest < ActiveSupport::TestCase
  def test_create
    user = users(:blue)
    page = DiscussionPage.create! title: 'hi', user: user
    assert_equal Page.access_ids_for(user_ids: [user.id]).first,
                 page.page_terms.access_ids
    assert page.page_terms.delta
  end

  def test_destroy
    user = users(:blue)
    page = DiscussionPage.create! title: 'hi', user: user
    assert page.reload_page_terms
    page.destroy
    assert_nil page.reload_page_terms
  end

  def test_tagging_with_odd_characters
    name = 'test page'
    page = FactoryBot.create :wiki_page,
                              title: name.titleize,
                              name: name.nameize,
                              tag_list: '^&#, +, **, %, ə'

    '^&#, +, **, %, ə'.split(', ').each do |char|
      found = Page.find_by_path(['tag', char]).first
      assert found, format('there should be a page tagged %s', char)
      assert_equal page.id, found.id,
        format('the page ids should match for tag %s', char)
    end
  end
end
