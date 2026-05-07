# frozen_string_literal: true

class AddBrandIdToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_reference :submissions, :brand, null: true, foreign_key: true, index: true
  end
end
