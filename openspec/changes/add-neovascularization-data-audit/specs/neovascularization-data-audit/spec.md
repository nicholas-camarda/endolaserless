## ADDED Requirements

### Requirement: Inventory neovascularization source workbooks
The workflow SHALL inventory cloud-backed Endolaserless spreadsheet inputs that may contain neovascularization, NVD, NVE, or leakage data, and SHALL distinguish duplicate-content exports from distinct source files using file metadata and content hashes.

#### Scenario: Duplicate suffixed exports are present
- **WHEN** a suffixed workbook or CSV under the top-level cloud `data/` root has the same content hash as an unsuffixed source file
- **THEN** the inventory SHALL report the files as duplicate-content exports
- **AND** it SHALL not treat the newer timestamp alone as evidence of new data

### Requirement: Parse active-neovascularization summary endpoint
The workflow SHALL parse `Laserless Study DATA Updated for 3 Year Data (1).xlsx` sheet `FAFundus Readout` into a subject-level processed table using `Presence of active neovascularization: Yes, No, Missed` as the primary descriptive endpoint.

#### Scenario: FAFundus Readout contains group marker rows and embedded subject labels
- **WHEN** parsing the sheet
- **THEN** the workflow SHALL fill q8/q16 schedule from section markers
- **AND** it SHALL normalize embedded `L` subject identifiers to the `L-##` format
- **AND** it SHALL exclude section headers and rows without endpoint evidence from the processed table

### Requirement: Build raw longitudinal endpoint context
The workflow SHALL parse raw RedCap/Wisconsin NVD, NVE, and retinal vascular leakage fields into a cleaned longitudinal table for descriptive context and endpoint reconciliation.

#### Scenario: Raw endpoint fields include cannot-grade or sentinel values
- **WHEN** raw categorical fields contain `Cannot Grade`, missed visits, or blanks
- **THEN** the workflow SHALL preserve those values as explicit status fields where applicable
- **AND** it SHALL clean numeric leakage sentinel values at or above the relevant missing-value threshold to missing in derived numeric columns

### Requirement: Reconcile summary and raw endpoint evidence
The workflow SHALL compare each parsed active-neovascularization summary row with the subject's latest available raw NVD/NVE evidence and report agreement, discordance, and insufficient raw evidence.

#### Scenario: Summary endpoint says active neovascularization is present
- **WHEN** the latest raw NVD or NVE evidence for that subject is definite/present
- **THEN** the reconciliation SHALL mark the sources as concordant
- **WHEN** the latest raw evidence is absent or cannot be evaluated
- **THEN** the reconciliation SHALL mark discordance or insufficient raw evidence instead of silently treating the summary as validated

### Requirement: Report descriptive feasibility only
The workflow SHALL emit a feasibility report that classifies endpoint readiness and explicitly limits conclusions to descriptive source inventory, endpoint counts, and reconciliation.

#### Scenario: Endpoint counts are too sparse for comparative modeling
- **WHEN** NVD or NVE event counts are sparse or concentrated in few subjects
- **THEN** the report SHALL classify those endpoints as descriptive or sparse
- **AND** it SHALL not recommend causal, predictive, survival, equivalence, or q8/q16 efficacy modeling from this change's outputs
