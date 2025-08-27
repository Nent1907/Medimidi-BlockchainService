# Fabric CA Configuration Directory

Bu klasör **Fabric CA manuel konfigürasyonu** için ayrılmıştır.

## Şu Anki Durum: DEVELOPMENT

- 🔄 **Cryptogen kullanıyoruz** → Manuel CA setup yok
- 🐳 **Docker-compose CA'ları** otomatik çalışıyor  
- 📁 **Bu klasör boş** - normal durum

## Production İçin Gerekli Dosyalar

Production ortamında bu klasörde şu dosyalar olacak:

```
fabric-ca/
├── org1-ca-server-config.yaml     # Org1 CA server config
├── org2-ca-server-config.yaml     # Org2 CA server config  
├── orderer-ca-server-config.yaml  # Orderer CA server config
├── fabric-ca-server-ca.org1.medical.com.yaml
├── fabric-ca-server-ca.org2.medical.com.yaml
├── fabric-ca-server-ca.orderer.medical.com.yaml
└── scripts/
    ├── enroll-admin.sh             # Admin enrollment
    ├── register-users.sh           # User registration
    └── generate-certificates.sh    # Certificate generation
```

## Development vs Production

| Feature | Development (Cryptogen) | Production (Fabric CA) |
|---------|------------------------|------------------------|
| **Setup Speed** | ⚡ Otomatik (2 saniye) | ⏳ Manuel setup (5-10 dk) |
| **Certificate Management** | ❌ Statik (fixed users) | ✅ Dinamik (runtime users) |
| **User Registration** | ❌ Pre-generated only | ✅ Runtime registration |
| **New Doctor Addition** | ❌ Network restart gerekli | ✅ Hot-add possible |
| **Certificate Rotation** | ❌ Manuel regeneration | ✅ Otomatik renewal |
| **Revocation** | ❌ Desteklemiyor | ✅ CRL/OCSP support |

## Geçiş Planı

1. **Phase 1**: Cryptogen (şu anki durum) ✅
2. **Phase 2**: Hybrid (Cryptogen + CA scripts) 
3. **Phase 3**: Full Fabric CA (production)

Bu klasör **Phase 2 ve 3** için hazır bekliyor.
