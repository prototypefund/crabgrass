class CreateGroupArchives < ActiveRecord::Migration[4.2]
  def change
    create_table :group_archives do |t|
      t.string :filename
      t.integer :state, default: 0
      t.integer :created_by_id
      t.belongs_to :group, index: true
      t.string :excluded_asset_ids
      t.timestamps null: false
    end
  end
end
