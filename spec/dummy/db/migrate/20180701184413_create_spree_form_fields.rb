class CreateSpreeFormFields < ActiveRecord::Migration
  def change
    create_table :spree_form_fields do |t|
      t.integer :form_id, null: false
      t.string  :field_type, null: false
      t.boolean :required, default: false, null: false
      t.integer :num_columns, default: 1, null: false
      t.string  :label
      t.text    :value
      t.integer :position
      t.string  :css_class
    end

    add_index :spree_form_fields, :form_id
  end
end
