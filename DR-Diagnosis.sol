// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DRDiagnosisResults
 * @notice Manages diabetic retinopathy diagnosis records on a private blockchain.
 *         Role-based access: Admin registers patients, Doctors upload AI diagnoses
 *         and record their own decisions, Patients control their own consent.
 */
contract DRDiagnosisResults {

    // ─── Data Structures ────────────────────────────────────────────────────

    struct Patient {
        uint patientId;
        address doctorId;
        address patientAddress;
        uint timestamp;
    }

    struct Diagnosis {
        bytes32 imageHash;          // SHA-256 hash of retinal image
        bool diagnosisResult;       // true = DR detected, false = No DR
        uint confidenceScore;       // 0-100 (e.g. 87 means 87% confidence)
        bytes32 modelVersionHash;   // hash of the model file that made this prediction
        uint patientId;
        address doctorId;
        uint timestamp;
        bool reviewedByDoctor;      // false = pending doctor review
    }

    struct DoctorDecision {
        uint patientId;
        bool doctorResult;          // doctor's final call: true = DR, false = No DR
        bool agreedWithAI;          // true = agreed, false = overrode AI prediction
        string notes;
        address doctorId;
        uint timestamp;
    }

    struct Consent {
        bool given;
        uint timestamp;
    }

    // ─── State Variables ─────────────────────────────────────────────────────

    address immutable owner;

    mapping(uint => Patient) private patientIdToPatient;
    mapping(uint => Diagnosis[]) private patientToDiagnosis;
    mapping(uint => DoctorDecision[]) private patientToDoctorDecision;
    mapping(address => uint[]) private doctorToPatientId;
    mapping(uint => bool) private patientExists;
    mapping(uint => mapping(bytes32 => bool)) private diagnosisHashExists;
    mapping(uint => Consent) private patientConsent;
    mapping(uint => address) private secondOpinionDoctor;
    mapping(address => bool) private isAuthorizedDoctor;


    // ─── Errors ──────────────────────────────────────────────────────────────

    error NotOwner();
    error NotAuthorized();
    error PatientAlreadyExists();
    error PatientNotFound();
    error ConsentNotGiven();
    error ConsentAlreadyGiven();
    error NoDiagnosisFound();

    // ─── Events ──────────────────────────────────────────────────────────────

    event PatientRegistered(uint patientId, address doctorAddress);
    event DiagnosisUploaded(uint patientId, address doctorId, bool diagnosisResult, uint confidenceScore, uint timestamp);
    event DoctorDecisionRecorded(uint patientId, bool doctorResult, bool agreedWithAI, uint timestamp);
    event DoctorReassigned(uint patientId, address oldDoctor, address newDoctor);
    event ConsentGiven(uint patientId, uint timestamp);
    event ConsentRevoked(uint patientId, uint timestamp);
    event EmergencyAccessLog(uint patientId, address admin, string reason, uint timestamp);
    event SecondOpinionRequested(uint patientId, address secondDoctor, uint timestamp);

    // ─── Modifier ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ─── Constructor ─────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─── Admin Functions ─────────────────────────────────────────────────────

    function registerPatient(
        uint256 _patientId,
        address _doctorAddress,
        address _patientAddress
    ) external onlyOwner {
        if (patientExists[_patientId]) revert PatientAlreadyExists();

        patientExists[_patientId] = true;
        patientIdToPatient[_patientId] = Patient(
            _patientId,
            _doctorAddress,
            _patientAddress,
            block.timestamp
        );
        doctorToPatientId[_doctorAddress].push(_patientId);

        emit PatientRegistered(_patientId, _doctorAddress);
    }

    function reassignDoctor(uint256 _patientId, address _newDoctor) external onlyOwner {
        if (!patientExists[_patientId]) revert PatientNotFound();

        address oldDoctor = patientIdToPatient[_patientId].doctorId;
        patientIdToPatient[_patientId].doctorId = _newDoctor;
        doctorToPatientId[_newDoctor].push(_patientId);

        emit DoctorReassigned(_patientId, oldDoctor, _newDoctor);
    }

    // Admin can view patient diagnosis and details, without patient consent — permanently logged
    function emergencyAccess(uint _patientId, string calldata reason) 
    external onlyOwner returns (Diagnosis[] memory) {
        emit EmergencyAccessLog(_patientId, msg.sender, reason, block.timestamp);
        return patientToDiagnosis[_patientId];
    }

    function authorizeExternalDoctor(address doctor) external onlyOwner {
        isAuthorizedDoctor[doctor] = true;
    }

    // ─── Patient Functions ───────────────────────────────────────────────────

    // Patient gives consent using their own wallet — admin cannot do this on their behalf
    function giveConsent(uint patientId) external {
        if (!patientExists[patientId]) revert PatientNotFound();
        if (patientIdToPatient[patientId].patientAddress != msg.sender) revert NotAuthorized();
        if (patientConsent[patientId].given) revert ConsentAlreadyGiven();

        patientConsent[patientId] = Consent(true, block.timestamp);
        emit ConsentGiven(patientId, block.timestamp);
    }

    function revokeConsent(uint patientId) external {
        if (!patientExists[patientId]) revert PatientNotFound();
        if (patientIdToPatient[patientId].patientAddress != msg.sender) revert NotAuthorized();

        patientConsent[patientId].given = false;
        patientConsent[patientId].timestamp = block.timestamp;
        emit ConsentRevoked(patientId, block.timestamp);
    }

    // ─── Doctor Functions ────────────────────────────────────────────────────

    // Called by Python after model inference — uploads AI prediction on-chain
    function uploadDiagnosis(
        uint patientId,
        bytes32 imageHash,
        bool diagnosisResult,
        uint confidenceScore,
        bytes32 modelVersionHash
    ) external {
        if (patientIdToPatient[patientId].doctorId != msg.sender) revert NotAuthorized();

        patientToDiagnosis[patientId].push(
            Diagnosis(
                imageHash,
                diagnosisResult,
                confidenceScore,
                modelVersionHash,
                patientId,
                msg.sender,
                block.timestamp,
                false
            )
        );
        diagnosisHashExists[patientId][imageHash] = true;

        emit DiagnosisUploaded(patientId, msg.sender, diagnosisResult, confidenceScore, block.timestamp);
    }

    // Doctor reviews AI prediction and records their own decision
    function recordDoctorDecision(
        uint patientId,
        bool doctorResult,
        bool agreedWithAI,
        string calldata notes
    ) external {
        if (patientIdToPatient[patientId].doctorId != msg.sender) revert NotAuthorized();

        uint total = patientToDiagnosis[patientId].length;
        if (total == 0) revert NoDiagnosisFound();

        patientToDiagnosis[patientId][total - 1].reviewedByDoctor = true;

        patientToDoctorDecision[patientId].push(
            DoctorDecision(
                patientId,
                doctorResult,
                agreedWithAI,
                notes,
                msg.sender,
                block.timestamp
            )
        );

        emit DoctorDecisionRecorded(patientId, doctorResult, agreedWithAI, block.timestamp);
    }

    function requestSecondOpinion(uint patientId, address secondDoctor) external {
        if (patientIdToPatient[patientId].doctorId != msg.sender) revert NotAuthorized();
        secondOpinionDoctor[patientId] = secondDoctor;
        emit SecondOpinionRequested(patientId, secondDoctor, block.timestamp);
    }

    // ─── View Functions ──────────────────────────────────────────────────────

    function viewDoctorDecisions(uint _patientId) external view returns (DoctorDecision[] memory) {
        bool isAdmin = msg.sender == owner;
        bool isAssignedDoctor = msg.sender == patientIdToPatient[_patientId].doctorId;
        bool isPatient = msg.sender == patientIdToPatient[_patientId].patientAddress;
        
        if (!isAdmin && !isAssignedDoctor && !isPatient) revert NotAuthorized();
        return patientToDoctorDecision[_patientId];
    }

    // Returns patient IDs assigned to the calling doctor
    function viewPatients() external view returns (uint[] memory) {
        return doctorToPatientId[msg.sender];
    }

    // On-chain tamper detection — recompute hash off-chain and compare
    function verifyDiagnosis(uint patientId, bytes32 imageHash) external view returns (bool) {
        return diagnosisHashExists[patientId][imageHash];
    }

    // Check if last diagnosis is pending doctor review
    function isReviewed(uint patientId) external view returns (bool) {
        uint total = patientToDiagnosis[patientId].length;
        if (total == 0) return true;
        return patientToDiagnosis[patientId][total - 1].reviewedByDoctor;
    }

    function checkConsent(uint patientId) external view returns (bool) {
        return patientConsent[patientId].given;
    }

    function viewRecords(uint _patientId) external view returns (Diagnosis[] memory) {
        address assignedDoctor = patientIdToPatient[_patientId].doctorId;
        
        bool isAdmin = msg.sender == owner;
        bool isAssignedDoctor = msg.sender == assignedDoctor;
        bool isExternalWithConsent = isAuthorizedDoctor[msg.sender] && patientConsent[_patientId].given;
        bool isSecondOpinionDoctor = secondOpinionDoctor[_patientId] == msg.sender; // ← yeh add karo
        
        if (!isAdmin && !isAssignedDoctor && !isExternalWithConsent && !isSecondOpinionDoctor) 
            revert NotAuthorized();
        
        return patientToDiagnosis[_patientId];
    }
    
    function viewMyRecords(uint _patientId) external view returns (Diagnosis[] memory) {
        if (patientIdToPatient[_patientId].patientAddress != msg.sender) revert NotAuthorized();
        return patientToDiagnosis[_patientId];
    }

    function isPatientRegistered(uint patientId) external view returns (bool) {
        return patientExists[patientId];
    }

    function getPatientAddress(uint patientId) external view returns (address) {
        if (!patientExists[patientId]) revert PatientNotFound();
        return patientIdToPatient[patientId].patientAddress;
    }
}