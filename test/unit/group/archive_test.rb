require 'test_helper'
require 'zip'

class ArchiveTest < ActiveSupport::TestCase

  def setup
    @group = groups(:recent_group)
    @user = users(:blue)
    Group:: Archive.delete_all
    FileUtils.rm_r(Group::Archive.archive_dir) if File.directory?(Group::Archive.archive_dir)
  end

  def teardown
    FileUtils.rm_r(Group::Archive.archive_dir) if File.directory?(Group::Archive.archive_dir)
  end

  def test_regex
    name = 'animals+mycommittee'
    name = name.sub('+', '\\\+')
    html = '<a href="/animals+mycommittee/wiki-page-with-comments">wiki page with comments</a></p><a href="/animals+bla/wiki-page-with-comments">wiki page with comments</a></p>'
    regex = /href=\"(\/(#{name}\/))([^.\"]*)\"+/
    regex = /href=\"((\/#{name}\/)([^.\"]*))\"+/
    result = html.match(regex)
    assert result
    assert_equal "/animals+mycommittee/wiki-page-with-comments", $1
    assert_equal "/animals+mycommittee/", $2
    assert_equal "wiki-page-with-comments", $3
  end

  def test_create_archive
    a = Group::Archive.find_or_create(group: @group, user: @user)
    assert_equal 'success', a.state
    assert a.created_by_id, @user.id
    assert @group.id, a.group.id
  end

  def test_missing_group_param
    g = Group::Archive.create(user: @user)
    assert !g.valid?, 'archive without group should not be valid'
  end

  def test_initial_version
    a = Group::Archive.find_or_create(group: @group, user: @user)
    assert_equal 'success', a.state
    assert_equal 1, a.version
  end

  def test_archive_file_exists
    a = Group::Archive.create group: @group, user: @user
    assert_equal 'success', a.state
    assert true, File.file?(a.stored_zip_file)
  end

  def test_zip_archive
    a = Group::Archive.find_or_create(group: @group, user: @user)
    assert_equal 'success', a.state
    Zip::File.open(a.stored_zip_file) do |zip_file|
      assert true, zip_file.collect(&:name).include?("recent_group/test-wiki+210.html")
      zip_file.each do |entry|
        if entry.name == "recent_group/test-wiki+210.html"
          content = entry.get_input_stream.read
          assert true, content.include?("<h1>test wiki</h1>")
        end
      end
    end
  end

end


