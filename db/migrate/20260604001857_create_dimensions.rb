class CreateDimensions < ActiveRecord::Migration[7.2]
  def change
    create_table :dimensions do |t|
      t.references :framework, null: false, foreign_key: true
      t.string :name
      t.string :slug
      t.integer :position
      t.string :color

      t.timestamps
    end
    add_index :dimensions, [:framework_id, :slug], unique: true
  end
end
