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
    a = Group::Archive.new group: @group, user: @user
    assert_equal @user, a.user
    assert_equal @group, a.group
  end

  def test_missing_group_param
    a = Group::Archive.new user: @user
    assert !a.valid?, 'archive without group should be invalid'
    assert_equal false, a.process
  end

  # FIXME: not used anymore because zip creation is not triggered by
  # new but by GroupArchiveJob's process method. We have to test the job instead.
  def archive_file_exists
    a = Group::Archive.new group: @group, user: @user
    assert_equal true, File.file?(zip_archive_file(@group))
  end

  # FIXME: same here
  def zip_archive
    Group::Archive.new group: @group, user: @user
    Zip::File.open(zip_archive_file(@group)) do |zip_file|
      assert_true zip_file.collect(&:name).include?('recent_group/test-wiki+210.html')
      zip_file.each do |entry|
        if entry.name == 'recent_group/test-wiki+210.html'
          content = entry.get_input_stream.read
          assert_equal true, content.include?('<h1>test wiki</h1>')
        end
      end
    end
  end
end
