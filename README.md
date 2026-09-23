# PhenoMap: Pediatric TBI Subphenotyping SaMD

> **A MATLAB-based Software as a Medical Device (SaMD) leveraging acute 0–24h biomarker trajectories and unsupervised-to-supervised machine learning to stratify pediatric traumatic brain injury recovery phenotypes.**

PhenoMap is an objective, biomarker-driven clinical decision support pipeline designed for tertiary trauma centers, emergency departments, and pediatric intensive care units (PICUs). Conventional triage relies heavily on subjective Glasgow Coma Scale (GCS) scoring and acute neuroimaging, which frequently fail to capture secondary neuroinflammation and injury evolution in pediatric and non-verbal populations. 

PhenoMap resolves acute patient heterogeneity within 24 hours of admission to stratify latent recovery trajectories and inform early neuroprotective intervention.

* **Regulatory Classification:** Class II (Special Controls) via FDA De Novo Pathway (Human-in-the-Loop Clinical Decision Support).
* **Compliance Standards:** Structured under IEC 62304 (Medical Device Software Lifecycle) and ISO 14971 (Application of Risk Management).

---

## 1. System & Machine Learning Pipeline

```text
       [ Raw Patient Inputs (n = 51 Cohort) ]
       • Biomarkers (0h & 24h pooled): ASC, Caspase-1, IL-1β, Tau, GFAP, UCH-L1, NFL, p-Tau
       • Clinical & Demographics: GCS, Age, Weight, Body Surface Area (BSA)
                         │
                         ▼
        [ Preprocessing & Data Hygiene ]
       • Log-transformation for right-skewed outlier distributions
       • KNN imputation for sparse biomarker fields (<30% missingness threshold)
       • One-hot / binary categorical encoding & Z-score standardization
                         │
                         ▼
      [ Dimensionality Reduction & Projections ]
       • Principal Component Analysis (Top 3 PCs explain ~80% cumulative variance)
         - PC1 (Injury Axis): High positive loadings on UCH-L1, NFL, GFAP; inverse on GCS
         - PC2 / PC3 (Demographic Axes): Orthogonal axes driven by Age, Weight, and BSA
       • Benchmarked visually against non-linear manifolds (UMAP, t-SNE)
                         │
                         ▼
     [ Unsupervised Phenotyping (PAM / k-Medoids) ]
       • Partitioning Around Medoids evaluated across k = 2 through k = 8
       • Silhouette optimization and cluster-stability cross-validation
                         │
                         ▼
   [ Supervised Validation & Feature Attribution ]
       • Random Forest (TreeBagger) Ensemble Validation
       • Out-of-Bag (OOB) Multiclass Error: 0.089 (91.1% Classification Accuracy)
       • Permutation feature importance (SHAP-equivalent) & One-vs-Rest profiling
```
## 2. Engineering Challenges & Pipeline Iterations

* **Cluster Optimization vs. Clinical Power:** An initial mathematical model selected k=6 based purely on silhouette peaks. However, k=6 fragmented the cohort into unstable micro-clusters prone to outcome hijacking, with significance eroding by month 12. Constrained the architecture to k=3, maintaining high cluster separation (Silhouette ≈ 0.38 vs. the 0.193 Folweiler benchmark) while securing statistical power that revealed statistically significant 12-month GOS-E recovery divergence (p = 0.0286).
* **Outlier Skew & Biomarker Sparsity:** Raw acute inflammatory markers displayed severe right-skewed distributions and irregular missingness across clinical labs. Implemented a combined log-transform and automated KNN imputation pipeline with a strict <30% missingness threshold, preventing distorted distance metrics during PCA projection without discarding high-acuity pediatric cases.
* **Feature Leakage & Demographics Interference:** Preliminary models entangled patient developmental metrics with acute trauma signals. Decoupled feature loadings using PCA: PC1 isolated the true acute trauma axis (UCH-L1, NFL, GFAP inversely correlated with GCS), while PC2 and PC3 isolated developmental demographics (Age, Weight, BSA), ensuring predictions reflect physiological injury rather than physical growth.
* **Clinical Interpretability & Verification:** Standard ensemble models presented as clinical "black boxes," hindering physician adoption. Built an integrated MATLAB App Designer interface with safety interlocks that block predictions if missing inputs exceed validated thresholds, while generating real-time Pareto explanation plots and cohort heatmaps for dynamic patient risk audits.

---

## 3. Discovered Clinical Subphenotypes

* **Phenotype 1 — Low Injury / High GCS (Favorable Recovery):** Characterized by uniformly suppressed acute biomarkers (NFL, Tau, GFAP, and UCH-L1 below population medians) alongside preserved baseline GCS. Driven by the absence of active structural neurotrauma, this cohort consistently demonstrates favorable functional outcomes on the GOS-E Peds scale at 12 months.
* **Phenotype 2 — Older / Larger Cohort (Intermediate Profile):** Separated predominantly along demographic axes (elevated age, weight, and BSA) rather than primary acute damage. Presents with intermediate, isolated elevations in GFAP and Tau with stable GCS scores, reflecting an age-dependent injury profile and intermediate recovery trajectories.
* **Phenotype 3 — Severe Acute Neurotrauma (High-Risk Intervention):** Defined by young, lower-weight patients presenting with critical injury signatures: profoundly depressed GCS combined with massive acute spikes across structural and inflammatory markers (UCH-L1, NFL, GFAP). Correlates with significantly worse 12-month GOS-E scores, identifying the subpopulation requiring immediate neuroprotective therapy and PICU monitoring escalation.

---

## 4. Core Technical Skills Demonstrated

* **Biomedical Data Science & ML:** Unsupervised clustering (PAM/k-Medoids), Random Forest ensembles (TreeBagger), PCA dimensionality reduction, permutation feature importance, KNN imputation, log-normal transformations.
* **Clinical Biostatistics:** Non-parametric hypothesis testing (Kruskal-Wallis), longitudinal clinical outcome correlation (GOS-E Peds at 6 and 12 months), silhouette metric benchmarking.
* **Software Architecture & SaMD Design Controls:** MATLAB App Designer GUI development, asynchronous error handling, input sanity checking, audit trail logging.
* **Regulatory & Quality Systems:** IEC 62304 software safety classification, ISO 14971 hazard identification, clinical risk analysis, and software traceability matrix documentation.

---

## 5. Repository Structure

```text
├── src/
│   ├── data/                # Raw & preprocessed clinical & biomarker inputs
│   ├── code/                # MATLAB code (.m)
│   └── gui/                 # MATLAB App Designer files (.mlapp) 
├── docs/
│   ├── regulatory/          # ISO 14971 Risk Analysis & IEC 62304 Hazard Traceability Matrix
│   └── documentation/       # Other documentation
