class DropScores < ActiveRecord::Migration[7.2]
  def up
    drop_table :scores
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
