## **DIABETIC RETINOPATHY EARLY DIAGNOSIS** 

## Deep Learning \+ Blockchain Pipeline Project Document \- V2

### INTRODUCTION:

### Diabetic retinopathy (DR) is a complication of diabetes that damages the blood vessels in the retina, the light-sensitive layer at the back of the eye. It develops silently, with no noticeable symptoms in early stages, and can lead to permanent vision loss if left undetected. The earlier it is caught, the better the chances of preventing blindness.

Diagnosing DR requires a trained eye specialist to examine retinal photographs and identify subtle signs of damage. This is time-consuming, requires expertise that is not always accessible, and is subjective, two doctors reviewing the same image may reach different conclusions.

This project addresses that problem in two parts:

1. A deep learning model that automatically screens retinal images for DR.  
2. A blockchain layer that ensures every diagnosis, AI or human, is recorded in a way that cannot be altered, forged, or silently deleted.

### WHY DEEP LEARNING 

The retina shows visible signs of DR, tiny hemorrhages, abnormal blood vessels, fluid deposits that appear as patterns in a retinal photograph. Convolutional neural networks (CNNs), a type of deep learning model, are well suited to learning these patterns from thousands of labeled examples, similar to how a specialist develops pattern recognition through years of clinical experience.

The goal is not to replace the doctor. The model acts as a first-pass screening tool. It quickly flags images that are likely to show DR so the doctor can prioritize review, rather than manually examining every single image from scratch. This is especially valuable in settings where a large volume of patients needs to be screened but specialist time is limited.

### VERSION 1 — WHAT WAS BUILT AND WHAT WENT WRONG 

The first version classified DR into five severity grades: No DR, Mild, Moderate, Severe, and Proliferative. The model used was EfficientNetB3, a deep neural network pretrained on ImageNet, fine-tuned on the APTOS 2019 dataset containing around 2,900 retinal images.

#### **Key Issues in Version 1:**

* **Data Imbalance:** The dataset was heavily imbalanced, over half the images belonged to the "No DR" class, while the most severe grades had fewer than 200 examples each.  
* **Low Recall:** Despite efforts to compensate (augmenting minority classes, applying custom class weights, using focal loss), the model still failed on the classes that mattered most. Overall accuracy reached 80%, but recall on Severe and Proliferative grades was only 0.18 meaning the model missed 4 out of 5 of the most critical cases.  
* **Blockchain Layer:** The blockchain component was fully implemented using a Solidity smart contract deployed on the Sepolia public testnet with role-based access control, a Web3.py Python bridge for patient registration/diagnosis upload, and on-chain tamper verification using SHA-256 image hashing.

**Link to Version 1:**  [github repo](https://github.com/ksehar99/DL_Blockchain_Pipeline_For_DR_EarlyDiagnosis)

### VERSION 2 — REBUILDING THE PIPELINE

Three fundamental changes were made to address the failure modes of Version 1:

1. **Binary Classification:** The task was simplified from five-class severity grading to binary classification: DR present or No DR. Binary classification "does this patient need further review?"  is a realistic and valuable first stage in a screening pipeline. Severity grading can follow as a second step performed by a specialist.  
2. **Balanced Dataset:** The dataset was changed to EyePACS, pre-organized into binary classes and already balanced, 2,100 images per class in training. This removed the class imbalance problem almost entirely.  
3. **Lightweight Model:** The model was changed to MobileNetV2, a lighter architecture than EfficientNetB3 that is faster to iterate with while establishing a clean baseline.

### Training Strategy:

* **Two-Phase Training:** In phase one, the pretrained base was frozen and only the custom classification head was trained. In phase two, the top 30 layers of the base were unfrozen and fine-tuned at a lower learning rate. Both phases used early stopping and learning rate reduction to prevent overfitting.  
* **Test-Time Augmentation (TTA):** Evaluation used TTA, averaging predictions across the original image and three flipped versions which improves prediction stability.  
* **Decision Threshold Tuning:** The decision threshold was tuned from the default 0.5 down to 0.3, because in a screening context missing a real DR case is far more dangerous than a false alarm. At threshold 0.3, a doctor can quickly rule out a false positive; a missed case may go untreated.

### Final Results on Test Set:

* Accuracy: 76.8%  
* AUC (Area Under Curve): 0.870  
* DR Recall (Sensitivity): 0.860  
* DR Precision: 0.727

The model correctly identifies 86% of actual DR cases. The AUC of 0.87 means that if you picked one DR image and one No DR image at random, the model would rank the DR image higher 87% of the time, a reliable separator regardless of threshold.

### WHY BLOCKCHAIN 

Once the model produces a diagnosis, a separate question arises: how is that result recorded, trusted, and protected in a real clinical environment?

Medical records are high-stakes. A diagnosis stored in a standard database can be silently altered, by accident, by a system error, or deliberately. There is no built-in way to prove that a record has not been changed since it was created, or to know who accessed it and when.

* **Immutability:** Blockchain solves this through immutability. Once a record is written to a blockchain, it cannot be changed without leaving a detectable trace. Every transaction is cryptographically linked to the ones before it, altering any record breaks the chain.  
* **Private Permissioned Network:** This project uses a private permissioned blockchain (deployed locally via Hardhat) not a public network like Ethereum mainnet or Sepolia testnet. In a private blockchain, only authorized participants (hospital staff) can join the network and submit transactions. Patient data never reaches a public chain.

### VERSION 2 SMART CONTRACT — WHAT IT DOES 

The smart contract is the core of the blockchain layer. It is a program deployed on the blockchain that enforces clinical workflow rules automatically at the code level, split across three key roles:

* **Admin Role:** Registers patients and assigns doctors. A patient cannot be registered twice. Admin can reassign a patient to a different doctor if needed.  
* **Doctor Role:** Uploads the AI diagnosis for their assigned patient including the SHA-256 hash of the retinal image, the model's prediction, the confidence score, and a hash of the model file itself. The doctor then records their own decision whether they agreed with the AI or overrode it, along with clinical notes. These are two separate on-chain records, making the human review step mandatory and auditable.  
* **Patient Role:** Controls their own consent for cross-hospital data sharing. Within the hospital, the doctor always has access to their patient's records. If the patient visits another hospital and consents to sharing, authorized external doctors can view the records. The patient can revoke this consent at any time.

### Security Mechanism:

**Tamper Verification:** Works by recomputing the SHA-256 hash of the original retinal image and comparing it against what is stored on-chain. If the image has been modified in any way, the hashes will not match and the discrepancy is immediately detectable.

### END-TO-END FLOW

1. **Registration:** Admin registers a patient and assigns a doctor. The patient is given their account identifier to log into the system.  
2. **Inference and Review:** The doctor selects the patient, and a previously unused retinal image is automatically selected from the test pool, each image is tracked to prevent reuse. The model runs inference and displays the result and confidence score on screen. The doctor reviews this, records whether they agree or override, and adds clinical notes. Both the AI prediction and the doctor decision are written to the blockchain in a single interaction.  
3. **Patient Access:** The patient can log in at any time to view their diagnosis records and their doctor's decisions. They can also manage their cross-hospital consent status.

### LIMITATIONS

* **Simulated Authentication:** Authentication in this proof of concept is simulated, a user selects their account number, and the system trusts the selection. In production, each participant would authenticate using a cryptographic private key signature, making impersonation impossible.  
* **Local Volatile Network:** The system runs on a local private network (Hardhat/Anvil). Every session starts fresh, previous blockchain data does not persist across network restarts.  
* **Data Privacy Boundaries:** Patient personal details (name, age, medical history) are not stored on-chain, only identifiers and cryptographic hashes. A production system would pair the blockchain layer with an encrypted off-chain database for personal data, with the blockchain enforcing access control at the API level.  
* **Cross-Hospital Scope:** Cross-hospital consent and external doctor authorization are implemented in the smart contract but cannot be meaningfully tested in a single-hospital simulation environment. These features are designed for a multi-hospital consortium deployment.

### WHAT THIS DEMONSTRATES

A working AI screening tool for diabetic retinopathy that achieves clinically useful recall (86%) with a tuned decision threshold, integrated with a private blockchain that makes every AI prediction and every human decision permanently auditable, tamper-evident, and access-controlled — without relying on any central authority to maintain the integrity of the records.

