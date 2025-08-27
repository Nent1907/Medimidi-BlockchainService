const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const bodyParser = require('body-parser');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

// Route'ları içe aktar
const diagnosisRoutes = require('./routes/diagnosis');
const healthRoutes = require('./routes/health');

// Middleware'leri içe aktar
const logger = require('./middleware/logger');
const { errorHandler } = require('./middleware/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

// Hız sınırlaması
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 dakika
  max: 100 // her IP'yi windowMs başına 100 istekle sınırla
});

// Middleware
app.use(helmet()); // Güvenlik başlıkları
app.use(cors()); // CORS'u etkinleştir
app.use(compression()); // Yanıtları sıkıştır
app.use(limiter); // Hız sınırlamasını uygula
app.use(morgan('combined')); // HTTP istek günlükleme
app.use(bodyParser.json({ limit: '10mb' })); // JSON gövdelerini ayrıştır
app.use(bodyParser.urlencoded({ extended: true }));

// Özel middleware
app.use(logger);

// Rotalar
app.use('/api/health', healthRoutes);
app.use('/api/diagnosis', diagnosisRoutes);

// Ana rota
app.get('/', (req, res) => {
  res.json({
    message: 'Medical Diagnosis Blockchain API',
    version: '1.0.0',
    status: 'Running',
    endpoints: {
      health: '/api/health',
      diagnosis: '/api/diagnosis'
    },
    documentation: {
      swagger: '/api/docs',
      postman: '/api/postman'
    }
  });
});

// 404 işleyicisi
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    message: `Cannot ${req.method} ${req.originalUrl}`,
    availableEndpoints: [
      'GET /',
      'GET /api/health',
      'POST /api/diagnosis/forms',
      'GET /api/diagnosis/forms/:formId',
      'GET /api/diagnosis/forms',
      'GET /api/diagnosis/forms/doctor/:doctorId',
      'GET /api/diagnosis/forms/patient/:patientId'
    ]
  });
});

// Hata işleme middleware (en son olmalı)
app.use(errorHandler);

// Zarif kapatma
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

// Sunucuyu başlat
const server = app.listen(PORT, () => {
  console.log(`
🏥 Medical Diagnosis Blockchain API
🚀 Server is running on port ${PORT}
🌍 Environment: ${process.env.NODE_ENV || 'development'}
📚 API Documentation: http://localhost:${PORT}/
🔗 Blockchain Network: ${process.env.FABRIC_NETWORK || 'local'}
  `);
});

// İşlenmemiş promise reddedilmelerini işle
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  server.close(() => {
    process.exit(1);
  });
});

module.exports = app;
