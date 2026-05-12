# docsign-custom — Müşteri Sunucusu Kurulum Rehberi

Bu rehber, takım liderinin müşterinin Linux sunucusuna **sıfırdan** `docsign-custom`'u kurması için adım adım talimat içerir. Tüm komutlar test edilmiştir, sırayla takip edildiğinde yaklaşık **1-2 saatte** sistem canlıya alınır.

---

## İçindekiler

1. [Ön Hazırlık Kontrol Listesi](#1-ön-hazırlık-kontrol-listesi)
2. [Sunucu Hazırlığı](#2-sunucu-hazırlığı)
3. [Repository Kurulumu](#3-repository-kurulumu)
4. [Çevre Değişkenleri (.env.production)](#4-çevre-değişkenleri-envproduction)
5. [DNS Yapılandırması](#5-dns-yapılandırması)
6. [Sistemi Başlatma](#6-sistemi-başlatma)
7. [İlk Admin Hesabı ve Marka Yapılandırması](#7-i̇lk-admin-hesabı-ve-marka-yapılandırması)
8. [SMTP DKIM/SPF/DMARC Kayıtları](#8-smtp-dkimspfdmarc-kayıtları)
9. [Smoke Test (Uçtan Uca Doğrulama)](#9-smoke-test-uçtan-uca-doğrulama)
10. [Yedekleme Kurulumu](#10-yedekleme-kurulumu)
11. [Müşteri Teslimi ve Eğitim](#11-müşteri-teslimi-ve-eğitim)
12. [Bakım Operasyonları](#12-bakım-operasyonları)
13. [Sorun Giderme](#13-sorun-giderme)

---

## 1. Ön Hazırlık Kontrol Listesi

Kuruluma başlamadan önce **müşteriden bu 8 bilgiyi al**:

| # | Bilgi | Örnek değer | Notlar |
|---|---|---|---|
| 1 | Sunucu IP'si | `1.2.3.4` | Public IP |
| 2 | SSH erişimi | SSH key veya parola | `root` veya `sudo` kullanıcısı |
| 3 | İşletim sistemi | Ubuntu 22.04 LTS | Diğer Linux distrolar için bash komutları benzer |
| 4 | Sunucu kaynak | min 2 vCPU / 4 GB RAM / 40 GB SSD | Daha az ise performans düşer |
| 5 | Subdomain | `imza.musteri.com.tr` | DNS A-record'u sunucu IP'sine bakacak |
| 6 | DNS yönetim erişimi | Panel veya teknik kişi | Cloudflare/Route53/host paneli |
| 7 | SMTP servisi tercihi | Postmark / SES / Resend / Office 365 | E-posta gönderimi için |
| 8 | SMTP credentials | API key veya kullanıcı/şifre | Güvenli kanaldan iletilsin |

**Takım liderinin elinde olması gerekenler:**
- Repo erişimi: https://github.com/furkycl/docsign-custom
- Bu KURULUM.md dosyası
- Kurulum sırasında müşterinin IT'siyle iletişim hattı

---

## 2. Sunucu Hazırlığı

### 2.1. SSH ile bağlan

```bash
ssh root@<SUNUCU_IP>
# veya
ssh ubuntu@<SUNUCU_IP>
```

### 2.2. Sistem güncellemesi

```bash
apt update && apt upgrade -y
apt install -y curl ca-certificates git
```

### 2.3. Docker kurulumu

```bash
# Docker'ı resmi kurulum scriptiyle indir (Ubuntu/Debian)
curl -fsSL https://get.docker.com | sh

# Servis başlat ve sistem başlangıcına ekle
systemctl enable --now docker

# Test
docker --version
docker compose version
```

### 2.4. Güvenlik duvarı (ufw)

```bash
# Sadece SSH (22) + HTTP (80) + HTTPS (443) açık olsun
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable
```

### 2.5. (Opsiyonel) Yeni kullanıcı oluştur

Root kullanmamak için:

```bash
adduser docsign
usermod -aG docker docsign
usermod -aG sudo docsign

# Sonra SSH key'i kopyala ve docsign kullanıcısına geç:
su - docsign
```

---

## 3. Repository Kurulumu

### 3.1. Repo'yu çek

```bash
# /opt klasörüne kuralım
cd /opt
sudo git clone https://github.com/furkycl/docsign-custom.git
sudo chown -R $(whoami):$(whoami) docsign-custom
cd docsign-custom
```

### 3.2. Repo durumunu doğrula

```bash
git log --oneline -3
# En üstte main branch'in son commit'i görünmeli
```

---

## 4. Çevre Değişkenleri (.env.production)

### 4.1. Şablonu kopyala

```bash
cd /opt/docsign-custom
cp .env.production.example .env.production
```

### 4.2. SECRET_KEY_BASE üret

```bash
openssl rand -hex 64
# Çıktıyı kopyala (128 karakterlik hex string)
```

### 4.3. PostgreSQL parolası üret

```bash
openssl rand -base64 32
# Bu da kopyala
```

### 4.4. .env.production'ı düzenle

```bash
nano .env.production
```

Aşağıdaki alanları doldur:

| Değişken | Değer |
|---|---|
| `HOST` | `imza.musteri.com.tr` (müşterinin subdomain'i) |
| `SECRET_KEY_BASE` | (4.2'de ürettiğin string) |
| `POSTGRES_PASSWORD` | (4.3'te ürettiğin string) |
| `DATABASE_URL` | `postgresql://docsign:<POSTGRES_PASSWORD>@postgres:5432/docsign_production` |
| `SMTP_*` | Müşterinin SMTP servisinin değerleri (örnekler dosyada) |
| `SMTP_FROM` | `noreply@imza.musteri.com.tr` |
| `S3_*` | (opsiyonel) S3 bucket bilgileri |

**Dikkat:**
- `DATABASE_URL` içindeki parola `POSTGRES_PASSWORD` ile **birebir aynı** olmalı
- `SMTP_DOMAIN` genelde `HOST` değerinin domain kısmı (örn. `musteri.com.tr`)
- Parolaları **iki tırnak içine alma** — düz değerler `KEY=value` formatında

### 4.5. .env.production izinleri

```bash
chmod 600 .env.production
# Sadece sahip okuyabilir — secret'lar başkasına görünmesin
```

---

## 5. DNS Yapılandırması

**Müşterinin DNS sağlayıcısına şu kaydı ekletin:**

| Type | Name | Value | TTL |
|---|---|---|---|
| `A` | `imza` (veya tam subdomain) | `<SUNUCU_IP>` | `3600` |

**Doğrulama (sunucuda):**

```bash
# DNS propagation kontrolü (5-30 dk sürer)
dig +short imza.musteri.com.tr
# Çıktı sunucu IP'si olmalı
```

DNS yansımadan Caddy SSL alamaz, sonraki adımda hata verir.

---

## 6. Sistemi Başlatma

### 6.1. İlk build (uzun sürer)

```bash
cd /opt/docsign-custom

# İlk build ~10-15 dk sürer (Ruby gem'leri + frontend asset compile)
docker compose -f docker-compose.prod.yml --env-file .env.production build
```

### 6.2. Servisleri başlat

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

### 6.3. Logları izle

```bash
# Canlı log akışı
docker compose -f docker-compose.prod.yml logs -f

# Beklenen çıktı:
# postgres   | database system is ready to accept connections
# redis      | Ready to accept connections
# app        | * Listening on http://0.0.0.0:3000
# caddy      | server running on :443
```

`Ctrl+C` ile log'tan çık (container'lar arka planda çalışmaya devam eder).

### 6.4. DB migration ve brand seed

Container içinde Rails migration ve brand seed çalıştır:

```bash
docker compose -f docker-compose.prod.yml exec app bin/rails db:migrate
docker compose -f docker-compose.prod.yml exec app bin/rails runner db/seeds/brands.rb
```

### 6.5. HTTPS doğrulama

Tarayıcıda **`https://imza.musteri.com.tr`** aç. Beklenen:

- Yeşil kilit ikonu (Let's Encrypt sertifikası)
- **Sign-in** veya **Initial Setup** sayfası açılır

Eğer "This site can't be reached" alıyorsan:
- DNS daha propagate olmamış olabilir (5-30 dk bekle)
- `docker compose logs caddy` → SSL hatasını kontrol et
- Sunucu firewall'u 80 ve 443'ü açık tutuyor mu (`ufw status`)

---

## 7. İlk Admin Hesabı ve Marka Yapılandırması

### 7.1. Initial Setup

Tarayıcıdan `https://imza.musteri.com.tr` aç → Initial Setup formunu doldur:

- **Şirket adı:** Müşterinin kurum adı (örn. "Erusoft Yazılım")
- **Ad / Soyad:** İlk admin'in adı (müşterinin yöneticisi)
- **E-posta:** Müşterinin yöneticisinin gerçek mail adresi
- **Şifre:** Müşteriye iletilecek geçici güçlü parola (sonra değiştirir)

"Hesap Oluştur" → **3 marka otomatik seed'lenir** (`Account#after_create` callback'i):
- Academia United (mavi)
- Linguland (yeşil)
- Topstudy (turuncu)

### 7.2. Marka bilgilerini güncelle (opsiyonel)

E-posta gönderici adlarını markaya özel yapmak istersen:

```bash
docker compose -f docker-compose.prod.yml exec app bin/rails runner '
  Brand.find_by(slug: "academia_united")&.update!(email_from_address: "noreply@academiaunited.com")
  Brand.find_by(slug: "linguland")&.update!(email_from_address: "noreply@linguland.com")
  Brand.find_by(slug: "topstudy")&.update!(email_from_address: "noreply@topstudy.com")
'
```

> **NOT:** Bu adresler için DKIM kayıtları DNS'e eklenmiş olmalı (sonraki adıma bak), aksi halde mailler spam'a düşer.

### 7.3. Brand logolarını değiştir (opsiyonel)

`app/assets/images/brands/` altındaki SVG'leri müşterinin gerçek logolarıyla değiştir, sonra container'ı yeniden build et:

```bash
# Logoları upload ettikten sonra
docker compose -f docker-compose.prod.yml build app
docker compose -f docker-compose.prod.yml up -d app
```

---

## 8. SMTP DKIM/SPF/DMARC Kayıtları

**E-posta yapılandırması olmadan mailler spam'a düşer.** SMTP servisinin (Postmark/SES/Resend) verdiği DNS değerlerini DNS'e ekle:

### Genel kurulum (her servis için benzer)

SMTP servisinin admin panelinden alacaklarınız:
- **SPF kaydı** — bir TXT kayıt
- **DKIM kayıtları** — 1-3 adet CNAME veya TXT kayıt
- **DMARC kaydı** — bir TXT kayıt

### Örnek (Postmark için)

| Type | Name | Value | TTL |
|---|---|---|---|
| `TXT` | `@` veya `imza.musteri.com.tr` | `v=spf1 a mx include:spf.mtasv.net ~all` | `3600` |
| `CNAME` | `20240101pm._domainkey` | `20240101pm.domainkey.postmarkapp.com` | `3600` |
| `TXT` | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:dmarc@musteri.com.tr` | `3600` |

### Doğrulama (24 saat içinde)

SMTP servisinin dashboard'ında "Domain status: Verified" görmen gerekir. Postmark'ta:
- https://account.postmarkapp.com → Senders → Domain → "Verify"

### Test gönderim

```bash
docker compose -f docker-compose.prod.yml exec app bin/rails runner '
  ActionMailer::Base.mail(
    to: "kendi.mailin@example.com",
    from: ENV["SMTP_FROM"],
    subject: "docsign-custom test",
    body: "Eğer bu maili gördüysen SMTP doğru çalışıyor!"
  ).deliver_now
  puts "Mail gönderildi."
'
```

Maili kendi inbox'unda görürsen ✓. Spam klasörüne düşerse DNS kayıtları henüz yansımamıştır, bekle.

---

## 9. Smoke Test (Uçtan Uca Doğrulama)

Müşteriye teslim etmeden **16 maddenin canlı sistemde çalıştığını** doğrula. Bunun için detaylı test rehberi `dokumanlar/test-rehberi.md` dosyasında — özet:

| Test | Sonuç |
|---|---|
| Tarayıcıdan `https://HOST` açılıyor mu? Yeşil kilit var mı? | Evet/Hayır |
| Sign-in yaparak dashboard'a düşülüyor mu? | Evet/Hayır |
| **Şablon yükle** → bir PDF + imza alanı | Evet/Hayır |
| **3 markaya gönderim** (Academia / Linguland / Topstudy) | Evet/Hayır |
| Mailler **inbox'a** (spam'a değil) düşüyor mu? Renkler doğru mu? | Evet/Hayır |
| Mail linkine **incognito** sekmeden tıkla → PDF açılıyor, imza atılıyor | Evet/Hayır |
| Tamamlama sonrası "Belgeniz başarıyla imzalanmıştır" | Evet/Hayır |
| `/submissions` sayfasında status "İmzalandı" yeşil | Evet/Hayır |
| "İndir" → PDF indiriliyor, **denetim sayfası** (IP + tarih) var | Evet/Hayır |
| `/submissions/archived` çalışıyor | Evet/Hayır |

Hepsi ✓ olduğunda müşteri teslimi için hazırsın.

---

## 10. Yedekleme Kurulumu

### 10.1. Backup scriptini hazırla

```bash
chmod +x /opt/docsign-custom/scripts/backup.sh

# İlk yedeği manuel al, çalıştığını gör
sudo /opt/docsign-custom/scripts/backup.sh
```

Çıktıda `Yedek tamam: /var/backups/docsign/db-...sql.gz (XYZ KB)` görmeli.

### 10.2. Cron job kur

```bash
sudo crontab -e
```

Şu satırı ekle (her gece 03:00'da yedek):

```cron
0 3 * * * /opt/docsign-custom/scripts/backup.sh >> /var/log/docsign-backup.log 2>&1
```

### 10.3. (Opsiyonel) S3'e otomatik push

Müşteri uzaktan backup istiyorsa, `backup.sh`'in sonundaki S3 push bölümünü aktifleştir:

```bash
nano /opt/docsign-custom/scripts/backup.sh
# En alttaki `if command -v aws...` bloğunu uncomment et
# AWS CLI kur: apt install awscli
# Credentials: aws configure
```

Sonra `S3_BACKUP_BUCKET` env var'ı tanımla ya da script içinde sabitle.

---

## 11. Müşteri Teslimi ve Eğitim

### 11.1. Müşteriye iletilecekler

| Şey | Nereden | Kime |
|---|---|---|
| **Production URL** | `https://imza.musteri.com.tr` | Tüm yöneticilere |
| **Admin hesap bilgisi** | Şifreli e-posta veya 1Password gibi share | Müşterinin yöneticisine ve müşteri IT'sine |
| **PDF Kullanım Kılavuzu** | `dokumanlar/docsign-custom-kullanim-kilavuzu.pdf` | Tüm yöneticilere |
| **Sunucu erişim bilgileri (root SSH key, vs.)** | Güvenli kanal | Müşteri IT'sine (gelecekte bakım için) |
| **Bakım sözleşmesi** | Şirket sözleşme formatı | Müşteri yönetimine |

### 11.2. Eğitim — 1 saatlik ekran paylaşımı

Müşterinin yöneticisiyle birlikte:

1. **Sign-in** → Şifre değiştir (kendi şifresini belirleyecek)
2. **Şablon Yükleme** → bir PDF + imza alanı yerleştirme
3. **Gönderim** → marka seçimi + alıcı email
4. **Mail görüntüleme** → kendi inbox'ında geleni göster
5. **Signer flow** → linke tıkla, imzala
6. **/submissions** → status değişimi, PDF indirme
7. **Ayarlar** → kullanıcı ekleme (`/settings/users`)
8. **Sorular**

Eğitim sonunda PDF kılavuzunu hatırlat — "her şey orada yazıyor, takıldığında bak".

---

## 12. Bakım Operasyonları

### 12.1. Logları izleme

```bash
# Tüm servislerin canlı logu
docker compose -f docker-compose.prod.yml logs -f

# Sadece app
docker compose -f docker-compose.prod.yml logs -f app
```

### 12.2. Yeniden başlatma

```bash
docker compose -f docker-compose.prod.yml restart
```

### 12.3. Upstream güncelleme (aylık güvenlik patch)

```bash
cd /opt/docsign-custom

# Upstream remote ekli mi kontrol et
git remote -v
# upstream → docusealco/docuseal görmeli

# Yeni commit'leri çek
git fetch upstream

# Bizim main'e merge et
git merge upstream/master

# Çakışma çıkarsa DOCSIGN-CUSTOM marker'lı satırları koru, üstüne entegre et
# Yardım için ekibe danış

# Test ve build
docker compose -f docker-compose.prod.yml build app
docker compose -f docker-compose.prod.yml up -d

# Migration varsa
docker compose -f docker-compose.prod.yml exec app bin/rails db:migrate

# Push
git push origin main
```

### 12.4. Disk kullanım kontrolü

```bash
# Genel disk
df -h

# Docker volume'ları
docker system df

# Eski yedek dosyaları
du -sh /var/backups/docsign/*
```

### 12.5. Veritabanı yedeği geri yükleme (disaster recovery)

```bash
# Önce eski DB'yi temizle (ÇOK DİKKAT)
docker compose -f docker-compose.prod.yml exec postgres \
  psql -U $POSTGRES_USER -c "DROP DATABASE IF EXISTS $POSTGRES_DB; CREATE DATABASE $POSTGRES_DB;"

# Yedekten restore
gunzip < /var/backups/docsign/db-20260512-030000.sql.gz | \
  docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U $POSTGRES_USER -d $POSTGRES_DB

# Uygulamayı restart
docker compose -f docker-compose.prod.yml restart app
```

---

## 13. Sorun Giderme

### 13.1. "This site can't be reached" / 502 Bad Gateway

```bash
# Container durumu
docker compose -f docker-compose.prod.yml ps

# Hangi container çalışmıyor? Logları:
docker compose -f docker-compose.prod.yml logs <servis-adı> --tail 50
```

Yaygın sebepler:
- **DNS henüz yansımadı** → 5-30 dk bekle
- **Caddy SSL alamadı** → 80/443 firewall'da açık olduğunu doğrula
- **App container start edemedi** → `logs app` ile boot hatasını gör

### 13.2. Mail gönderilmiyor

```bash
# SMTP test
docker compose -f docker-compose.prod.yml exec app bin/rails runner '
  begin
    ActionMailer::Base.mail(to: "test@erusoft.com", from: ENV["SMTP_FROM"],
      subject: "test", body: "test").deliver_now
    puts "OK"
  rescue => e
    puts "HATA: #{e.class}: #{e.message}"
  end
'
```

- `Net::SMTPAuthenticationError` → SMTP_USERNAME/PASSWORD yanlış
- `Net::OpenTimeout` → SMTP_ADDRESS veya SMTP_PORT yanlış, firewall block
- `OK` ama mail gelmedi → spam klasörüne bak, DKIM/SPF kayıtları yansımış mı

### 13.3. Database bağlantı hatası

```bash
docker compose -f docker-compose.prod.yml logs app | grep -i "database"
```

- `password authentication failed` → `.env.production`'daki `DATABASE_URL` ve `POSTGRES_PASSWORD` aynı olmalı
- `could not connect` → postgres container ayakta mı (`docker compose ps`)

### 13.4. Disk dolu

```bash
df -h
docker system df

# Eski image'ları temizle
docker system prune -a
```

### 13.5. Performans yavaş

- Sunucu CPU/RAM yetersiz olabilir → `htop` ile bak
- Postgres yavaş → `docker compose exec postgres psql -U $POSTGRES_USER -c "SELECT count(*) FROM submissions"` → kayıt sayısı çok mu

### 13.6. Daha derin yardım

- README.md'deki troubleshooting bölümü
- GitHub Issues: https://github.com/furkycl/docsign-custom/issues
- Upstream DocuSeal docs: https://www.docuseal.com/docs

---

## Ek: Hızlı Komut Referansı

```bash
# Servisleri başlat
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# Logları izle
docker compose -f docker-compose.prod.yml logs -f

# Durumu gör
docker compose -f docker-compose.prod.yml ps

# Yeniden başlat
docker compose -f docker-compose.prod.yml restart

# Durdur
docker compose -f docker-compose.prod.yml down

# Build (kod değişikliği sonrası)
docker compose -f docker-compose.prod.yml build app
docker compose -f docker-compose.prod.yml up -d app

# Rails console
docker compose -f docker-compose.prod.yml exec app bin/rails console

# Manual yedek
sudo /opt/docsign-custom/scripts/backup.sh
```

---

**Hazırlayan:** Erusoft Yazılım
**Versiyon:** 1.0
**Son güncelleme:** 2026-05-11
