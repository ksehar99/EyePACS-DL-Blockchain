# EyePACS-DL-Blockchain
## Diabetic Retinopathy Early Diagnosis — Deep Learning + Blockchain Pipeline (v2)

A restructured iteration of an earlier internship project combining Deep Learning and Blockchain for secure, tamper-proof diabetic retinopathy screening. This version rebuilds the DL component from scratch on a new dataset with a binary classification approach, and integrates a significantly improved smart contract architecture with a fully working CLI-based pipeline.

Previous version (v1): https://github.com/ksehar99/DL_Blockchain_Pipeline_For_DR_EarlyDiagnosis

---

## Status

| Component | Status |
|---|---|
| Deep Learning Model | Complete |
| Smart Contract | Complete — deployed on private network |
| Web3 Python Bridge + CLI | Complete |
| DL + Blockchain Integration | Complete |

---

## Deep Learning

**Dataset:** EyePACS — pre-organized into binary classes (Nrdr / Rdr), balanced across splits.

| Split | No DR | DR | Total |
|---|---|---|---|
| Train | 2,100 | 2,100 | 4,200 |
| Valid | 600 | 600 | 1,200 |
| Test | — | — | 600 |

**Model:** MobileNetV2 (ImageNet pretrained) with a custom classification head — GlobalAveragePooling2D → Dense(256, relu) → Dropout(0.5) → Dense(1, sigmoid).

**Training:** Two-phase transfer learning.
- Phase 1: Base frozen, head trained for 20 epochs (Adam lr=1e-3, binary crossentropy, EarlyStopping on val_auc)
- Phase 2: Top 30 layers unfrozen, fine-tuned from Phase 1 best checkpoint (Adam lr=1e-5, 15 epochs)

**Evaluation:** TTA (Test-Time Augmentation) — predictions averaged over original + 3 flipped variants. Final threshold set to 0.30 (tuned from default 0.50 to prioritize recall).

| Metric | Default Threshold (0.50) | Final Threshold (0.30) |
|---|---|---|
| DR Recall | 0.670 | **0.860** |
| DR Precision | 0.878 | 0.727 |
| No DR Recall | 0.877 | 0.677 |
| Accuracy | 0.788 | 0.768 |
| AUC | 0.874 | 0.870 |

Threshold was lowered to 0.30 because in a clinical screening context, missing a DR case (false negative) carries significantly higher risk than a false alarm (false positive). At 0.30, the model catches 86% of actual DR cases.

---

## Smart Contract

**Network:** Private Ethereum network (Hardhat, Chain ID 1337, PoA consensus) — patient data never touches a public chain.

**Contract:** `DRDiagnosisResults.sol`

**Architecture:**   
Admin    → registers patients, assigns doctors, reassigns doctors   
Doctor   → uploads AI diagnosis, records own clinical decision   
Patient  → views own records and doctor decisions, manages cross-hospital consent   
System   → verifies tamper-proof hash on-chain after every diagnosis   

**Key features:**

Role-based access control — three distinct roles (admin, doctor, patient) with enforced separation at the contract level. Admin cannot upload diagnoses. Doctors cannot register patients. Patient consent cannot be given by anyone other than the patient.

AI provenance logging — every on-chain diagnosis record includes the retinal image hash, model version hash, prediction result, and confidence score. Any change to the image or the model is immediately detectable.

Human-in-the-loop — AI prediction and doctor decision are two separate on-chain transactions. The doctor explicitly records whether they agreed with or overrode the model, along with optional clinical notes. No diagnosis is treated as final without this sign-off.

Patient consent — patient controls cross-hospital data sharing consent via their own wallet. Admin cannot grant or revoke this on the patient's behalf. Consent can be revoked at any time.

Second opinion — the assigned doctor can request a second opinion from another doctor, granting them read access to that patient's records.

Tamper verification — the SHA-256 hash of the retinal image is recomputed and checked against the on-chain record at any time to confirm the image has not been modified since diagnosis.

**On-chain record per diagnosis:**

| Field | Type | Description |
|---|---|---|
| imageHash | bytes32 | SHA-256 of retinal image |
| diagnosisResult | bool | true = DR detected |
| confidenceScore | uint | 0–100 (model confidence %) |
| modelVersionHash | bytes32 | SHA-256 of model file |
| doctorId | address | Uploading doctor's wallet |
| timestamp | uint | Block timestamp |
| reviewedByDoctor | bool | Pending review flag |

---

## Pipeline

The full end-to-end flow runs through a CLI interface:   
Admin registers patient → assigns doctor → patient gets account number   
↓   
Doctor selects patient → system picks unused retinal image automatically   
↓   
MobileNetV2 runs inference → result + confidence displayed on screen   
↓   
Doctor reviews → agrees or overrides → notes added (optional)   
↓   
AI prediction + doctor decision written to blockchain (two transactions)   
↓   
Tamper verification runs automatically — image hash checked on-chain   
↓   
Patient logs in → views diagnosis records and doctor decisions   

---

## Limitations

Authentication is simulated via account number selection. In production, each participant would authenticate using a private key signature.

The system runs on a local Hardhat network — blockchain state does not persist across sessions. A production deployment would run on a persistent private network across multiple hospital nodes.

Patient personal details are not stored on-chain. A production system would pair the blockchain with an encrypted off-chain database, with the smart contract enforcing access control at the API level.

Cross-hospital consent and external doctor authorization are implemented in the smart contract but require a multi-hospital network to demonstrate meaningfully.
