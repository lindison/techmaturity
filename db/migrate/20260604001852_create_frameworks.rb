class CreateFrameworks < ActiveRecord::Migration[7.2]
  def change
    create_table :frameworks do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.integer :position

      t.timestamps
    end
    add_index :frameworks, :slug, unique: true
  end
end
