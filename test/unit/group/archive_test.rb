require 'test_helper'
require 'zip'

class ArchiveTest < ActiveSupport::TestCase
  def setup
    @group = groups(:recent_group)
    @user = users(:blue)
  end

  # FIXME: use paths defined in model
  def singlepage_zip(group)
    File.join(ASSET_PRIVATE_STORAGE, 'archives', group.id.to_s, "singlepage_#{group.name}.zip")
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

  # TODO: test zip creation
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
    assert_equal true, File.file?(singlepage_zip(@group))
  end

  def test_zip_archive
    a = Group::Archive.create! group: @group, created_by: @user
    a.process
    Zip::File.open(singlepage_zip(@group)) do |zip_file|
      zip_file.collect(&:name).include?('recent_group/test-wiki+210.html')
      zip_file.each do |entry|
        if entry.name == 'recent_group/test-wiki+210.html'
          content = entry.get_input_stream.read
          assert_equal true, content.include?('<h1>test wiki</h1>')
        end
      end
    end
  end
end
