# EyePACS-DL-Blockchain
## Diabetic Retinopathy Early Diagnosis — Deep Learning + Blockchain Pipeline (v2)

A restructured iteration of an earlier internship project combining Deep Learning and Blockchain for secure, tamper-proof diabetic retinopathy screening. This version rebuilds the DL component from scratch on a new dataset with a binary classification approach, and introduces a significantly improved smart contract architecture.

Previous version (v1): https://github.com/ksehar99/DL_Blockchain_Pipeline_For_DR_EarlyDiagnosis

---

## Status

| Component | Status |
|---|---|
| Deep Learning Model | Complete |
| Smart Contract | Written, pending deployment |
| Web3 Python Bridge | In progress |

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
Admin → registers patient + assigns doctor   
Patient → gives/revokes consent    
Doctor → uploads AI diagnosis + records own decision   
Anyone authorized → verifies tamper-proof hash on-chain   

**Key features:**

Role-based access control — three distinct roles (admin, doctor, patient) with enforced separation. Admin cannot upload diagnoses. Doctor cannot register patients. Patient consent cannot be given by anyone else.

AI provenance logging — every on-chain diagnosis record includes the image hash, model version hash, prediction result, and confidence score. Any change to the image or model is detectable.

Human-in-the-loop — AI prediction and doctor decision are two separate on-chain transactions. Doctor explicitly records whether they agreed with or overrode the model.

Pending review tracking — every uploaded diagnosis is flagged as unreviewed until the doctor records their decision. `isReviewed()` and `DiagnosisUploaded` events allow off-chain monitoring without expensive on-chain loops.

Patient consent — patient controls their own consent via their wallet. Consent can be revoked at any time, blocking future diagnosis uploads immediately.

Emergency access — admin can access records in emergencies, with the access reason permanently logged on-chain.

Second opinion — primary doctor can request a second opinion from another doctor, granting them temporary read access.

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

## Next Steps

1. Deploy smart contract to private Hardhat network
2. Build Web3.py bridge — patient registration, consent, diagnosis upload, doctor decision, tamper verification
3. Integrate DL model inference with blockchain pipeline end-to-end
