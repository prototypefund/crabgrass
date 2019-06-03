# encoding: utf-8

require 'javascript_integration_test'

class TagSuggestionTest < JavascriptIntegrationTest

  def test_tag_from_user_suggestion
    create_user_page tag_list: %w[summer winter],
      created_by: users(:dolphin)
    tag_me = create_user_page created_by: users(:dolphin)
    login users(:dolphin)
    visit '/dolphin/' + tag_me.name_url
    tag_page_from_suggestion 'summer'
    assert_page_tags 'summer'
  end

  def test_tag_from_group_suggestion_as_non_member
    create_group_page tag_list: ['rainbowsecret']
    tag_me = create_group_page tag_list: ['nosecret']
    tag_me.add(users(:dolphin), access: :edit)
    tag_me.save!
    login users(:dolphin)
    visit '/rainbow/' + tag_me.name_url
    assert_page_tags 'nosecret'
    assert_no_content 'rainbowsecret'
  end

  def test_tag_from_group_suggestion_as_member
    create_group_page tag_list: ['rainbowsecret']
    tag_me = create_group_page
    login users(:red)
    visit '/rainbow/' + tag_me.name_url
    tag_page_from_suggestion 'rainbowsecret'
    assert_page_tags 'rainbowsecret'
    assert tag_me.tags.map(&:name).include? 'rainbowsecret'
  end

  def test_tag_suggested_via_group_participations
    tag_source_page = create_user_page tag_list: ['sharedtag']
    tag_source_page.add [users(:dolphin), groups(:rainbow)]
    tag_source_page.save!
    tag_me = create_user_page
    tag_me.add [users(:dolphin), groups(:rainbow)], access: :edit
    tag_me.save!
    login users(:dolphin)
    visit '/rainbow/' + tag_me.name_url
    tag_page_from_suggestion 'sharedtag'
    assert_page_tags 'sharedtag'
    assert tag_me.tags.map(&:name).include? 'sharedtag'
  end

  def create_group_page(options = {})
    attrs = options.reverse_merge created_by: users(:blue),
      owner: groups(:rainbow)
    FactoryBot.create :page, attrs
  end

  def create_user_page(options = {})
    attrs = options.reverse_merge created_by: users(:blue)
    FactoryBot.create :page, attrs
  end
end
