class CreateCapabilities < ActiveRecord::Migration[7.2]
  def change
    create_table :capabilities do |t|
      t.references :dimension, null: false, foreign_key: true
      t.string :name
      t.string :slug
      t.integer :position
      t.integer :min_level

      t.timestamps
    end
    add_index :capabilities, [:dimension_id, :slug], unique: true
  end
end
