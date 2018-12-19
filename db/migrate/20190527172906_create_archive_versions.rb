class CreateArchiveVersions < ActiveRecord::Migration[4.2]
  def self.up
    Group::Archive.create_versioned_table
  end

  def self.down
    Group::Archive.drop_versioned_table
  end
end
