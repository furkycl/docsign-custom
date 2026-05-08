# docsign-custom

**Çoklu marka destekli, white-label, self-hosted e-imza platformu.**
Türk müşteriler için DocuSeal tabanında özelleştirilmiş, üç marka (Academia United, Linguland, Topstudy) ile çalışan iç araç.

> **Upstream:** https://github.com/docusealco/docuseal (DocuSeal, AGPL-3.0)
> **Bu fork:** https://github.com/furkycl/docsign-custom

---

## İçerik

1. [Ne İşe Yarar?](#ne-işe-yarar)
2. [Özellik Karnesi (16 Müşteri Gereksinimi)](#özellik-karnesi)
3. [Mimari](#mimari)
4. [Hızlı Başlangıç (Geliştirme)](#hızlı-başlangıç-geliştirme)
5. [Production Kurulumu](#production-kurulumu)
6. [Kullanım Akışı](#kullanım-akışı)
7. [Markalar (Seed)](#markalar-seed)
8. [Bakım & Upstream Senkronizasyonu](#bakım--upstream-senkronizasyonu)
9. [Yedekleme](#yedekleme)
10. [Sorun Giderme](#sorun-giderme)

---

## Ne İşe Yarar?

`docsign-custom`, kurum içi sözleşme/form imzalama akışlarını dijitalleştiren bir araçtır:

- Yönetici PDF şablon yükler (öğrenci sözleşmesi, izin formu, vs.)
- Şablona imza/tarih/metin alanları yerleştirir
- Marka seçer (Academia United / Linguland / Topstudy) ve alıcının e-postasına gönderir
- Alıcı **üye olmadan** linke tıklar, PDF'i okur, parmağıyla/fareyle imza atar
- Sistem imzayı PDF'e gömer (kilitli), sona audit sayfası ekler (tarih + saat + IP)
- Yönetici tüm gönderimleri tablodan takip eder, imzalı PDF'i indirir

Üç marka için tek panel, tek deploy, ayrı renkli e-postalar.

---

## Özellik Karnesi

| # | Müşteri Gereksinimi | Durum |
|---|---|---|
| 1 | Ana şablonlar listelenen sayfa | ✅ |
| 2 | "Yeni Şablon Yükle" butonu + PDF | ✅ |
| 3 | Şablon gönderimde marka dropdown (3 brand) | ✅ |
| 4 | Sade gönderim formu (marka + email + gönder) | ✅ |
| 5 | Brand-aware e-posta (logo, Türkçe metin, marka rengi) | ✅ |
| 6 | Üyeliksiz signer linki | ✅ |
| 7 | Sticky "İmzala" butonu | ✅ |
| 8 | Drawn + upload imza | ✅ |
| 9 | Mobil scroll lock | ✅ |
| 10 | Temizle / Kaydet butonları | ✅ |
| 11 | Sade teşekkür sayfası | ✅ |
| 12 | Yönetici takip tablosu | ✅ |
| 13 | Renkli status etiketleri (gri/yeşil/kırmızı) | ✅ |
| 14 | İmzalı PDF + kilitli imza | ✅ |
| 15 | Audit trail (tarih + saat + IP) | ✅ |
| 16 | Tarih bazlı arşiv | ✅ |

---

## Mimari

```
┌────────────────────────┐         ┌──────────────────┐
│  Tarayıcı (admin)      │         │  Tarayıcı (signer)│
│  ───────               │         │  ───────         │
│  /templates             │         │  /s/{slug}        │
│  /submissions           │         │  → PDF + imza    │
└──────────┬─────────────┘         └─────────┬────────┘
           │                                  │
           │  HTTPS (Caddy)                   │
           ▼                                  ▼
┌─────────────────────────────────────────────────┐
│  Rails 8.1 + Puma + Sidekiq                       │
│  ───────                                          │
│  - 3 Brand otomatik seed (after_create callback) │
│  - Brand-aware mailer (logo + renk + Türkçe)     │
│  - HexaPDF flatten + audit trail (IP, tarih)     │
└──────────┬───────────────────────────┬──────────┘
           │                           │
   ┌───────▼────────┐         ┌────────▼─────────┐
   │ PostgreSQL 16  │         │ S3 / Disk Volume │
   │ Submission +   │         │ Şablon PDF'leri  │
   │ Submitter +    │         │ İmzalı PDF'ler   │
   │ Brand          │         │ Audit trail'ler  │
   └────────────────┘         └──────────────────┘
```

**Customization katmanı:** DocuSeal'e dokunulmadan eklenen tek bağımsız modül `Brand` modelidir.

---

## Hızlı Başlangıç (Geliştirme)

Mac'te lokal çalıştırma — Docker Desktop kurulu olmalı:

```bash
git clone https://github.com/furkycl/docsign-custom.git
cd docsign-custom
docker compose -f docker-compose.dev.yml up
```

İlk başlatma 5–10 dakika sürer (`bundle install`, `yarn install`, `db:migrate`, brand seed).

`* Listening on http://0.0.0.0:3000` görününce: **http://localhost:5678** açın.

İlk kullanım:
1. `/setup` → admin hesabı oluşturun (şirket adı, email, şifre)
2. Hesap oluşur oluşmaz `Brand.after_create` callback'i 3 markayı otomatik seed'ler
3. Profil → "Dil" → Türkçe seçin (varsayılan zaten Türkçe gelmeli)
4. Şablon yükle, gönder, test et

### Lokal testler

```bash
docker compose -f docker-compose.dev.yml exec app bundle exec rspec spec/models/brand_spec.rb spec/mailers/submitter_mailer_brand_spec.rb
```

17 test yeşil olmalı.

---

## Production Kurulumu

### Sunucu Gereksinimleri

| Kaynak | Minimum | Önerilen |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB | 8 GB |
| Disk | 40 GB SSD | 100 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| Docker | 24.x+ | 24.x+ |

Hetzner CX22 (4 EUR/ay), DigitalOcean Basic (6 USD/ay) veya kurumsal on-prem VM yeterli.

### DNS

Bir alt-domain seçin: `imza.musteri.com.tr`. DNS'inde A-record sunucu IP'sine bakacak şekilde ayarlayın.

### SMTP

Bir e-posta servisi gereklidir. Önerilenler:
- **Postmark** — transactional için en iyi deliverability (~$15/ay 10k mail)
- **AWS SES** — en ucuz ($0.10/1k mail)
- **Resend** — modern, free tier ile başlanabilir
- **Office 365 SMTP** — kurumsal abonelik varsa ücretsiz

DKIM + SPF + DMARC kayıtları **şart** — aksi halde mailler spam'e düşer.

### Kurulum Adımları

> Production Dockerfile ve compose dosyaları için **`KURULUM.md`** dosyasına bakın.
> Kısa özet: SSH ile sunucuya bağlan → docker kur → repo'yu çek → `.env.production` doldur → `docker compose -f docker-compose.prod.yml up -d` → DNS'i bekle → smoke test.

---

## Kullanım Akışı

### Admin (Yönetici)

1. **Şablon yükleme**
   - `Şablonlar` → `Yükle` → PDF seç
   - Editörde sürükle-bırak ile alanlar (signature, text, date) yerleştir
   - `Kaydet`

2. **Gönderim**
   - Şablonu aç → `Alıcı Ekle` butonu
   - **Marka** seç (Academia United / Linguland / Topstudy)
   - Alıcı e-postası gir → `Gönder`
   - Sistem ilgili marka logosuyla otomatik mail atar

3. **Takip**
   - `Gönderimler` sekmesi
   - Status badge: Gri (Gönderildi), Yeşil (İmzalandı), Kırmızı (Reddedildi)
   - Tamamlananın `İndir` butonu ile imzalı PDF'i al

4. **Arşiv**
   - `Gönderimler` üst köşesinde `Arşivlenmiş Görüntüle`
   - Eski gönderimler tarih sıralı

### Signer (Alıcı)

1. E-postadaki marka logolu **`Belgeyi Görüntüle ve İmzala`** butonuna tıklar
2. Login YOKTUR — direkt PDF açılır
3. Aşağı scroll yapar, en altta sticky **`İmzala`** butonu
4. Tıklar → canvas modal'ı açılır → parmak/fare ile imza çizer (mobilde sayfa kilitli)
5. `Temizle` ile silebilir, `Kaydet`/`Tamamla` ile gönderir
6. **"Belgeniz başarıyla imzalanmıştır"** sayfası
7. PDF kopyasını indirebilir

---

## Markalar (Seed)

Her yeni hesap otomatik olarak 3 markaya sahip olur:

| Slug | Ad | Birincil Renk | Logo |
|---|---|---|---|
| `academia_united` | Academia United | `#1E40AF` (mavi) | `app/assets/images/brands/academia_united.svg` |
| `linguland` | Linguland | `#15803D` (yeşil) | `app/assets/images/brands/linguland.svg` |
| `topstudy` | Topstudy | `#EA580C` (turuncu) | `app/assets/images/brands/topstudy.svg` |

Logo değiştirmek için `app/assets/images/brands/` altındaki SVG'leri yenisiyle değiştirin (yeniden deploy gerekir).

`email_from_address` boş — production'da SMTP ayarladıktan sonra her marka için doldurun:

```bash
docker compose -f docker-compose.prod.yml exec app bin/rails runner '
  Brand.find_by(slug: "academia_united").update!(email_from_address: "noreply@academiaunited.com")
  Brand.find_by(slug: "linguland").update!(email_from_address: "noreply@linguland.com")
  Brand.find_by(slug: "topstudy").update!(email_from_address: "noreply@topstudy.com")
'
```

---

## Bakım & Upstream Senkronizasyonu

DocuSeal upstream'inden gelen güvenlik patch'leri ayda bir merge edilmelidir:

```bash
git fetch upstream
git checkout main
git merge upstream/master
# Çakışma varsa: DOCSIGN-CUSTOM marker'lı satırları koru, üstüne entegre et
bundle install
docker compose -f docker-compose.dev.yml exec app bin/rails db:migrate
docker compose -f docker-compose.dev.yml exec app bundle exec rspec
git push origin main
```

Customization branch stratejisi `CLAUDE.md`'de detaylı açıklanmıştır.

---

## Yedekleme

PostgreSQL günlük yedeklemesi (cron + S3):

```bash
# scripts/backup.sh — günlük çalıştırılabilir
docker compose -f docker-compose.prod.yml exec -T postgres \
  pg_dump -U postgres docuseal | gzip > /backups/db-$(date +%Y%m%d).sql.gz

# S3'e yükle (aws-cli kuruluysa)
aws s3 cp /backups/db-$(date +%Y%m%d).sql.gz s3://my-backups/docsign/
```

Object storage (S3) kullanılıyorsa otomatik versioning + replication yeterli.

---

## Sorun Giderme

| Belirti | Neden | Çözüm |
|---|---|---|
| Container başlatma sırasında 503 | Cold-start (libpdfium, vips ilk kez yükleniyor) | 30 sn bekle, tekrar dene |
| `webpacker.1 exited code 0` (dev) | FUSE bind-mount file watching quirk | `Procfile.dev`'de `shakapacker --watch` kullanılıyor zaten |
| E-posta spam'a düşüyor | DKIM/SPF/DMARC eksik | DNS kayıtlarını SMTP servisinin verdiği değerlerle ekle |
| Şablon upload 503 | Worker pool dolu, libpdfium init ediliyor | Container restart sonrası ilk request, 1-2 retry yeterli |
| Türkçe gözükmüyor | Account.locale ≠ 'tr' | `/settings/profile` → Dil → Türkçe seç |

---

## Lisans

Bu fork DocuSeal'in **AGPL-3.0** lisansını devralır. İç araç olarak kullanım serbest. SaaS olarak sunarsanız kaynak kodu paylaşma yükümlülüğü tetiklenir.

## Destek

İç teknik sorular için [furkycl/docsign-custom Issues](https://github.com/furkycl/docsign-custom/issues).
