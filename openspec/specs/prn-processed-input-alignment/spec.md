## ADDED Requirements

### Requirement: Align the PRN workflow to the canonical processed NPI input
The PRN injection workflow SHALL read its processed NPI input from the canonical active NPI processed branch instead of from a stale week4-only compatibility branch.

#### Scenario: PRN script runs after the NPI pipeline
- **WHEN** `scripts/count_prn_injections.R` runs after `scripts/endolaserless_analysis-2.R`
- **THEN** it SHALL read `cached_long_input_data.xlsx` from `processed_data/npi_project/output-week4_week16_baseline`
- **AND** it SHALL use that refreshed workbook when computing cumulative injections, PRN rescue injections, NPA summaries, and downstream exports

#### Scenario: Canonical processed workbook is missing
- **WHEN** `scripts/count_prn_injections.R` cannot find the canonical processed workbook under `processed_data/npi_project/output-week4_week16_baseline`
- **THEN** the workflow SHALL fail explicitly rather than silently falling back to `processed_data/npi_project/output-week4_baseline`
- **AND** the error path SHALL make the missing dependency on the upstream NPI rerun clear

### Requirement: Preserve downstream workbook continuity during path normalization
The normalized PRN workflow SHALL validate that its downstream runtime outputs still refresh correctly after the input-path change.

#### Scenario: PRN outputs are regenerated from the canonical branch
- **WHEN** the normalized workflow reruns `scripts/count_prn_injections.R`
- **THEN** it SHALL refresh `processed_data/npi_project/FINAL_PROCESSED-npi_plus_all_injection_data.xlsx`
- **AND** it SHALL refresh the expected PRN workbooks under `output/npi_project/count_prn_injections`

#### Scenario: Downstream compatibility is reviewed after the rerun
- **WHEN** refreshed PRN workbooks are compared to prior runtime artifacts
- **THEN** the change validation SHALL record whether Prism-facing exports or figure mirrors need manual updates
- **AND** the compatibility-only week4 branch SHALL not be removed until that review is complete

### Requirement: Clean invalid NPA values before exporting PRN-adjacent summaries
The PRN workflow SHALL treat invalid RedCap NPA entries as missing before writing NPA summary workbooks or grouped means.

#### Scenario: RedCap NPA field contains explicit invalid tokens
- **WHEN** `scripts/count_prn_injections.R` reads `Nonperfusion area within eye` from `2024-10-22 Endolaserless_RedCap_Data.xlsx`
- **THEN** values such as `"not gradable"` SHALL be converted to missing
- **AND** numeric sentinel-like values at or above `8888` SHALL be converted to missing before export

#### Scenario: Cleaned NPA workbook is written
- **WHEN** `npa_by_week.xlsx` and grouped NPA means are regenerated
- **THEN** the exported workbook SHALL not contain the raw invalid tokens or sentinel values
- **AND** grouped NPA summaries SHALL operate on cleaned numeric values rather than mixed character data
