# EngiNet 🎓
> Mühendislik öğrencilerini ve profesyonelleri bir araya getiren eğitim platformu

---

## 📌 Hakkında
EngiNet, mühendislik öğrencileri ve profesyoneller için geliştirilmiş tam kapsamlı bir eğitim platformudur. Makaleler, kitaplar, kurslar, soru-cevap ve yapay zeka destekli öneriler tek bir uygulamada sunulmaktadır.

---

## 🛠 Teknoloji Yığını

| Katman | Teknoloji |
|--------|-----------|
| Mobil | Flutter (Dart) |
| Backend | FastAPI (Python) |
| Veritabanı | Supabase (PostgreSQL) |
| Kimlik Doğrulama | JWT + bcrypt |
| Yapay Zeka/ML | ALS + İçerik Tabanlı Filtreleme |
| AI Sohbet | Groq API (LLaMA 3) |
| Depolama | Supabase Storage |
| E-posta | Gmail SMTP |

---

## ✨ Özellikler

- 🔐 JWT kimlik doğrulama ile kayıt ve giriş
- 📧 OTP e-posta ile şifre sıfırlama (6 haneli kod, 10 dakika geçerli)
- 📚 Kategoriye göre makale, kitap ve kurs gezinme
- ❓ Mühendislik soruları sorma ve yanıtlama
- 🤖 LLaMA 3 destekli yapay zeka sohbet asistanı
- 🎯 Kişiselleştirilmiş öneriler (ALS + İçerik Tabanlı)
- 🏆 Puan sistemi — içerik katkısıyla puan kazanma
- 🔔 Bildirim sistemi
- 👤 Öğrenci ve Mühendis profilleri
- 🔍 Tüm içeriklerde global arama

---

## 🚀 Kurulum

### Backend (FastAPI)

```bash
# 1. Repoyu klonla
git clone https://github.com/kullanici-adin/enginet.git
cd enginet/backend

# 2. Bağımlılıkları yükle
pip install -r requirements.txt

# 3. Ortam değişkenlerini ayarla
cp .env.example .env
# .env dosyasını doldurun

# 4. Sunucuyu çalıştır
uvicorn main:app --reload
```

### Ortam Değişkenleri

```env
SUPABASE_URL=supabase_url
SUPABASE_KEY=supabase_servis_anahtari
SECRET_KEY=jwt_gizli_anahtar
GMAIL_USER=gmail@gmail.com
GMAIL_PASSWORD=gmail_uygulama_sifresi
GROQ_API_KEY=groq_api_anahtari
ALLOWED_ORIGINS=http://localhost,https://alanadiniz.com
```

### Flutter Uygulaması

```bash
cd enginet/flutter

# Bağımlılıkları yükle
flutter pub get

# lib/core/constants.dart dosyasında base URL'i ayarla
# Uygulamayı çalıştır
flutter run
```

---

## 📁 Proje Yapısı

```
enginet/
├── backend/
│   ├── main.py                  # Kimlik doğrulama, OTP, temel uç noktalar
│   ├── articles_router.py
│   ├── books_router.py
│   ├── courses_router.py
│   ├── questions_router.py
│   ├── recommendations_router.py
│   ├── routers/
│   │   └── ai_router.py
│   ├── models.py
│   ├── database.py
│   └── dependencies.py
│
└── flutter/
    ├── lib/
    │   ├── core/
    │   │   ├── app_colors.dart
    │   │   ├── constants.dart
    │   │   └── session_manager.dart
    │   ├── screens/
    │   ├── widgets/
    │   └── main.dart
```

---

## 🔒 Güvenlik

- Şifreler **bcrypt** ile hashlenir
- **JWT token** ile kimlik doğrulama (süreli)
- OTP kodları **10 dakika** sonra geçersiz olur
- API anahtarları **ortam değişkenlerinde** saklanır (istemcide asla)
- Dosya yüklemeleri **tür ve boyuta** göre doğrulanır

---

## 🧪 Testleri Çalıştırma

```bash
cd backend
pytest tests/
```

---

## 👥 Katkıda Bulunanlar

| İsim | Rol |
|------|-----|
| [Fatımatulzahraa Assad] | Tam Yığın Geliştirici |

---

## 📄 Lisans
MIT Lisansı — serbestçe kullanabilir ve değiştirebilirsiniz.