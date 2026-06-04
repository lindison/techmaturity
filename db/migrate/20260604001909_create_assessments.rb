class CreateAssessments < ActiveRecord::Migration[7.2]
  def change
    create_table :assessments do |t|
      t.references :product, null: false, foreign_key: true
      t.references :framework, null: false, foreign_key: true
      t.boolean :latest
      t.text :comment

      t.timestamps
    end
  end
end
