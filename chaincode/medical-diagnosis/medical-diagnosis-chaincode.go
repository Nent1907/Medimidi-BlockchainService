package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// MedicalDiagnosisContract defines the smart contract for medical diagnosis forms
type MedicalDiagnosisContract struct {
	contractapi.Contract
}

type DiagnosisForm struct {
	FormID       string          `json:"formId"`
	DoctorID     string          `json:"doctorId"`
	DoctorName   string          `json:"doctorName"`
	PatientID    string          `json:"patientId"`
	PatientName  string          `json:"patientName"`
	Timestamp    string          `json:"timestamp"`
	Diagnosis    Diagnosis       `json:"diagnosis"`
	Symptoms     []string        `json:"symptoms"`
	PhysicalExam json.RawMessage `json:"physicalExam,omitempty"`
	LabResults   json.RawMessage `json:"labResults,omitempty"`
	Treatment    Treatment       `json:"treatment"`
	FollowUp     FollowUp        `json:"followUp"`
	Signature    string          `json:"signature"`
	CreatedAt    string          `json:"createdAt"`
	UpdatedAt    string          `json:"updatedAt"`
}

type Diagnosis struct {
	Primary   string   `json:"primary"`
	Secondary []string `json:"secondary,omitempty"`
	ICDCodes  []string `json:"icdCodes"`
}

type Treatment struct {
	Medications     []Medication `json:"medications"`
	Recommendations []string     `json:"recommendations"`
}

// Medication represents medication information
type Medication struct {
	Name      string `json:"name"`
	Dosage    string `json:"dosage"`
	Frequency string `json:"frequency"`
	Duration  string `json:"duration"`
}

// FollowUp represents follow-up information
type FollowUp struct {
	NextAppointment string   `json:"nextAppointment,omitempty"`
	UrgentContact   bool     `json:"urgentContact"`
	Instructions    string   `json:"instructions"`
	Referrals       []string `json:"referrals,omitempty"`
}

// QueryResult structure used for handling result of query
type QueryResult struct {
	Key    string `json:"Key"`
	Record *DiagnosisForm
}

// InitLedger adds a base set of diagnosis forms to the ledger (for testing)
func (s *MedicalDiagnosisContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	log.Println("Initializing Medical Diagnosis Ledger...")
	return nil
}

// AddDiagnosisForm adds a new diagnosis form to the blockchain
func (s *MedicalDiagnosisContract) AddDiagnosisForm(ctx contractapi.TransactionContextInterface, formData string) error {
	var form DiagnosisForm

	// Parse the JSON data
	err := json.Unmarshal([]byte(formData), &form)
	if err != nil {
		return fmt.Errorf("failed to parse form data: %v", err)
	}

	// Validate required fields
	if form.FormID == "" {
		return fmt.Errorf("formId is required")
	}
	if form.DoctorID == "" {
		return fmt.Errorf("doctorId is required")
	}
	if form.PatientID == "" {
		return fmt.Errorf("patientId is required")
	}

	// Check if form already exists
	existing, err := ctx.GetStub().GetState(form.FormID)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if existing != nil {
		return fmt.Errorf("diagnosis form %s already exists", form.FormID)
	}

	// Add timestamps
	now := time.Now().UTC().Format(time.RFC3339)
	form.CreatedAt = now
	form.UpdatedAt = now

	// Generate digital signature hash (in real implementation, this would be a proper digital signature)
	signature := s.generateSignature(form.FormID, form.DoctorID, form.Timestamp)
	form.Signature = signature

	// Marshal form to JSON
	formJSON, err := json.Marshal(form)
	if err != nil {
		return fmt.Errorf("failed to marshal form: %v", err)
	}

	// Store the form in the blockchain
	err = ctx.GetStub().PutState(form.FormID, formJSON)
	if err != nil {
		return fmt.Errorf("failed to put form to world state: %v", err)
	}

	// Create audit log for form creation
	if err := s.createFormCreationAuditLog(ctx, form.FormID, form); err != nil {
		log.Printf("Failed to create creation audit log: %v", err)
	}

	// Log the transaction
	log.Printf("Diagnosis form %s added successfully by doctor %s", form.FormID, form.DoctorID)

	return nil
}

// GetDiagnosisForm retrieves a diagnosis form by ID
func (s *MedicalDiagnosisContract) GetDiagnosisForm(ctx contractapi.TransactionContextInterface, formID string) (*DiagnosisForm, error) {
	if formID == "" {
		return nil, fmt.Errorf("formId cannot be empty")
	}

	formJSON, err := ctx.GetStub().GetState(formID)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if formJSON == nil {
		return nil, fmt.Errorf("diagnosis form %s does not exist", formID)
	}

	var form DiagnosisForm
	err = json.Unmarshal(formJSON, &form)
	if err != nil {
		return nil, fmt.Errorf("failed to unmarshal form: %v", err)
	}

	return &form, nil
}

// ListDiagnosisForms
func (s *MedicalDiagnosisContract) ListDiagnosisForms(ctx contractapi.TransactionContextInterface) ([]*DiagnosisForm, error) {

	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get state by range: %v", err)
	}
	defer resultsIterator.Close()

	var forms []*DiagnosisForm
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to get next result: %v", err)
		}

		var form DiagnosisForm
		err = json.Unmarshal(queryResponse.Value, &form)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshal form: %v", err)
		}
		forms = append(forms, &form)
	}

	return forms, nil
}

// GetFormsByDoctor retrieves all forms by a specific doctor
func (s *MedicalDiagnosisContract) GetFormsByDoctor(ctx contractapi.TransactionContextInterface, doctorID string) ([]*DiagnosisForm, error) {
	if doctorID == "" {
		return nil, fmt.Errorf("doctorId cannot be empty")
	}

	// Create a query string for CouchDB
	queryString := fmt.Sprintf(`{
		"selector": {
			"doctorId": "%s"
		}
	}`, doctorID)

	return s.getQueryResultForQueryString(ctx, queryString)
}

// GetFormsByPatient retrieves all forms for a specific patient
func (s *MedicalDiagnosisContract) GetFormsByPatient(ctx contractapi.TransactionContextInterface, patientID string) ([]*DiagnosisForm, error) {
	if patientID == "" {
		return nil, fmt.Errorf("patientId cannot be empty")
	}

	// Create a query string for CouchDB
	queryString := fmt.Sprintf(`{
		"selector": {
			"patientId": "%s"
		}
	}`, patientID)

	return s.getQueryResultForQueryString(ctx, queryString)
}

// VerifyFormSignature verifies the digital signature of a form
func (s *MedicalDiagnosisContract) VerifyFormSignature(ctx contractapi.TransactionContextInterface, formID string) (bool, error) {
	form, err := s.GetDiagnosisForm(ctx, formID)
	if err != nil {
		return false, err
	}

	// Generate expected signature
	expectedSignature := s.generateSignature(form.FormID, form.DoctorID, form.Timestamp)

	// Compare signatures
	return form.Signature == expectedSignature, nil
}

// UpdateDiagnosisFormSelective updates specific fields of an existing diagnosis form
func (s *MedicalDiagnosisContract) UpdateDiagnosisFormSelective(ctx contractapi.TransactionContextInterface, formID string, updateFields string) error {
	// Check if form exists
	existingForm, err := s.GetDiagnosisForm(ctx, formID)
	if err != nil {
		return err
	}

	// Verify update permissions
	if err := s.verifyUpdatePermissions(ctx, existingForm); err != nil {
		return err
	}

	// Parse selective update fields
	var updates map[string]interface{}
	err = json.Unmarshal([]byte(updateFields), &updates)
	if err != nil {
		return fmt.Errorf("failed to parse update fields: %v", err)
	}

	// Apply selective updates
	updatedForm := *existingForm
	changesMade := false

	// Update diagnosis if provided
	if diagnosisUpdate, ok := updates["diagnosis"]; ok {
		var newDiagnosis Diagnosis
		diagnosisBytes, _ := json.Marshal(diagnosisUpdate)
		if err := json.Unmarshal(diagnosisBytes, &newDiagnosis); err == nil {
			updatedForm.Diagnosis = newDiagnosis
			changesMade = true
		}
	}

	// Update symptoms if provided
	if symptomsUpdate, ok := updates["symptoms"]; ok {
		if symptoms, ok := symptomsUpdate.([]interface{}); ok {
			var newSymptoms []string
			for _, symptom := range symptoms {
				if str, ok := symptom.(string); ok {
					newSymptoms = append(newSymptoms, str)
				}
			}
			updatedForm.Symptoms = newSymptoms
			changesMade = true
		}
	}

	// Update treatment if provided
	if treatmentUpdate, ok := updates["treatment"]; ok {
		var newTreatment Treatment
		treatmentBytes, _ := json.Marshal(treatmentUpdate)
		if err := json.Unmarshal(treatmentBytes, &newTreatment); err == nil {
			updatedForm.Treatment = newTreatment
			changesMade = true
		}
	}

	// Update follow-up if provided
	if followUpUpdate, ok := updates["followUp"]; ok {
		var newFollowUp FollowUp
		followUpBytes, _ := json.Marshal(followUpUpdate)
		if err := json.Unmarshal(followUpBytes, &newFollowUp); err == nil {
			updatedForm.FollowUp = newFollowUp
			changesMade = true
		}
	}

	// Update lab results if provided
	if labResultsUpdate, ok := updates["labResults"]; ok {
		if labResultsBytes, err := json.Marshal(labResultsUpdate); err == nil {
			updatedForm.LabResults = json.RawMessage(labResultsBytes)
			changesMade = true
		}
	}

	// Update physical exam if provided
	if physicalExamUpdate, ok := updates["physicalExam"]; ok {
		if physicalExamBytes, err := json.Marshal(physicalExamUpdate); err == nil {
			updatedForm.PhysicalExam = json.RawMessage(physicalExamBytes)
			changesMade = true
		}
	}

	// If no changes were made, return early
	if !changesMade {
		return fmt.Errorf("no valid updates provided")
	}

	// Update metadata
	updatedForm.UpdatedAt = time.Now().UTC().Format(time.RFC3339)

	// Regenerate signature with updated data
	updatedForm.Signature = s.generateSignature(updatedForm.FormID, updatedForm.DoctorID, updatedForm.Timestamp)

	// Create audit trail
	if err := s.createUpdateAuditLog(ctx, formID, updates); err != nil {
		log.Printf("Failed to create audit log: %v", err)
	}

	// Marshal and store
	updatedJSON, err := json.Marshal(updatedForm)
	if err != nil {
		return fmt.Errorf("failed to marshal updated form: %v", err)
	}

	err = ctx.GetStub().PutState(formID, updatedJSON)
	if err != nil {
		return fmt.Errorf("failed to update form in blockchain: %v", err)
	}

	log.Printf("Form %s updated successfully with selective changes", formID)
	return nil
}

// UpdateDiagnosisForm updates an existing diagnosis form (legacy - complete replacement)
func (s *MedicalDiagnosisContract) UpdateDiagnosisForm(ctx contractapi.TransactionContextInterface, formID string, updatedData string) error {
	// Check if form exists
	existingForm, err := s.GetDiagnosisForm(ctx, formID)
	if err != nil {
		return err
	}

	// Verify update permissions
	if err := s.verifyUpdatePermissions(ctx, existingForm); err != nil {
		return err
	}

	// Parse updated data
	var updates DiagnosisForm
	err = json.Unmarshal([]byte(updatedData), &updates)
	if err != nil {
		return fmt.Errorf("failed to parse update data: %v", err)
	}

	// Validate required fields
	if updates.FormID != existingForm.FormID {
		return fmt.Errorf("formId cannot be changed")
	}
	if updates.DoctorID == "" {
		return fmt.Errorf("doctorId is required")
	}
	if updates.PatientID == "" {
		return fmt.Errorf("patientId is required")
	}

	// Preserve original creation data and update timestamp
	updates.FormID = existingForm.FormID
	updates.CreatedAt = existingForm.CreatedAt
	updates.UpdatedAt = time.Now().UTC().Format(time.RFC3339)

	// Regenerate signature
	updates.Signature = s.generateSignature(updates.FormID, updates.DoctorID, updates.Timestamp)

	// Create audit trail for complete update
	auditData := map[string]interface{}{
		"type":              "complete_update",
		"previousSignature": existingForm.Signature,
		"newSignature":      updates.Signature,
	}
	if err := s.createUpdateAuditLog(ctx, formID, auditData); err != nil {
		log.Printf("Failed to create audit log: %v", err)
	}

	// Marshal and store
	updatedJSON, err := json.Marshal(updates)
	if err != nil {
		return fmt.Errorf("failed to marshal updated form: %v", err)
	}

	err = ctx.GetStub().PutState(formID, updatedJSON)
	if err != nil {
		return fmt.Errorf("failed to update form in blockchain: %v", err)
	}

	log.Printf("Form %s updated successfully (complete replacement)", formID)
	return nil
}

// Private helper methods

// verifyUpdatePermissions checks if the caller has permission to update the form
func (s *MedicalDiagnosisContract) verifyUpdatePermissions(ctx contractapi.TransactionContextInterface, existingForm *DiagnosisForm) error {
	// Get the client identity
	clientIdentity := ctx.GetClientIdentity()

	// Get the MSP ID of the caller
	callerMSPID, err := clientIdentity.GetMSPID()
	if err != nil {
		return fmt.Errorf("failed to get caller MSP ID: %v", err)
	}

	// Check if caller is from authorized organization
	if callerMSPID != "Org1MSP" && callerMSPID != "Org2MSP" {
		return fmt.Errorf("unauthorized organization: %s", callerMSPID)
	}

	// Additional permission checks can be added here:
	// - Only original doctor can update
	// - Time-based restrictions (e.g., no updates after 24h)
	// - Role-based permissions

	return nil
}

// createFormCreationAuditLog creates an audit log entry for new form creation
func (s *MedicalDiagnosisContract) createFormCreationAuditLog(ctx contractapi.TransactionContextInterface, formID string, form DiagnosisForm) error {
	// Get transaction details
	txID := ctx.GetStub().GetTxID()
	timestamp, _ := ctx.GetStub().GetTxTimestamp()

	// Get caller identity
	clientIdentity := ctx.GetClientIdentity()
	callerMSPID, _ := clientIdentity.GetMSPID()

	// Create creation audit log entry
	auditLog := map[string]interface{}{
		"formID":    formID,
		"txID":      txID,
		"timestamp": timestamp,
		"callerMSP": callerMSPID,
		"doctorID":  form.DoctorID,
		"patientID": form.PatientID,
		"diagnosis": form.Diagnosis.Primary,
		"logType":   "form_creation",
		"action":    "CREATE_NEW_FORM",
	}

	// Store creation audit log with unique key
	auditKey := fmt.Sprintf("AUDIT-CREATE-%s-%s", formID, txID)
	auditJSON, err := json.Marshal(auditLog)
	if err != nil {
		return fmt.Errorf("failed to marshal creation audit log: %v", err)
	}

	return ctx.GetStub().PutState(auditKey, auditJSON)
}

// createUpdateAuditLog creates an audit log entry for form updates
func (s *MedicalDiagnosisContract) createUpdateAuditLog(ctx contractapi.TransactionContextInterface, formID string, updates interface{}) error {
	// Get transaction details
	txID := ctx.GetStub().GetTxID()
	timestamp, _ := ctx.GetStub().GetTxTimestamp()

	// Get caller identity
	clientIdentity := ctx.GetClientIdentity()
	callerMSPID, _ := clientIdentity.GetMSPID()

	// Create audit log entry
	auditLog := map[string]interface{}{
		"formID":    formID,
		"txID":      txID,
		"timestamp": timestamp,
		"callerMSP": callerMSPID,
		"updates":   updates,
		"logType":   "form_update",
	}

	// Store audit log with unique key
	auditKey := fmt.Sprintf("AUDIT-%s-%s", formID, txID)
	auditJSON, err := json.Marshal(auditLog)
	if err != nil {
		return fmt.Errorf("failed to marshal audit log: %v", err)
	}

	return ctx.GetStub().PutState(auditKey, auditJSON)
}

// GetFormAuditLog retrieves complete audit log for a specific form (creation + updates)
func (s *MedicalDiagnosisContract) GetFormAuditLog(ctx contractapi.TransactionContextInterface, formID string) ([]interface{}, error) {
	if formID == "" {
		return nil, fmt.Errorf("formId cannot be empty")
	}

	var auditLogs []interface{}

	// Get creation audit logs
	createAuditPrefix := fmt.Sprintf("AUDIT-CREATE-%s-", formID)
	createIterator, err := ctx.GetStub().GetStateByRange(createAuditPrefix, createAuditPrefix+"~")
	if err == nil {
		defer createIterator.Close()
		for createIterator.HasNext() {
			queryResponse, err := createIterator.Next()
			if err == nil {
				var auditLog interface{}
				if json.Unmarshal(queryResponse.Value, &auditLog) == nil {
					auditLogs = append(auditLogs, auditLog)
				}
			}
		}
	}

	// Get update audit logs
	updateAuditPrefix := fmt.Sprintf("AUDIT-%s-", formID)
	updateIterator, err := ctx.GetStub().GetStateByRange(updateAuditPrefix, updateAuditPrefix+"~")
	if err == nil {
		defer updateIterator.Close()
		for updateIterator.HasNext() {
			queryResponse, err := updateIterator.Next()
			if err == nil {
				// Skip creation logs (already processed above)
				if !strings.Contains(queryResponse.Key, "AUDIT-CREATE-") {
					var auditLog interface{}
					if json.Unmarshal(queryResponse.Value, &auditLog) == nil {
						auditLogs = append(auditLogs, auditLog)
					}
				}
			}
		}
	}

	if len(auditLogs) == 0 {
		return nil, fmt.Errorf("no audit logs found for form %s", formID)
	}

	return auditLogs, nil
}

// getQueryResultForQueryString executes the passed in query string
func (s *MedicalDiagnosisContract) getQueryResultForQueryString(ctx contractapi.TransactionContextInterface, queryString string) ([]*DiagnosisForm, error) {
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %v", err)
	}
	defer resultsIterator.Close()

	var forms []*DiagnosisForm
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("failed to get next query result: %v", err)
		}

		var form DiagnosisForm
		err = json.Unmarshal(queryResponse.Value, &form)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshal form: %v", err)
		}
		forms = append(forms, &form)
	}

	return forms, nil
}

// generateSignature generates a digital signature hash for the form
// In production, this would use proper cryptographic signing with private keys
func (s *MedicalDiagnosisContract) generateSignature(formID, doctorID, timestamp string) string {
	data := fmt.Sprintf("%s|%s|%s", formID, doctorID, timestamp)
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:])
}

func main() {
	medicalChaincode, err := contractapi.NewChaincode(&MedicalDiagnosisContract{})
	if err != nil {
		log.Panicf("Error creating medical diagnosis chaincode: %v", err)
	}

	if err := medicalChaincode.Start(); err != nil {
		log.Panicf("Error starting medical diagnosis chaincode: %v", err)
	}
}
