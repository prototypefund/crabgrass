require 'test_helper'

class Page::CommentsTest < ActiveSupport::TestCase
  def setup
    @user = users(:blue)
    # we need a wiki page because discussion pages store
    # comments in the page_terms body rather than as comments.
    @page = @user.pages.where(type: 'WikiPage').last
  end

  def test_posting_comment
    text = Faker::Lorem.paragraph
    @page.add_post(@user, body: text)
    assert @page.discussion.present?
    assert_equal 1, @page.discussion.posts_count
    assert_includes Page::Terms.where(page: @page).first.comments,
      text
  end

  def test_posting_comment_with_emoji
    @page.add_post(@user, body: '😀')
    assert @page.discussion.present?
    assert_equal 1, @page.discussion.posts_count
    assert @page.page_terms.comments.include? '😀'
  end

end
