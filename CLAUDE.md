# docsign-custom — DocuSeal Çoklu Marka Customization

İç araç olarak self-host edilen, **DocuSeal** (Ruby on Rails) tabanlı, 3 markalı (Academia United, Linguland, Topstudy) bir doküman imza sistemi.

Upstream: https://github.com/docusealco/docuseal
Bu fork: https://github.com/furkycl/docsign-custom

---

## Mimari

DocuSeal'e sıfırdan yazılan tek katman: **Brand modülü**. Onun dışında her şey upstream'den olduğu gibi geliyor.

- `Brand` modeli (`app/models/brand.rb`) — `belongs_to :account`, her hesabın 3 markası var (slug ile)
- `submissions.brand_id` (nullable FK) — gönderim sırasında seçilen marka
- Mailer brand-aware (`SubmitterMailer` `@brand` context'i kullanır)
- Şablon gönderme UI'ında brand dropdown
- Status badge renkleri brand renginden bağımsız sabit (gri = Gönderildi, yeşil = İmzalandı)

### Customization branch stratejisi

- `main` = upstream master + bizim customization'lar
- Yeni dosyalar (Brand model, migrations, seeds, brand assets) merge conflict çıkarmaz
- Modifiye dosyalar (`SubmitterMailer`, `submissions_controller`, `invite_form.vue`) upstream güncellenince elle merge edilir
- Upstream çekme: `git fetch upstream && git merge upstream/master`

---

## 16 Müşteri Gereksinimi → Karşılama Özeti

| # | Gereksinim | Durum | Dokunulan |
|---|---|---|---|
| 1 | Şablon listesi | ✅ Hazır | `templates_dashboard/index` |
| 2 | "Yeni Şablon Yükle" + PDF | ✅ Hazır | `templates_uploads_controller` |
| 3 | Marka dropdown (3 brand) | 🔧 Custom | `Brand` model + `invite_form.vue` |
| 4 | Marka + email + gönder | 🔧 Custom | `SubmissionsController#create` + view |
| 5 | Brand-aware email + logo | 🔧 Custom | `SubmitterMailer` + `invitation_email.html.erb` |
| 6 | Üyeliksiz signer linki | ✅ Hazır | `start_form#show` |
| 7 | Sticky "İmzala" butonu | ✅ Hazır | `submission_form.html.erb` |
| 8 | Drawn + upload signature | ✅ Hazır | `submit_form_draw_signature` |
| 9 | Mobil scroll lock | 🩹 Patch | `submit_form_draw_signature/show` body lock |
| 10 | Temizle/Kaydet butonları | ✅ Hazır | aynı view |
| 11 | Teşekkür sayfası | ✅ Hazır | `submit_form/completed` |
| 12 | Admin panel tablosu | ✅ Hazır | `submissions_dashboard/index` |
| 13 | Renkli status etiketleri | 🩹 Patch | `templates/_submission` badge sınıfları |
| 14 | İmzalı PDF + kilitli imza | ✅ Hazır | HexaPDF flatten |
| 15 | Audit trail (tarih+saat+IP) | ✅ Hazır | `lib/submissions/generate_audit_trail.rb` |
| 16 | Tarih bazlı arşiv | ✅ Hazır | `submissions_archived_controller` |

---

## Lokal Geliştirme

```bash
# Bağımlılıklar
bundle install
yarn install

# DB
bin/rails db:create db:migrate
bundle exec rails runner db/seeds/brands.rb

# Sunucu (Procfile.dev: rails + sidekiq + js bundler)
bin/dev
```

Erişim: http://localhost:3000

### Test

```bash
bundle exec rspec spec/models/brand_spec.rb
bundle exec rspec spec/  # tam suite
```

### Docker (production-benzeri)

```bash
docker compose up
```

---

## Dosya Konumları

```
app/
  models/brand.rb                                 # Brand modeli
  assets/images/brands/                           # Marka logoları (SVG)
    academia_united.svg
    linguland.svg
    topstudy.svg
  mailers/submitter_mailer.rb                     # Brand-aware (modifiye)
  views/submitter_mailer/invitation_email.html.erb # Brand logo + metin (modifiye)
  controllers/submissions_controller.rb           # brand_id param (modifiye)
  javascript/submission_form/invite_form.vue      # Brand dropdown (modifiye)
  views/submit_form_draw_signature/show.html.erb  # Mobil scroll lock (modifiye)
  views/templates/_submission.html.erb            # Status renkleri (modifiye)
db/
  migrate/
    20260507100000_create_brands.rb
    20260507100100_add_brand_id_to_submissions.rb
  seeds/brands.rb
spec/models/brand_spec.rb
.claude/agents/                                   # Claude yardımcı agent tanımları
```

---

## Customization Yaparken Kurallar

1. **Yeni dosya yaz** > **mevcut dosyayı modifiye et** (merge conflict riskini azaltır)
2. Modifiye etmen gereken upstream dosyasının üstüne `# DOCSIGN-CUSTOM:` comment'i ekle ve neyi değiştirdiğini yaz
3. Brand-spesifik logic'i `Brand` modeline veya `BrandsHelper`'a koy, view'larda `@brand.foo` çağır
4. Locale'lerde Türkçe metinler `config/locales/tr.docsign.yml` içine (DocuSeal'in `i18n.yml`'ini bozmamak için)
5. RSpec testi her yeni model/servis için zorunlu

---

## Markalar (Seed)

| Slug | Ad | Renk | Logo |
|---|---|---|---|
| `academia_united` | Academia United | `#1E40AF` | `brands/academia_united.svg` |
| `linguland` | Linguland | `#15803D` | `brands/linguland.svg` |
| `topstudy` | Topstudy | `#EA580C` | `brands/topstudy.svg` |
