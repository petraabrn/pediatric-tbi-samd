# pediatric-tbi-samd

**PhenoMap**
_Pediatric TBI Subphenotyping SaMD_

A MATLAB-based Software as a Medical Device (SaMD) designed for tertiary trauma centers, emergency departments, and PICUs. PhenoMap moves beyond subjective Glasgow Coma Scale (GCS) assessments by evaluating 0–24h acute inflammatory and CNS injury biomarker trajectories to discover latent, clinically actionable pediatric TBI recovery phenotypes.

**1. BACKGROUND**
- **Unmet Needs:** Conventional clinical scores (GCS) and standard neuroimaging often fail to resolve active secondary neuroinflammation, particularly in non-verbal or pediatric populations.
- **Value Proposition:** PhenoMap establishes an objective, biomarker-driven framework that classifies acute trauma heterogeneity into data-driven subphenotypes within the first 24 hours post-injury to inform early neuroprotective intervention.
- **Target Classification:** Class II (Special Controls) via FDA De Novo Pathway (Human-in-the-Loop decision support).

**2. ML PIPELINE**
Raw Patient Inputs (51 pts)
│  • Biomarkers (0h & 24h pooled): ASC, Caspase-1, IL-1β, Tau, GFAP, UCH-L1, NFL, p-Tau
│  • Clinical & Demographics: GCS, Age, Weight, Body Surface Area (BSA)
▼
Preprocessing
│  • Log-transform for skewed outlier distributions
│  • One-hot & binary categorical encoding
│  • KNN imputation for missing biomarker entries (<30% threshold)
│  • Z-score standardization
▼
Dimensionality Reduction (PCA)
│  • Retained top 3 Principal Components explaining ~80% cumulative variance
│  • PC1 (Injury Axis): Positive loading on UCH-L1, NFL, GFAP; inverse loading on GCS
│  • PC2 / PC3 (Demographic Axes): Driven by Age, Weight, and BSA (orthogonal to injury severity)
│  • Visual benchmarking: Evaluated alongside non-linear projections (UMAP, t-SNE)
▼
Unsupervised Clustering (PAM / k-Medoids)
│  • Model Selection: Evaluated k=6 (mathematical optimum) vs. k=3 (clinically actionable)
│  • Selection Rationale: k=6 suffered from micro-clusters prone to outcome hijacking; k=3 maintained 
│    comparable cluster separation (Silhouette ≈ 0.38 vs. 0.193 Folweiler benchmark) while providing 
│    sufficient statistical power per arm
▼
Supervised Validation & Feature Attribution
   • Random Forest (TreeBagger) Multiclass OOB Error: 0.089 (91.1% Classification Accuracy)
   • Permutation feature importance (SHAP-equivalent) & One-vs-Rest distinct profile isolation

**3. IDENTIFIED SUBPHENOTYPES**
- **Phenotype 1 (Low Injury / High GCS):** Characterized by uniformly suppressed acute biomarkers (NFL, Tau, GFAP, UCH-L1 below population means) alongside well-preserved baseline GCS scores. Driven primarily by the absence of structural neurotrauma markers, this cohort consistently demonstrates favorable long-term functional recovery at 12 months.
- **Phenotype 2 (Older / Larger Cohort):** Distinctly separated by patient habitus and development rather than primary injury severity, presenting with high age, weight, and body surface area (BSA). Biomarkers show intermediate, isolated elevations in GFAP and Tau with stable GCS, reflecting an age-dependent injury profile and intermediate recovery trajectories.
- **Phenotype 3 (Severe Acute Neurotrauma):** Defined by young, low-weight patients exhibiting critical injury signatures: profoundly depressed GCS paired with marked acute spikes across structural and inflammatory markers (UCH-L1, NFL, GFAP). This group carries the highest risk profile and correlates with significantly poorer long-term GOS-E recovery outcomes, indicating an urgent need for early neuroprotective intervention.

**4. VALIDATION**
- Long-Term Prognostic Separation (6–12 Months): k=3 partitioning achieved statistically significant separation on 12-month GOS-E Peds scores (_p_ = 0.0286, Kruskal-Wallis).
- Clinical Utility vs. Overfitting (k=3 vs. k=6): While k=6 demonstrated early short-term separation (2–6 weeks, _p_ = 0.0283), significance eroded over time due to small-cluster overfitting. Constraining the model to k=3 captured true, durable recovery trajectories, providing a quantitative basis for early critical-care escalations.

**5. DESIGN CONTROLS**
Clinical App Designer Interface: Built with a clinician-facing GUI incorporating:
- Dynamic Pareto explanation plots illustrating individual patient feature attribution.
- Phenotype cohort heatmaps mapping the patient's acute vector against reference bounds.
-Safety interlock logic preventing prediction generation if missing biomarker fields exceed safe thresholds.

Risk Management & Design Traceability: Structured under IEC 62304 (Medical device software lifecycle) and ISO 14971 risk management standards:
- Traceability matrix mapping 10 identified clinical/technical software hazards to software safety mitigations.
- Verification protocols designed for clinical decision support audit trails.
