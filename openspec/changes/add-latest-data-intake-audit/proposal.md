## Why

The repo now has a normalized NPI runtime layout and cleaned PRN/NPA downstream path, but it still needed a reproducible intake audit for the canonical cloud-backed raw inputs under `data/`. The newest files by timestamp still included duplicate suffixed exports, inconsistent imported headers, starred numeric cells, mixed week labels, and RedCap missing-value conventions, so the change adds an audit that identifies canonical files, recommends cleaning rules, and verifies rerun readiness against the actual runtime branches.

## What Changes

- Add a read-only latest-data intake audit workflow that inventories the canonical cloud-backed raw inputs under `/Users/ncamarda/Library/CloudStorage/OneDrive-Personal/Research/endolaserless/data`, records file timestamps and duplicate-content hashes, and identifies the canonical workbook or CSV to use for each analysis input.
- Add data-quality checks targeted to the files currently consumed by `scripts/endolaserless_analysis-2.R` and `scripts/count_prn_injections.R`, including messy imported headers, starred numeric cells, inconsistent week labels, missing schedule/group fields, and RedCap NPA conventions such as `"not gradable"` and sentinel values at or above `8888`.
- Have the audit recommend canonical cleaning rules when the evidence is already clear, and use validation to align the live PRN header parser when the audit surfaces a real downstream mismatch.
- Add a prioritized follow-on project shortlist derived from the audited inputs and current outputs, with each candidate tied to the exact source files, required cleaning, and downstream artifacts it could affect, and rank a replication/cache-consistency pass first.
- Document compatibility risks for regenerated processed workbooks under runtime `processed_data`, Prism-facing exports under runtime `output`, and any `docs/*.png` mirrors that depend on those artifacts, including the fact that the old week4-only compatibility branch has been archived out of the active runtime path.

## Capabilities

### New Capabilities
- `latest-data-intake-audit`: Audit the newest cloud-backed Endolaserless input files against the current script assumptions, identify canonical raw inputs, and report concrete cleaning or path issues before rerunning the q8/q16 NPI and PRN pipelines.
- `follow-on-project-shortlist`: Produce a small, evidence-backed shortlist of follow-on analysis projects that can be spun up from the audited latest data, including readiness, cleaning dependencies, and affected workbooks or figure mirrors, with replication first.

### Modified Capabilities
- `scripts/count_prn_injections.R`: align PRN visit-header normalization with the audited raw `prn_injections.xlsx` sheet so headers like `20 wk post op` and `1-2 wk post-op` are parsed into the active workflow instead of being left as drift.

## Impact

- Affected scripts: `scripts/endolaserless_analysis-2.R`, `scripts/count_prn_injections.R`, and the new audit helper script under `scripts/latest_data_intake_audit.R`.
- Affected external inputs: `Stats Wisconsin (Nick Edited).xlsx`, `prn_injections.xlsx`, `2024-10-22 Endolaserless_RedCap_Data.xlsx`, and duplicate-content timestamped files under the top-level cloud `data` root.
- Affected outputs: cached processed workbooks under runtime `processed_data/npi_project`, PRN workbooks under runtime `output/npi_project/count_prn_injections`, Prism-facing exports under runtime `output/npi_project/output-week4_week16_baseline`, and any downstream `docs/*.png` mirrors regenerated from those outputs.
- Compatibility risk: changing canonical input selection, archiving the old week4-only processed branch, or aligning PRN header parsing can invalidate previously generated PRN summaries if the audited rerun outputs are not reviewed before publication use.
