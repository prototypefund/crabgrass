class UpdateCastleGateKeysHolderCodeSize < ActiveRecord::Migration[4.2]
  def up
    change_table "castle_gates_keys" do |t|
      t.change "holder_code", :integer, limit: 8
    end
  end

  def down
    change_table "castle_gates_keys" do |t|
      t.change "holder_code", :integer, limit: 4
    end
  end
end
