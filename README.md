# 🏥 Medical Diagnosis Blockchain System

## 🔧 PROJE TANIMI

Dış bir sistemde doktorlar tarafından doldurulan tıbbi teşhis formlarını **Hyperledger Fabric RAFT konsensüs algoritması** tabanlı bir blockchain ağına güvenli şekilde kaydedecek bir sistem. Bu formlar JSON formatında gelecek ve değiştirilemez, izlenebilir, şifreli ve merkeziyetsiz bir yapıda saklanacak.

## 🧪 TEST DURUMU

Proje başlangıcında sistemden bağımsız olarak **dummy (örnek) JSON verileri** kullanılacak. Blockchain altyapısı başarılı şekilde kurulup test edildikten sonra dış sistemle **gerçek entegrasyon yapılacak**.

## 🎯 HEDEF

- ✅ Doktorlar tarafından doldurulan teşhis formlarının blockchain üzerinde block olarak saklanması
- ✅ Her formun public/private key altyapısıyla imzalanarak güvenliğinin ve bütünlüğünün sağlanması  
- ✅ Sadece yetkili kişilerce erişilebilecek, şeffaf ve denetlenebilir bir yapı oluşturulması

## 🧱 KULLANILACAK TEKNOLOJİLER

- **Hyperledger Fabric** - Permissioned blockchain platform
- **RAFT** - Konsensüs algoritması
- **Fabric CA** - Dijital kimlik ve key üretimi
- **Chaincode (Go)** - Smart contract geliştirme
- **Docker & Docker Compose** - Konteynerizasyon
- **REST API** - JSON veriyi chaincode'a göndermek için
- **CouchDB** - JSON veriler üzerinde sorgu (opsiyonel)
- **WSL + Ubuntu** - Windows geliştirme ortamı

## 🗂️ MİMARİ

### Network Yapısı (RAFT Konsensüs)
- **2 Organizasyon** (Org1 & Org2), her biri 1 peer node'a sahip
- **2 Orderer Node Cluster** (RAFT konsensüs algoritması ile çalışan)
  - `orderer0.medimidi.com:7050` (RAFT Leader)
  - `orderer1.medimidi.com:8050` (RAFT Follower)
- **Fabric CA** üzerinden her doktor için kimlik ve public/private key üretilecek
- **Crash Fault Tolerance**: 1 orderer çökerse sistem durur (2 orderer ile majority gerekli)

### Veri Akışı
1. Teşhis formları dış sistemden JSON formatında REST API ile alınacak
2. JSON verisi chaincode'a gönderilerek block olarak ledger'a kaydedilecek
3. Her form doktorun private key'i ile imzalanacak
4. Geri çağrıldığında public key ile doğrulama yapılacak
5. CouchDB ile form içeriği üzerinde rich query yapılabilecek (isteğe bağlı)

## 🔐 GÜVENLİK

- **TLS Encryption** - Tüm iletişimler şifrelenecek
- **Digital Signatures** - Doktorun private key'i ile her form imzalanacak
- **Immutable Records** - Veriler değiştirilemez olacak
- **Audit Trail** - Her işlem izlenebilir şekilde kaydedilecek
- **Access Control** - Sadece yetkili kimlikler işlem yapabilecek

## 📋 YAPILACAKLAR LİSTESİ

### 1. ✅ Altyapı Kurulumu (TAMAMLANDI)
- [x] **RAFT Konsensüs** ile Hyperledger Fabric ağı kuruldu
- [x] **2 Orderer Node** cluster konfigürasyonu
- [x] Fabric CA yapılandırması tamamlandı
- [x] Docker Compose ile tam otomasyon sağlandı

### 2. ✅ Chaincode Geliştirme (TAMAMLANDI)
- [x] `AddDiagnosisForm(jsonData)` - Form ekleme fonksiyonu
- [x] `GetDiagnosisForm(formId)` - Form sorgulama fonksiyonu  
- [x] `ListDiagnosisForms()` - Form listeleme fonksiyonu
- [x] `GetFormsByDoctor()` - Doktora göre sorgulama
- [x] `GetFormsByPatient()` - Hastaya göre sorgulama
- [x] `VerifyFormSignature()` - Dijital imza doğrulama
- [x] Dijital imzalama ve doğrulama fonksiyonları

### 3. ✅ Network Scripts (TAMAMLANDI)  
- [x] **Cryptogen** certificate generation scripti
- [x] **RAFT destekli** network başlatma scripti (otomatik crypto generation)
- [x] Channel oluşturma scripti (RAFT cluster ile)
- [x] Chaincode deployment scripti (RAFT consensus ile)

### 4. ✅ API Geliştirme (TAMAMLANDI)
- [x] REST API geliştirildi (Node.js/Express)
- [x] Blockchain entegrasyon middleware'i
- [x] Error handling ve logging
- [x] Health check endpoints

### 5. 🚀 Test ve Entegrasyon (HAZIR)
- [x] Dummy JSON test verileri hazırlandı
- [ ] **Sonraki adım**: Network'ü başlatıp test etmek
- [ ] Gerçek sistem entegrasyonu

## 🏗️ PROJE YAPISI

```
BlockchainService/
├── README.md
├── docker-compose.yml
├── network/
│   ├── organizations/
│   │   ├── ordererOrganizations/
│   │   └── peerOrganizations/
│   ├── scripts/
│   └── configtx/
├── chaincode/
│   └── medical-diagnosis/
├── api/
│   ├── server.js
│   └── routes/
├── test-data/
│   └── dummy-forms.json
└── config/
    ├── fabric-ca/
    └── core.yaml
└── caliper/
    ├── workloads/
    └── benchmark.yaml
    └── networkConfig.json
    └── package.json

```

## 📊 ÖRNEK JSON FORM YAPISI

```json
{
  "formId": "DIAG-2024-001",
  "doctorId": "DR001",
  "patientId": "PAT001",
  "timestamp": "2024-01-01T10:00:00Z",
  "diagnosis": {
    "primary": "Hypertension",
    "secondary": ["Diabetes Type 2"],
    "icdCodes": ["I10", "E11.9"]
  },
  "symptoms": ["High blood pressure", "Fatigue"],
  "treatment": {
    "medications": [
      {
        "name": "Lisinopril",
        "dosage": "10mg",
        "frequency": "Once daily"
      }
    ],
    "recommendations": ["Diet modification", "Regular exercise"]
  },
  "signature": "digital_signature_hash"
}
```

## 🚀 BAŞLATMA TALİMATLARI (RAFT Konsensüs)

### Ön Gereksinimler
- ✅ Docker ve Docker Compose
- ✅ WSL2 + Ubuntu (Windows için)
- ✅ Go 1.19+
- ✅ Node.js 16+
- ✅ Hyperledger Fabric binaries (configtxgen, peer, etc.)

### Kurulum (RAFT + Cryptogen ile)
```bash
# 1. Environment dosyasını hazırla
cp .env.example .env
# .env dosyasını düzenleyin

# 2. (Opsiyonel) Cryptographic material'ı manuel generate et
./network/scripts/generate-crypto.sh

# 3. RAFT Cluster'ı başlat (otomatik crypto generation ile)
./network/scripts/start-network.sh

# 4. RAFT destekli channel oluştur
./network/scripts/create-channel.sh

# 5. Chaincode'u RAFT cluster'a deploy et
./network/scripts/deploy-chaincode.sh

# 6. API sunucusunu başlat
cd api
npm install
npm start
```

### 🔧 RAFT Konsensüs Avantajları
- **Consistency**: Strong consistency guarantee
- **Performance**: Yüksek throughput
- **Simplicity**: 2 node ile basit setup
- **Byzantine Fault Tolerance**: Malicious node'lara karşı korumalı değil, sadece crash faults

### 🔐 Cryptogen Certificate Management
- **Otomatik Certificate Generation**: Network başlatırken otomatik çalışır
- **Development Ready**: Hızla test edebilir durumda
- **Complete PKI**: Tüm organizasyonlar için MSP yapısı
- **TLS Support**: Tüm communication şifrelenmiş

## 📝 NOTLAR

### ⚡ RAFT Konsensüs Özellikleri
- **2 Orderer Node** cluster ile basit consensus sağlanmıştır
- **Leader Election**: Otomatik leader seçimi
- **Log Replication**: Tüm transactions 2 orderer'da replike edilir
- **Crash Fault Tolerance**: 1 node çökerse sistem durur (majority gerekli)
- **No Byzantine Faults**: Malicious node'lara karşı korumalı değil

### 🔧 Development Durumu
- ✅ **RAFT entegrasyonu tamamlandı**
- ✅ **Full blockchain stack hazır**
- ⏳ İlk aşamada dummy veriler kullanılacaktır
- ⏳ Production ortamı için ek güvenlik önlemleri alınmalıdır
- ⏳ Performance tuning sonraki versiyonlarda yapılacaktır

### 🎯 Production Önerileri
- **3+ Orderer** kullanın (daha yüksek fault tolerance için)
- **TLS certificates** production-grade olmalı
- **Hardware Security Modules (HSM)** kullanın
- **Network segmentation** ve **firewall rules** uygulayın
- **Monitoring ve alerting** sistemi kurun



---
*Bu dokümantasyon proje geliştirme sürecinde güncellenecektir.*
