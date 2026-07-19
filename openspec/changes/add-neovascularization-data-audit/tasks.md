## 1. OpenSpec Artifacts

- [x] 1.1 Create the proposal, design, spec, and tasks artifacts for the neovascularization data audit change.

## 2. Script And Source Inventory

- [x] 2.1 Add a repo-local neovascularization data audit entry point under `scripts/` that resolves roots through `scripts/project_paths.R`.
- [x] 2.2 Implement spreadsheet inventory and duplicate-hash reporting across current cloud `data/` files, relevant `data/old` workbooks, and existing neovascularization published mirrors.

## 3. Endpoint Dataset Generation

- [x] 3.1 Parse `FAFundus Readout` into a normalized active-neovascularization summary table with q8/q16 schedule, normalized subject IDs, FA dates, active NV status, and FA NV change.
- [x] 3.2 Parse raw RedCap/Wisconsin NVD, NVE, and leakage fields into a cleaned longitudinal endpoint table, excluding non-study rows such as `TEST`.
- [x] 3.3 Reconcile the active-neovascularization summary against each subject's latest available raw NVD/NVE evidence and classify concordance, discordance, or insufficient raw evidence.

## 4. Reporting And Validation

- [x] 4.1 Write processed CSV outputs and a descriptive feasibility report under the neovascularization runtime processed/output roots.
- [x] 4.2 Run the audit against the current cloud and runtime roots and verify the expected active-neovascularization counts, duplicate-export findings, raw endpoint sparsity, and descriptive-only claim posture.
- [x] 4.3 Confirm OpenSpec apply status shows all tasks complete and note any residual data limitations.
