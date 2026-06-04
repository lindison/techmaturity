class CreateRepoScans < ActiveRecord::Migration[7.2]
  def change
    create_table :repo_scans do |t|
      t.references :product, null: false, foreign_key: true
      t.string  :repo,     null: false
      t.string  :status,   null: false, default: "pending"
      t.integer :progress, null: false, default: 0
      t.text    :error
      t.jsonb   :result,   null: false, default: {}

      t.timestamps
    end
    add_index :repo_scans, [:product_id, :created_at]
  end
end
