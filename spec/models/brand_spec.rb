# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Brand do
  let(:account) { create(:account) }

  describe 'validations' do
    subject(:brand) do
      described_class.new(
        account: account,
        slug: 'academia_united',
        name: 'Academia United',
        logo_path: 'brands/academia_united.svg',
        primary_color: '#1E40AF'
      )
    end

    it { expect(brand).to be_valid }

    it 'requires a slug' do
      brand.slug = nil
      expect(brand).not_to be_valid
      expect(brand.errors[:slug]).to be_present
    end

    it 'rejects slugs with spaces or uppercase' do
      brand.slug = 'Academia United'
      expect(brand).not_to be_valid
    end

    it 'enforces unique slug per account' do
      brand.save!
      duplicate = described_class.new(
        account: account,
        slug: 'academia_united',
        name: 'Other',
        logo_path: 'brands/x.svg',
        primary_color: '#000000'
      )
      expect(duplicate).not_to be_valid
    end

    it 'allows the same slug across different accounts' do
      brand.save!
      other_account = create(:account)
      duplicate = described_class.new(
        account: other_account,
        slug: 'academia_united',
        name: 'Academia United',
        logo_path: 'brands/academia_united.svg',
        primary_color: '#1E40AF'
      )
      expect(duplicate).to be_valid
    end

    it 'requires a valid hex color' do
      brand.primary_color = 'blue'
      expect(brand).not_to be_valid
    end
  end

  describe '#from_header' do
    it 'returns nil when email_from_address is blank' do
      brand = described_class.new(account: account, name: 'Foo', email_from_address: nil)
      expect(brand.from_header).to be_nil
    end

    it 'uses email_from_name when provided' do
      brand = described_class.new(
        account: account, name: 'Foo',
        email_from_name: 'Custom', email_from_address: 'noreply@example.com'
      )
      expect(brand.from_header).to eq('"Custom" <noreply@example.com>')
    end

    it 'falls back to brand name when email_from_name is blank' do
      brand = described_class.new(
        account: account, name: 'Foo',
        email_from_name: nil, email_from_address: 'noreply@example.com'
      )
      expect(brand.from_header).to eq('"Foo" <noreply@example.com>')
    end
  end

  describe '#email_intro_for_locale' do
    it 'returns the configured intro text when present' do
      brand = described_class.new(account: account, name: 'Linguland', email_intro_text: 'Custom intro')
      expect(brand.email_intro_for_locale).to eq('Custom intro')
    end

    it 'returns a default Turkish intro when intro text is blank' do
      brand = described_class.new(account: account, name: 'Linguland', email_intro_text: nil)
      expect(brand.email_intro_for_locale).to include('Linguland')
    end
  end
end
