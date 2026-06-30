# Diabetic Retinopathy Early Diagnosis — Deep Learning + Blockchain
## Project Background and Progress Document

---

## 1. The Problem

Diabetic Retinopathy (DR) is an eye condition caused by long-term diabetes, where damage to the blood vessels in the retina can lead to vision loss and eventually blindness. The dangerous part of DR is that it develops silently — in its early stages, a patient typically has no symptoms, and by the time vision changes are noticeable, significant damage may already be irreversible.

Early diagnosis is therefore critical. The earlier DR is caught, the more treatable it is. However, diagnosing DR requires a trained ophthalmologist to examine retinal images and look for specific signs — this is time-consuming, requires specialist expertise that isn't always available, especially in under-resourced healthcare settings, and is subject to human variability between different doctors reviewing the same image.

This is the gap this project addresses: can a deep learning model assist in screening retinal images for DR, flagging cases early so doctors can prioritize and confirm, rather than reviewing every single image from scratch?

---

## 2. Why Deep Learning for This Problem

Retinal images are a visual diagnostic problem — the disease shows up as visible patterns and abnormalities on the retina. This is exactly the type of problem convolutional neural networks (CNNs) are well suited for: they can learn to recognize visual patterns from large numbers of labeled examples, similar to how a doctor learns to recognize disease patterns after seeing thousands of cases.

The goal of using deep learning here is not to replace the doctor's judgment, but to act as a **screening and triage tool** — a first-pass filter that can quickly flag likely DR cases out of a large volume of images, so doctors can focus their time and expertise where it's most needed. This is especially valuable in screening programs where large numbers of patients need to be checked but specialist time is limited.

**Why this approach has value:**
- Faster turnaround — automated screening can process images much faster than manual review
- Consistency — a model applies the same criteria every time, reducing variability between reviewers
- Scalability — can be deployed in settings with limited access to specialists

**Why this approach has risk, and why it must be used carefully:**
- A model is only as good as the data it was trained on — it can fail on cases that look different from its training data
- False negatives (missing a real DR case) are clinically dangerous — this is why recall, not just overall accuracy, matters so much in this context
- A model should support a doctor's decision, not replace it — this is a recurring theme that also shapes how blockchain will later be used in this project (see Section 5)

---

## 3. First Attempt: Multi-Class Severity Classification (v1)

The first version of this project attempted to classify DR into its full severity spectrum: No DR, Mild, Moderate, Severe, and Proliferative — five distinct stages of disease progression. This mirrors how doctors actually grade DR clinically, so it was the natural starting point.

**Dataset used:** APTOS 2019, around 2,930 labeled retinal images across the five severity classes.

**Model used:** EfficientNetB3, a deep convolutional architecture pretrained on ImageNet and fine-tuned on the retinal images (a standard transfer learning approach — reusing a model that already knows general visual features, then teaching it the specifics of retinal disease).

**What went wrong:** The dataset was heavily imbalanced — the majority of images were "No DR," while the more severe stages (Severe, Proliferative) had very few examples. This is a common and serious problem in medical imaging: the most dangerous cases are often also the rarest, simply because fewer patients reach that stage before being diagnosed. Despite efforts to correct for this (class weighting, augmenting minority classes, focal loss), the model still struggled — it achieved 80% overall accuracy, but recall on the Severe and Proliferative classes was only around 0.18, meaning the model was missing roughly 4 out of 5 of the most critical cases. An overall accuracy number looked reasonable, but it was hiding a serious weakness exactly where it mattered most.

Link to v1 repository: https://github.com/ksehar99/DL_Blockchain_Pipeline_For_DR_EarlyDiagnosis

This result led to the decision to restart the modeling approach rather than keep trying to patch the multi-class model.

---

## 4. Second Attempt: Binary Classification (v2 — current)

**The core change:** instead of classifying DR into five severity stages, the model now classifies images into two categories: **DR present** or **No DR**.

**Why this change helps:**

Multi-class severity grading is a much harder problem than it first appears, because the boundary between adjacent stages (e.g., Mild vs Moderate) is often subtle even for human graders, and because rare severe classes simply don't have enough examples for a model to learn from reliably. By collapsing the problem to binary, every "has DR" example — regardless of its original severity grade — becomes one of two simpler classes, which gives the model far more balanced and abundant examples to learn from. The dataset used for this version, EyePACS, also happened to be naturally balanced once organized this way (equal numbers of DR and non-DR images), which removed the imbalance problem almost entirely without needing the workarounds (augmentation, class weighting, focal loss) the first version relied on.

**Why this tradeoff is reasonable for the goal of this project:** A binary screening model — "does this patient need further review or not" — is a realistic and valuable first stage in a real screening pipeline. Severity grading can be a second-stage task performed by a specialist once a case has already been flagged, rather than something the first-pass AI model needs to get exactly right.

**Model used:** MobileNetV2, a lighter pretrained architecture than EfficientNetB3, again using transfer learning. A lighter model was chosen partly for faster iteration while establishing a clean, reliable baseline.

**Results:** The binary model achieved 81% overall accuracy, with an AUC of 0.874 (AUC measures how well the model separates the two classes across all possible decision thresholds, not just at one fixed cutoff — a more complete picture of model quality than accuracy alone). Recall on the DR class was 0.743, meaning the model currently catches about 3 out of 4 actual DR cases.

**Comparing v1 and v2 directly:** the overall accuracy is similar between versions (80% vs 81%), but that number is misleading in v1's case, since it masked very poor performance on the most dangerous classes. v2's simpler task gives a result that is more honest and more usable — the recall number, while still needing improvement, reflects a single meaningful class rather than being averaged across five classes of very different difficulty and importance.

**What's still being refined:** Recall of 0.743 is not yet good enough for a clinical screening tool — missing 1 in 4 real DR cases is too high a risk. The next planned step is decision threshold tuning: the model outputs a probability rather than a hard yes/no, and by adjusting the cutoff used to decide "DR" vs "No DR" (rather than retraining the model), recall can be pushed significantly higher, with an acceptable tradeoff of more false alarms (which a doctor can quickly rule out, unlike a missed case).

---

## 5. Why Blockchain — Role in Healthcare AI Systems

Once a model produces a diagnosis, a separate but equally important question arises: how is that diagnosis recorded, trusted, and acted upon in a real clinical environment? This is where blockchain comes in — not as a replacement for the AI model, but as a trust and accountability layer around it.

**Why healthcare specifically is a strong fit for blockchain:**

- **Tamper-proof records.** Medical diagnoses, once recorded, should not be alterable after the fact — by accident, by a system bug, or maliciously. Blockchain's core property is immutability: once a record is written, it cannot be silently changed. This matters in healthcare both for patient safety and for legal/regulatory reasons.
- **Accountability and traceability.** If an AI-assisted diagnosis is later questioned (a patient disputes it, an insurer asks for proof, or a regulator audits the system), there needs to be a verifiable record of exactly what the model predicted, when, on what data, and what a human doctor decided afterward. Blockchain provides this kind of provable history.
- **Access control without a single point of failure.** Patient data is highly sensitive. Blockchain-based smart contracts can enforce who is allowed to view or act on a patient's data, with that access control itself being transparent and auditable, rather than relying solely on a single hospital's internal database security.
- **Patient ownership and consent.** There is a growing trend in healthcare technology toward giving patients more control over their own medical data — who can see it, for how long, and the ability to revoke that access. Blockchain-based consent mechanisms are one way this is being explored industry-wide.
- **Interoperability between institutions.** Patients often see multiple doctors or move between hospitals. A blockchain-based record (or a pointer to one) can act as a shared, trusted reference point between institutions that don't otherwise trust each other's internal systems.

**Current industry trend:** Healthcare blockchain research and pilot programs are increasingly focused on a few recurring patterns: using blockchain to log AI model decisions for accountability (rather than storing all medical data on-chain, which is impractical), combining blockchain with decentralized file storage (like IPFS) so large files such as medical images aren't stored directly on the chain, and using blockchain primarily as a consent and access-control layer rather than a data warehouse. This project's direction follows that same general pattern — the blockchain is not meant to store or replace the medical record itself, but to provide a verifiable trust layer around how the AI model's predictions and the doctor's decisions are recorded and accessed.

**Why this project specifically considered blockchain (not just as an add-on):** The starting motivation was that an AI-assisted diagnosis is only as trustworthy as the system around it. A model can be accurate, but if its output can be silently altered after the fact, or if there's no clear record of whether a doctor actually reviewed and confirmed it, the system is not trustworthy enough for real clinical use. Blockchain was chosen specifically to close that gap — not because it's a trending technology, but because the specific properties it offers (immutability, auditability, enforceable access rules) map directly onto real weaknesses in how AI-assisted diagnoses are typically recorded today.

The first version of this project (v1) already implemented a working blockchain layer — a smart contract handling patient registration, doctor-restricted diagnosis uploads, and on-chain hash-based verification that an image hadn't been tampered with after diagnosis. That implementation is a useful reference point, but the decision was made to first strengthen the DL model in this version before re-integrating and improving the blockchain layer, so that the trust layer is being built around a model that is actually reliable.

---

## 6. Where This Project Stands Now, and What's Next

**Completed so far (this version):**
- Binary DR classification model trained and evaluated on EyePACS dataset
- Model achieves 81% accuracy, 0.874 AUC, with identified recall gap on the DR class

**Immediate next step:**
- Threshold tuning to raise DR recall to a clinically acceptable level (target 90%+) before considering the model ready
