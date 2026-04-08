## 1. Audit Scaffold And Path Alignment

- [x] 1.1 Add a repo-local audit entry point under `scripts/` that resolves roots through `scripts/project_paths.R` and inventories candidate raw inputs under the cloud `data` root.
- [x] 1.2 Keep the audit read-only and have it emit recommended cleaning rules and rerun-readiness findings without mutating raw inputs or existing analysis scripts.
- [x] 1.3 Update the change-local audit/report expectations so they refer to the already normalized runtime layout instead of reopening path-default cleanup.

## 2. File-Level Intake Checks

- [x] 2.1 Implement canonical-file selection logic for the required raw inputs using file metadata plus content hashes within the top-level cloud `data/` directory, and report duplicate-content suffixed exports separately from true new data.
- [x] 2.2 Add workbook checks for `Stats Wisconsin (Nick Edited).xlsx` sheet 6 covering expected columns, non-numeric `Week` cells, starred numeric strings, and q8/q16 subject coverage used by `scripts/endolaserless_analysis-2.R`.
- [x] 2.3 Add workbook checks for `prn_injections.xlsx` sheet 1 covering mixed week-label formats, PRN marker cells, and the subject/group fields used by `scripts/count_prn_injections.R`.
- [x] 2.4 Add workbook checks for `2024-10-22 Endolaserless_RedCap_Data.xlsx` covering expected columns, missing `Group` values, and NPA-related missing-value handling used downstream in `scripts/count_prn_injections.R`, including `"not gradable"` and values `>= 8888`.
- [x] 2.5 Align the live PRN visit-header normalization with the audited raw workbook when validation shows real PRN marker cells under headers that the current parser misses.

## 3. Stale Cache Detection And Project Shortlist

- [x] 3.1 Add a runtime-readiness audit that inspects the already normalized canonical NPI and PRN artifact branches, including timestamps and rerun-readiness warnings for a replication pass.
- [x] 3.2 Write the audit report to the runtime output tree with the canonical inputs, cleaning issues, recommended rules, and rerun readiness summary.
- [x] 3.3 Generate a short follow-on project shortlist from the audit results, and for each project record claim type, readiness tier, blocking issues, exact input files, affected processed workbooks, and any `docs/*.png` mirror risk, with replication/cache-consistency ranked first.

## 4. Validation

- [x] 4.1 Run the intake audit against the current cloud and runtime roots and confirm it flags the known duplicate raw exports, recognizes the normalized runtime layout, and recommends the known NPA cleaning rule.
- [x] 4.2 If the audit indicates rerun-ready inputs, rerun `scripts/endolaserless_analysis-2.R` and verify the regenerated processed workbooks under runtime `processed_data/npi_project`.
- [x] 4.3 Rerun `scripts/count_prn_injections.R` against the reconciled processed workbook path and verify the downstream PRN outputs under runtime `output/npi_project/count_prn_injections`.
- [x] 4.4 Review any affected Prism-facing exports or `docs/*.png` mirrors and document whether they remain current or need regeneration after the audited rerun.
- [x] 4.5 Archive the obsolete week4-only compatibility processed branch out of the active runtime tree once rerun validation confirms it is no longer needed.
