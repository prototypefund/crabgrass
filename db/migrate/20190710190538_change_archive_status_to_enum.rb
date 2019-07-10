class ChangeArchiveStatusToEnum < ActiveRecord::Migration[5.2]
  def up
    change_column :group_archives, :state, :integer, default: 0
  end

  def down
    change_column :group_archives, :state, :string, default: 'pending'
  end


end
