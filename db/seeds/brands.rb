# frozen_string_literal: true

# DOCSIGN-CUSTOM: backfill brands for existing accounts.
# New accounts get brands automatically via Account#seed_default_brands callback.
# This script is idempotent — safe to re-run on already-seeded accounts.
#
# Run with:
#   bundle exec rails runner db/seeds/brands.rb

Account.find_each do |account|
  Brand::DEFAULT_SEEDS.each do |attrs|
    brand = account.brands.find_or_initialize_by(slug: attrs[:slug])
    brand.assign_attributes(attrs)
    brand.save!
    puts "Brand seeded: #{account.name} / #{brand.name}"
  end
end
