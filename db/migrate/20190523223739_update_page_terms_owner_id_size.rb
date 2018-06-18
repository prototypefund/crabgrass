class UpdatePageTermsOwnerIdSize < ActiveRecord::Migration[4.2]
  def up
    change_table "page_terms" do |t|
      t.change "owner_id", :integer, limit: 8
    end
  end

  def down
    change_table "page_terms" do |t|
      t.change "owner_id", :integer, limit: 4
    end
  end
end
