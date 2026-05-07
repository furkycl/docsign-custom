# frozen_string_literal: true

# DOCSIGN-CUSTOM: brand factory for tests
FactoryBot.define do
  factory :brand do
    account
    sequence(:slug) { |n| "brand_#{n}" }
    sequence(:name) { |n| "Brand #{n}" }
    logo_path { 'brands/academia_united.svg' }
    primary_color { '#1E40AF' }
    active { true }

    # Use _test suffix on slug to avoid clash with the 3 brands that
    # Account#after_create auto-seeds (academia_united, linguland, topstudy).
    # Names stay clean for assertions like `include('Linguland')`.
    trait :linguland do
      sequence(:slug) { |n| "linguland_test_#{n}" }
      name { 'Linguland' }
      logo_path { 'brands/linguland.svg' }
      primary_color { '#15803D' }
      email_from_name { 'Linguland' }
      email_from_address { 'noreply@linguland.test' }
    end

    trait :topstudy do
      sequence(:slug) { |n| "topstudy_test_#{n}" }
      name { 'Topstudy' }
      logo_path { 'brands/topstudy.svg' }
      primary_color { '#EA580C' }
    end
  end
end
