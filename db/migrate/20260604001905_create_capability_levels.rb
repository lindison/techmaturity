class CreateCapabilityLevels < ActiveRecord::Migration[7.2]
  def change
    create_table :capability_levels do |t|
      t.references :capability, null: false, foreign_key: true
      t.integer :value
      t.text :description
      t.text :formatted_description

      t.timestamps
    end
    add_index :capability_levels, [:capability_id, :value], unique: true
  end
end
