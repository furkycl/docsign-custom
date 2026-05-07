# frozen_string_literal: true

# Seeds the three default brands for every Account. Idempotent — safe to re-run.
#
# Run with:
#   bundle exec rails runner db/seeds/brands.rb
#
# Or invoke from db/seeds.rb so it runs as part of `rails db:seed`.

DEFAULT_BRANDS = [
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

Account.find_each do |account|
  DEFAULT_BRANDS.each do |attrs|
    brand = account.brands.find_or_initialize_by(slug: attrs[:slug])
    brand.assign_attributes(attrs)
    brand.save!
    puts "Brand seeded: #{account.name} / #{brand.name}"
  end
end
