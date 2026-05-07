# frozen_string_literal: true

require 'rails_helper'

# DOCSIGN-CUSTOM: brand-aware invitation email behavior
RSpec.describe SubmitterMailer do
  # Mailer tests don't need real PDF processing — stub it out so tests don't depend on libpdfium
  before do
    allow(Templates::ProcessDocument).to receive(:call) { |attachment, _data| attachment }
  end

  # Use only_field_types to avoid spinning up file/payment fields (faster)
  let(:account) { create(:account) }
  let(:author) { create(:user, account: account) }

  describe '#invitation_email with brand' do
    let(:template) { create(:template, account:, author:, only_field_types: %w[text signature]) }
    let(:brand) { create(:brand, :linguland, account:) }
    let(:submission) do
      create(:submission, :with_submitters, template:, brand:, created_by_user: author)
    end
    let(:submitter) { submission.submitters.first }

    it 'renders the brand name in the body' do
      mail = described_class.invitation_email(submitter)
      expect(mail.body.encoded).to include('Linguland')
    end

    it 'uses the brand primary color in the inline button style' do
      mail = described_class.invitation_email(submitter)
      expect(mail.body.encoded).to include('#15803D')
    end

    it 'uses the brand intro text (Turkish default)' do
      mail = described_class.invitation_email(submitter)
      expect(mail.body.encoded).to include('Linguland tarafından')
    end

    it 'sets the From header from the brand when configured' do
      mail = described_class.invitation_email(submitter)
      expect(mail.from).to include('noreply@linguland.test')
    end
  end

  describe '#invitation_email without brand (fallback)' do
    let(:template) { create(:template, account:, author:, only_field_types: %w[text signature]) }
    let(:submission) do
      create(:submission, :with_submitters, template:, brand: nil, created_by_user: author)
    end
    let(:submitter) { submission.submitters.first }

    it 'does NOT render any brand-specific markup' do
      mail = described_class.invitation_email(submitter)
      expect(mail.body.encoded).not_to include('#15803D')
      expect(mail.body.encoded).not_to include('Linguland')
    end

    it 'still renders the generic invitation' do
      mail = described_class.invitation_email(submitter)
      expect(mail.body.encoded).to match(/hi.there/i).or include(account.name)
    end
  end
end
