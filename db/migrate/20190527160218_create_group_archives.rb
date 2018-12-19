class CreateGroupArchives < ActiveRecord::Migration[4.2]
  def change
    create_table :group_archives do |t|
      t.string :filename
      t.string :state, limit: 10, default: 'pending'
      t.integer :version, default: 0
      t.integer :created_by_id
      t.integer :updated_by_id
      t.boolean :singlepage
      t.belongs_to :group, index: true
      t.timestamps null: false
    end
  end
end