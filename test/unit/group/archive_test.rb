require 'test_helper'
require 'zip'

class ArchiveTest < ActiveSupport::TestCase
  def setup
    @group = groups(:recent_group)
    @user = users(:blue)
  end

  def test_regex
    name = 'animals+mycommittee'
    name = name.sub('+', '\\\+')
    html = '<a href="/animals+mycommittee/wiki-page-with-comments">wiki page with comments</a></p><a href="/animals+bla/wiki-page-with-comments">wiki page with comments</a></p>'
    regex = %r{href=\"((\/#{name}\/)([^.\"]*))\"+}
    result = html.match(regex)
    assert result
    assert_equal '/animals+mycommittee/wiki-page-with-comments', Regexp.last_match(1)
    assert_equal '/animals+mycommittee/', Regexp.last_match(2)
    assert_equal 'wiki-page-with-comments', Regexp.last_match(3)
  end

  def test_create_archive
    a = Group::Archive.create! group: @group, created_by: @user
    assert_equal @user.id, a.created_by_id
    assert_equal @group, a.group
    assert_equal 'pending', a.state
  end

  def test_missing_group_param
    assert_raises ActiveRecord::RecordInvalid do
      Group::Archive.create! created_by_id: @user.id
    end
  end

  def test_archive_file_exists
    a = Group::Archive.create! group: @group, created_by: @user
    a.process
    assert_equal true, File.file?(a.zipfile)
  end

  def test_zip_archive
    a = Group::Archive.create! group: @group, created_by: @user
    a.process
    Zip::File.open(a.zipfile) do |zip_file|
      entry = zip_file.detect{|file| file.name == 'recent_group/test-wiki+210.html'}
      assert entry, "zipfile should include 'recent_group/test-wiki+210.html'"
      content = entry.get_input_stream.read
      assert_includes content, "<h1 id='test-wiki+210'>test wiki</h1>"
    end
  end
end
