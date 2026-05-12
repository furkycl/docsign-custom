# frozen_string_literal: true

# DOCSIGN-CUSTOM: Marka logosunun e-postada gösterildiği container'ın
# arka plan rengi. primary_color buton/link rengi için, logo_background_color
# logonun görünür olduğu BG için ayrı kullanılır.
class AddLogoBackgroundColorToBrands < ActiveRecord::Migration[8.1]
  def change
    add_column :brands, :logo_background_color, :string,
               null: false, default: '#FFFFFF',
               comment: 'E-postada logo container BG rengi (hex)'
  end
end
