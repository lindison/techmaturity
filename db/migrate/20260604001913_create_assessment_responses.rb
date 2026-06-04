class CreateAssessmentResponses < ActiveRecord::Migration[7.2]
  def change
    create_table :assessment_responses do |t|
      t.references :assessment, null: false, foreign_key: true
      t.references :capability, null: false, foreign_key: true
      t.integer :value

      t.timestamps
    end
    add_index :assessment_responses, [:assessment_id, :capability_id], unique: true
  end
end
