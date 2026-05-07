# frozen_string_literal: true

class CreateBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :brands do |t|
      t.references :account, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :name, null: false
      t.string :logo_path, null: false
      t.string :primary_color, null: false, default: '#1F2937'
      t.string :email_from_name
      t.string :email_from_address
      t.text :email_intro_text
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :brands, %i[account_id slug], unique: true
  end
end
