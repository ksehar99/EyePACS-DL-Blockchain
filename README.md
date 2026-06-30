# EyePACS-DL-Blockchain

## Diabetic Retinopathy — Deep Learning + Blockchain Pipeline (v2)

This is a fresh, restructured iteration of an earlier internship project that combined Deep Learning with Blockchain for secure, tamper-proof diabetic retinopathy (DR) diagnosis. This version restarts the deep learning component from scratch on a new dataset, using a binary classification approach with the goal of building a stronger model before re-integrating blockchain.

The previous version (multi-class, EfficientNetB3, APTOS dataset) is preserved separately and referenced in the comparison document for context.

---

## Current Status

This repository currently contains the **Deep Learning component only**. Blockchain integration is planned as the next phase, not yet implemented in this version.

---

## Deep Learning Model

**Dataset:** EyePACS, pre-organized into binary classes (Nrdr = No DR, Rdr = DR), split into train/valid/test sets.
- Train: 4,200 images (2,100 Nrdr / 2,100 Rdr — balanced)
- Valid: 1,200 images (600 Nrdr / 600 Rdr)
- Test: 600 images (merged folder, labels inferred per image)

**Architecture:** Transfer learning on MobileNetV2 (ImageNet pretrained). Classification head: GlobalAveragePooling2D → Dense(256, relu) → Dropout(0.4) → Dense(1, sigmoid).

**Preprocessing:** Images resized to 224x224, normalized using MobileNetV2's native `preprocess_input` ([-1, 1] range). No augmentation applied — dataset was already class-balanced and augmentation was found unnecessary at this dataset size.

**Training:** Two-phase approach.
- Phase 1: Base model frozen, only classification head trained. 10 epochs, Adam optimizer (lr=1e-3), binary crossentropy loss.
- Phase 2: Last 30 layers of base model unfrozen, fine-tuned at lower learning rate (1e-5). Best Phase 1 checkpoint loaded before fine-tuning.

Both phases used EarlyStopping (monitor: val_auc) and ReduceLROnPlateau.

**Evaluation:** Test set evaluated using Test-Time Augmentation (TTA) — predictions averaged over original image plus horizontal flip, vertical flip, and both-flip variants.

| Metric | Value |
|---|---|
| Overall Accuracy | 0.81 |
| Overall AUC | 0.874 |
| Precision (DR) | 0.858 |
| Recall (DR) | 0.743 |
| Precision (No DR) | 0.774 |
| Recall (No DR) | 0.877 |

**Confusion Matrix (test set, n=600):**

|  | Predicted No DR | Predicted DR |
|---|---|---|
| Actual No DR | 263 | 37 |
| Actual DR | 77 | 223 |

---

## Known Limitation

Recall on the DR (positive) class is 0.743 at the default 0.5 decision threshold — meaning roughly 1 in 4 actual DR cases are currently missed. For a screening tool, this is the most important metric to improve, since false negatives carry higher clinical risk than false positives. Threshold tuning (lowering the decision threshold below 0.5) is the planned next step to raise recall toward 0.90+, with an expected tradeoff in precision.

---

## Repository Structure

- `notebooks/DR_DL_training.ipynb` — Data loading, preprocessing, two-phase MobileNetV2 training, TTA-based test evaluation.
- `docs/PROGRESS.md` — Comparison between v1 (multi-class, EfficientNetB3) and v2 (binary, MobileNetV2), including rationale for changes.

---

## Next Steps

1. Threshold tuning to improve DR recall to 90%+ for clinical screening use.
2. Re-introduce blockchain layer (smart contract + Web3 bridge), informed by v1's design, with improvements.
