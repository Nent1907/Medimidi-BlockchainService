const { logger } = require('./logger');

// API hataları için özel hata sınıfı
class APIError extends Error {
  constructor(message, statusCode = 500, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.timestamp = new Date().toISOString();
    
    Error.captureStackTrace(this, this.constructor);
  }
}

// Hata işleme middleware'i
const errorHandler = (error, req, res, next) => {
  let { statusCode = 500, message, isOperational = false } = error;

  // Hata detaylarını logla
  logger.error('API Error occurred', {
    error: {
      message: error.message,
      stack: error.stack,
      statusCode,
      isOperational
    },
    request: {
      method: req.method,
      url: req.url,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      body: req.body
    }
  });

  // Belirli hata türlerini işle
  if (error.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation Error: ' + error.message;
  } else if (error.name === 'CastError') {
    statusCode = 400;
    message = 'Invalid data format';
  } else if (error.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  } else if (error.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Token expired';
  } else if (error.code === 'LIMIT_FILE_SIZE') {
    statusCode = 400;
    message = 'File size too large';
  } else if (error.type === 'entity.parse.failed') {
    statusCode = 400;
    message = 'Invalid JSON format';
  }

  // Fabric/Blockchain özel hataları
  if (error.message.includes('chaincode')) {
    if (error.message.includes('does not exist')) {
      statusCode = 404;
      message = 'Resource not found on blockchain';
    } else if (error.message.includes('already exists')) {
      statusCode = 409;
      message = 'Resource already exists on blockchain';
    } else if (error.message.includes('MVCC_READ_CONFLICT')) {
      statusCode = 409;
      message = 'Concurrent modification error';
    } else if (error.message.includes('Failed to connect')) {
      statusCode = 503;
      message = 'Blockchain service temporarily unavailable';
    }
  }

  // Production'da iç hata detaylarını açığa çıkarma
  if (process.env.NODE_ENV === 'production' && !isOperational) {
    message = 'Internal server error';
  }

  // Hata yanıtını hazırla
  const errorResponse = {
    success: false,
    error: {
      message,
      statusCode,
      timestamp: new Date().toISOString()
    }
  };

  // Development'da hata detaylarını ekle
  if (process.env.NODE_ENV === 'development') {
    errorResponse.error.stack = error.stack;
    errorResponse.error.details = error;
  }

  // Mevcut ise request ID ekle
  if (req.headers['x-request-id']) {
    errorResponse.error.requestId = req.headers['x-request-id'];
  }

  res.status(statusCode).json(errorResponse);
};

// Async hata sarmalayıcısı
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

// 404 işleyicisi
const notFoundHandler = (req, res, next) => {
  const error = new APIError(`Route ${req.originalUrl} not found`, 404, true);
  next(error);
};

module.exports = {
  errorHandler,
  APIError,
  asyncHandler,
  notFoundHandler
};
