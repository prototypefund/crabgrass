require 'test_helper'
require 'zip'

class ArchiveTest < ActiveSupport::TestCase
  def setup
    @group = groups(:recent_group)
    @user = users(:blue)
  end

  # FIXME: use paths defined in model
  def zip_archive_file(group)
    File.join(ASSET_PRIVATE_STORAGE, 'archives', group.id.to_s, "#{group.name}.zip")
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
    a = Group::Archive.create! group: @group, created_by_id: @user.id
    #    assert_equal 'success', a.state
    assert a.created_by_id, @user.id
    assert @group.id, a.group.id
  end

  def test_missing_group_param
    assert_raises ActiveRecord::RecordInvalid do
      Group::Archive.create! created_by_id: @user.id
    end
  end

  def test_archive_file_exists
    Group::Archive.create! group: @group, created_by_id: @user.id
    # assert_equal 'success', a.state
    assert true, File.file?(zip_archive_file(@group))
  end

  def test_zip_archive
    Group::Archive.create! group: @group, created_by_id: @user.id
    # assert_equal 'success', a.state
    Zip::File.open(zip_archive_file(@group)) do |zip_file|
      assert true, zip_file.collect(&:name).include?('recent_group/test-wiki+210.html')
      zip_file.each do |entry|
        if entry.name == 'recent_group/test-wiki+210.html'
          content = entry.get_input_stream.read
          assert true, content.include?('<h1>test wiki</h1>')
        end
      end
    end
  end
end
