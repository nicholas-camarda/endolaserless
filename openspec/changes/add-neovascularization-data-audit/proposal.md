## Why

The neovascularization track is currently scaffold-only, but the cloud source tree contains usable neovascularization-adjacent data outside that placeholder folder. A reproducible audit is needed now to distinguish duplicate workbook exports from genuinely distinct sources, parse the collaborator-facing active-neovascularization summary, reconcile it against raw Wisconsin/RedCap NVD/NVE/leakage fields, and decide what descriptive analysis is supportable before any manuscript-facing claims are made.

## What Changes

- Add a script-first neovascularization intake audit that inventories cloud Excel/CSV sources, records file metadata and hashes, and flags duplicate-content suffixed exports separately from distinct source workbooks.
- Parse `Laserless Study DATA Updated for 3 Year Data (1).xlsx`, sheet `FAFundus Readout`, as the primary subject-level active-neovascularization summary source.
- Parse raw longitudinal NVD, NVE, and retinal vascular leakage fields from the RedCap/Wisconsin source workbooks as validation and descriptive context.
- Produce processed runtime datasets plus a feasibility report under the neovascularization runtime roots, without mutating source Excel files or existing NPI/PRN outputs.
- Enforce a descriptive-only claim posture: counts, source agreement, endpoint sparsity, and feasibility/readiness conclusions are allowed; treatment-effect, causal, and predictive claims are not.

## Capabilities

### New Capabilities
- `neovascularization-data-audit`: Inventory neovascularization source workbooks, build a processed active-neovascularization summary and raw longitudinal endpoint dataset, reconcile endpoint evidence across sources, and report descriptive feasibility.

### Modified Capabilities
- None.

## Impact

- Affected scripts: new audit entry point under `scripts/`; existing `scripts/project_paths.R` and `scripts/neovascularization_project.R` path helpers are reused but not changed unless validation exposes a path mismatch.
- Affected external inputs: `Laserless Study DATA Updated for 3 Year Data (1).xlsx`, `2024-10-22 Endolaserless_RedCap_Data.xlsx`, `Wisconsis_study_data_analysis_FAgradng_MASTERsheet7.10.24.xlsm`, historical Wisconsin/RedCap workbook copies under `data/old`, and duplicate-content suffixed exports under the top-level cloud `data` root.
- Affected outputs: new runtime artifacts under `processed_data/neovascularization_project` and `output/neovascularization_project`; no existing NPI processed workbooks, PRN outputs, Prism-facing exports, or `docs/*.png` mirrors are modified.
- Compatibility risk: the audit may show that prior `neovascularization_project/output/published/model_summary_combined.xlsx` is stale or methodologically unsafe, but this change does not overwrite that published mirror.
