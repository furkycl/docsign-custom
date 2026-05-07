# frozen_string_literal: true

# == Schema Information
#
# Table name: brands
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE), not null
#  email_from_address  :string
#  email_from_name     :string
#  email_intro_text    :text
#  logo_path           :string           not null
#  name                :string           not null
#  primary_color       :string           default("#1F2937"), not null
#  slug                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_brands_on_account_id            (account_id)
#  index_brands_on_account_id_and_slug   (account_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Brand < ApplicationRecord
  # DOCSIGN-CUSTOM: default brand catalog seeded on every new Account (see Account#seed_default_brands)
  DEFAULT_SEEDS = [
    {
      slug: 'academia_united',
      name: 'Academia United',
      logo_path: 'brands/academia_united.svg',
      primary_color: '#1E40AF',
      email_from_name: 'Academia United',
      email_intro_text: 'Size Academia United tarafından imzalamanız gereken bir belge gönderildi.'
    },
    {
      slug: 'linguland',
      name: 'Linguland',
      logo_path: 'brands/linguland.svg',
      primary_color: '#15803D',
      email_from_name: 'Linguland',
      email_intro_text: 'Size Linguland tarafından imzalamanız gereken bir belge gönderildi.'
    },
    {
      slug: 'topstudy',
      name: 'Topstudy',
      logo_path: 'brands/topstudy.svg',
      primary_color: '#EA580C',
      email_from_name: 'Topstudy',
      email_intro_text: 'Size Topstudy tarafından imzalamanız gereken bir belge gönderildi.'
    }
  ].freeze

  belongs_to :account
  has_many :submissions, dependent: :nullify

  validates :slug, presence: true,
                   uniqueness: { scope: :account_id },
                   format: { with: /\A[a-z0-9_\-]+\z/, message: 'only lowercase letters, digits, dashes, underscores' }
  validates :name, presence: true
  validates :logo_path, presence: true
  validates :primary_color, format: { with: /\A#(?:[0-9a-fA-F]{3}){1,2}\z/ }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  # Returns the asset path the mailer/views can use directly with image_tag.
  # Defaults to a safe placeholder if nothing is configured.
  def logo_asset_path
    logo_path.presence || 'brands/default.svg'
  end

  # The "From" header used by branded mailers. Falls back to account defaults
  # so existing accounts without a brand selection keep working.
  def from_header
    return nil if email_from_address.blank?

    name_part = (email_from_name.presence || name)
    %("#{name_part}" <#{email_from_address}>)
  end

  # The intro paragraph shown at the top of the invitation email body.
  # If no override is set we use a generic Turkish text with the brand's name interpolated.
  def email_intro_for_locale(locale = I18n.locale)
    return email_intro_text if email_intro_text.present?

    I18n.t('brands.default_email_intro',
           brand: name,
           locale: locale,
           default: "Size #{name} tarafından imzalamanız gereken bir belge gönderildi.")
  end
end
