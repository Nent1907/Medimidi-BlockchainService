# Config Directory

Bu klasör production ortamı için konfigürasyon dosyalarına ayrılmıştır.

## Development Stage

Şu anda **cryptogen** kullandığımız için bu klasör boş. 
Development aşamasında tüm konfigürasyonlar otomatik yapılıyor.

## Production Stage

Production'da bu klasörde şu dosyalar olacak:

### Fabric CA Configuration
- `fabric-ca/org1-ca-server-config.yaml`
- `fabric-ca/org2-ca-server-config.yaml` 
- `fabric-ca/orderer-ca-server-config.yaml`

### Peer & Orderer Configuration
- `core.yaml` - Peer configuration
- `orderer.yaml` - Orderer configuration
- `logging.yaml` - Logging configuration

### Monitoring
- `monitoring.yaml` - Prometheus/Grafana setup

## Usage

Bu klasör şu anda **placeholder** olarak duruyor.
Gelecekteki production setup'ı için hazır.
