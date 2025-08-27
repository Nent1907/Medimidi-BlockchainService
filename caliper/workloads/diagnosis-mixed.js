'use strict';
const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

function randomId(prefix='DIAG') {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random()*1e6)}`;
}

class DiagnosisMixedWorkload extends WorkloadModuleBase {
  async initializeWorkloadModule() {
    this.formIds = [];
    this.writeRatio = (this.roundArguments.writeRatio || 0.6);
    this.channel = this.roundArguments.channel || 'medimidi-channel';
    this.contractId = this.roundArguments.contractId || 'medical-diagnosis';
  }

  async submitTransaction() {
    const doWrite = Math.random() < this.writeRatio;
    if (doWrite || this.formIds.length === 0) {
      const formId = randomId();
      const payload = {
        formId,
        doctorId: 'DR001',
        patientId: 'PAT' + Math.floor(Math.random()*1000),
        timestamp: new Date().toISOString(),
        diagnosis: { primary: 'Hypertension', secondary: ['Diabetes Type 2'], icdCodes: ['I10','E11.9'] },
        symptoms: ['High blood pressure', 'Fatigue'],
        treatment: { medications: [{ name: 'Lisinopril', dosage: '10mg', frequency: 'Once daily' }], recommendations: ['Diet','Exercise'] },
        signature: 'digital_signature_hash'
      };

      const req = {
        contractId: this.contractId,
        contractFunction: 'AddDiagnosisForm',
        contractArguments: [JSON.stringify(payload)],
        channel: this.channel,
        readOnly: false
      };
      await this.sutAdapter.sendRequests(req);
      this.formIds.push(formId);
    } else {
      const pick = this.formIds[Math.floor(Math.random()*this.formIds.length)];
      const req = {
        contractId: this.contractId,
        contractFunction: 'GetDiagnosisForm',
        contractArguments: [pick],
        channel: this.channel,
        readOnly: true
      };
      await this.sutAdapter.sendRequests(req);
    }
  }
}

function createWorkloadModule() { return new DiagnosisMixedWorkload(); }
module.exports.createWorkloadModule = createWorkloadModule;
