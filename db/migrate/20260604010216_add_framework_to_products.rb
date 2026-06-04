class AddFrameworkToProducts < ActiveRecord::Migration[7.2]
  def change
    # Nullable: a nil framework is treated as the default (Tech) in the app.
    add_reference :products, :framework, null: true, foreign_key: true
  end
end
