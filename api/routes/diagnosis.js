const express = require('express');
const router = express.Router();
const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const Joi = require('joi');

// Doğrulama şemaları
const diagnosisFormSchema = Joi.object({
  formId: Joi.string().required(),
  doctorId: Joi.string().required(),
  doctorName: Joi.string().required(),
  patientId: Joi.string().required(),
  patientName: Joi.string().required(),
  timestamp: Joi.string().isoDate().required(),
  diagnosis: Joi.object({
    primary: Joi.string().required(),
    secondary: Joi.array().items(Joi.string()).optional(),
    icdCodes: Joi.array().items(Joi.string()).required()
  }).required(),
  symptoms: Joi.array().items(Joi.string()).required(),
  physicalExam: Joi.object().optional(),
  labResults: Joi.object().optional(),
  treatment: Joi.object({
    medications: Joi.array().items(Joi.object({
      name: Joi.string().required(),
      dosage: Joi.string().required(),
      frequency: Joi.string().required(),
      duration: Joi.string().required()
    })).required(),
    recommendations: Joi.array().items(Joi.string()).required()
  }).required(),
  followUp: Joi.object({
    nextAppointment: Joi.string().isoDate().optional(),
    urgentContact: Joi.boolean().required(),
    instructions: Joi.string().required(),
    referrals: Joi.array().items(Joi.string()).optional()
  }).required()
});

// Blockchain ağ bağlantısı almak için yardımcı fonksiyon
async function getBlockchainConnection() {
  try {
    // Bağlantı profilini yükle
    const ccpPath = path.resolve(__dirname, '..', '..', 'network', 'organizations', 'peerOrganizations', 'org1.medical.com', 'connection-org1.json');
    
    // Kimlikleri yönetmek için yeni bir dosya sistemi tabanlı cüzdan oluştur
    const walletPath = path.join(process.cwd(), 'wallet');
    const wallet = await Wallets.newFileSystemWallet(walletPath);

    // Kullanıcıyı zaten kayıt etmiş miyiz kontrol et
    const identity = await wallet.get('appUser');
    if (!identity) {
      throw new Error('An identity for the user "appUser" does not exist in the wallet. Run the enrollment script first.');
    }

    // Peer düğümümüze bağlanmak için yeni bir ağ geçidi oluştur
    const gateway = new Gateway();
    await gateway.connect(ccpPath, {
      wallet,
      identity: 'appUser',
      discovery: { enabled: true, asLocalhost: true }
    });

    // Sözleşmemizin deploy edildiği ağı (kanal) al
    const network = await gateway.getNetwork('medical-channel');

    // Ağdan sözleşmeyi al
    const contract = network.getContract('medical-diagnosis-chaincode');

    return { gateway, contract };
  } catch (error) {
    throw new Error(`Failed to connect to blockchain network: ${error.message}`);
  }
}

// POST /api/diagnosis/forms - Yeni tanı formu ekle
router.post('/forms', async (req, res) => {
  try {
    // Girdiyi doğrula
    const { error, value } = diagnosisFormSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(detail => detail.message)
      });
    }

    // Blockchain'e bağlan
    const { gateway, contract } = await getBlockchainConnection();

    try {
      // Tanı formu eklemek için işlem gönder
      const result = await contract.submitTransaction('AddDiagnosisForm', JSON.stringify(value));
      
      res.status(201).json({
        success: true,
        message: 'Diagnosis form added successfully',
        formId: value.formId,
        transactionId: result.toString()
      });
    } finally {
      // Ağ geçidinden bağlantıyı kes
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Error adding diagnosis form:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// GET /api/diagnosis/forms/:formId - ID'ye göre tanı formu getir
router.get('/forms/:formId', async (req, res) => {
  try {
    const { formId } = req.params;

    if (!formId) {
      return res.status(400).json({
        error: 'Form ID is required'
      });
    }

    // Blockchain'e bağlan
    const { gateway, contract } = await getBlockchainConnection();

    try {
      // Deftere sorgu yap
      const result = await contract.evaluateTransaction('GetDiagnosisForm', formId);
      const form = JSON.parse(result.toString());

      res.json({
        success: true,
        data: form
      });
    } finally {
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Error getting diagnosis form:', error);
    
    if (error.message.includes('does not exist')) {
      return res.status(404).json({
        error: 'Form not found',
        message: `Diagnosis form with ID ${req.params.formId} does not exist`
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// GET /api/diagnosis/forms - Tüm tanı formlarını getir
router.get('/forms', async (req, res) => {
  try {
    // Blockchain'e bağlan
    const { gateway, contract } = await getBlockchainConnection();

    try {
      // Tüm formları sorgula
      const result = await contract.evaluateTransaction('ListDiagnosisForms');
      const forms = JSON.parse(result.toString());

      res.json({
        success: true,
        count: forms.length,
        data: forms
      });
    } finally {
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Error listing diagnosis forms:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// GET /api/diagnosis/forms/doctor/:doctorId - Doktora göre formları getir
router.get('/forms/doctor/:doctorId', async (req, res) => {
  try {
    const { doctorId } = req.params;

    if (!doctorId) {
      return res.status(400).json({
        error: 'Doctor ID is required'
      });
    }

    // Blockchain'e bağlan
    const { gateway, contract } = await getBlockchainConnection();

    try {
      const result = await contract.evaluateTransaction('GetFormsByDoctor', doctorId);
      const forms = JSON.parse(result.toString());

      res.json({
        success: true,
        doctorId: doctorId,
        count: forms.length,
        data: forms
      });
    } finally {
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Error getting forms by doctor:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// GET /api/diagnosis/forms/patient/:patientId - Hastaya göre formları getir
router.get('/forms/patient/:patientId', async (req, res) => {
  try {
    const { patientId } = req.params;

    if (!patientId) {
      return res.status(400).json({
        error: 'Patient ID is required'
      });
    }

    // Blockchain'e bağlan
    const { gateway, contract } = await getBlockchainConnection();

    try {
      const result = await contract.evaluateTransaction('GetFormsByPatient', patientId);
      const forms = JSON.parse(result.toString());

      res.json({
        success: true,
        patientId: patientId,
        count: forms.length,
        data: forms
      });
    } finally {
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Error getting forms by patient:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// POST /api/diagnosis/forms/:formId/verify - Form imzasını doğrula
router.post('/forms/:formId/verify', async (req, res) => {
  try {
    const { formId } = req.params;

    if (!formId) {
      return res.status(400).json({
        error: 'Form ID is required'
      });
    }

    // Blockchain'e bağlan
    const { gateway, contract } = await getBlockchainConnection();

    try {
      const result = await contract.evaluateTransaction('VerifyFormSignature', formId);
      const isValid = result.toString() === 'true';

      res.json({
        success: true,
        formId: formId,
        signatureValid: isValid,
        timestamp: new Date().toISOString()
      });
    } finally {
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Error verifying form signature:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// PUT /api/diagnosis/forms/:formId - Tanı formunu güncelle (kısıtlı)
router.put('/forms/:formId', async (req, res) => {
  try {
    const { formId } = req.params;

    if (!formId) {
      return res.status(400).json({
        error: 'Form ID is required'
      });
    }

    // Girdiyi doğrula
    const { error, value } = diagnosisFormSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(detail => detail.message)
      });
    }

    // Blockchain'e bağlan
    const { gateway, contract } = await getBlockchainConnection();

    try {
      await contract.submitTransaction('UpdateDiagnosisForm', formId, JSON.stringify(value));

      res.json({
        success: true,
        message: 'Diagnosis form updated successfully',
        formId: formId
      });
    } finally {
      await gateway.disconnect();
    }
  } catch (error) {
    console.error('Error updating diagnosis form:', error);
    
    if (error.message.includes('does not exist')) {
      return res.status(404).json({
        error: 'Form not found',
        message: `Diagnosis form with ID ${formId} does not exist`
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

module.exports = router;
