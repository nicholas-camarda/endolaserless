## ADDED Requirements

### Requirement: Audit canonical analysis inputs
The repo SHALL provide a latest-data intake audit that inspects the top-level cloud-backed raw input files under `data/` required by `scripts/endolaserless_analysis-2.R` and `scripts/count_prn_injections.R`, records file metadata for candidate inputs, and identifies the canonical source file to use for each required analysis input.

#### Scenario: Duplicate export files are present
- **WHEN** the audit finds two or more candidate files with different filenames but identical content hashes for the same raw input
- **THEN** the audit SHALL report them as duplicate exports
- **AND** the audit SHALL select one canonical file according to a documented rule
- **AND** the audit SHALL record the non-canonical duplicates without treating them as new data

#### Scenario: Historical files exist outside the canonical intake scope
- **WHEN** related files exist under `data/old` or another historical subdirectory
- **THEN** the audit SHALL not treat them as equal canonical candidates for the active workflow by default
- **AND** it SHALL mention them only as historical alternates or context when relevant

#### Scenario: A required input is missing
- **WHEN** the audit cannot find a required raw workbook or CSV needed by the current q8/q16 NPI or PRN workflows
- **THEN** the audit SHALL mark the input as missing
- **AND** the audit SHALL identify which script depends on that input
- **AND** the audit SHALL mark the audit as not ready for rerun

### Requirement: Validate workbook compatibility and cleaning needs
The intake audit SHALL validate the structure and values of the canonical raw inputs against the assumptions currently embedded in the analysis scripts, including required sheets, required columns, mixed week labels, starred numeric cells, missing schedule or group fields, and sentinel or non-numeric values that require explicit cleaning.

#### Scenario: Stats Wisconsin workbook contains non-numeric week cells
- **WHEN** the canonical `Stats Wisconsin (Nick Edited).xlsx` workbook contains `Week` cells with text markers such as `N/A`, `missed visit`, or starred numeric strings
- **THEN** the audit SHALL report those fields as requiring cleaning or coercion before the main NPI pipeline is rerun
- **AND** the audit SHALL identify the affected sheet and columns used by `scripts/endolaserless_analysis-2.R`

#### Scenario: PRN workbook contains inconsistent week column labels
- **WHEN** the canonical `prn_injections.xlsx` workbook contains week columns that vary in spelling or spacing such as `wk`, `week`, or `post op`
- **THEN** the audit SHALL report the normalization rule required for those columns
- **AND** the audit SHALL identify whether the current PRN script logic can still parse them

#### Scenario: Validation exposes a live PRN parsing gap
- **WHEN** the audit shows that an active `prn_injections.xlsx` header with real PRN marker cells is not being normalized into the downstream PRN workflow
- **THEN** the change SHALL align `scripts/count_prn_injections.R` with the audited normalization rule before the workflow is marked rerun-ready
- **AND** the rerun-ready audit state SHALL reflect that alignment

#### Scenario: RedCap workbook contains incomplete grouping or sentinel values
- **WHEN** the canonical `2024-10-22 Endolaserless_RedCap_Data.xlsx` workbook contains missing `Group` values outside the first subject row or sentinel values used to represent missing NPA
- **THEN** the audit SHALL report the affected fields and rows
- **AND** the audit SHALL state whether `scripts/count_prn_injections.R` already handles the issue or requires code changes

#### Scenario: Clear missing-value conventions are present in RedCap NPA
- **WHEN** the audit finds explicit `Nonperfusion area within eye` values such as `"not gradable"` or numeric values at or above `8888`
- **THEN** the audit SHALL recommend treating those values as missing
- **AND** it SHALL report the counts and example rows that support that recommendation

### Requirement: Keep the intake audit read-only while recommending clear rules
The intake audit SHALL report findings and recommended cleaning assumptions without mutating raw inputs or silently changing script behavior.

#### Scenario: Evidence supports a canonical cleaning rule
- **WHEN** the audit finds a repeated data convention that is clearly acting as a missing-value or formatting sentinel
- **THEN** the audit SHALL recommend the canonical cleaning rule in its report
- **AND** it SHALL keep the audit itself read-only
- **AND** it SHALL identify which downstream script or output would be affected if the recommendation is adopted

### Requirement: Detect path drift and stale processed-workbook dependencies
The intake audit SHALL compare configured code, runtime, and cloud roots with the artifact locations that actually exist and SHALL warn when the current canonical inputs or downstream artifacts appear inconsistent with the active normalized workflow.

#### Scenario: Canonical runtime artifacts are older than expected
- **WHEN** the audit inspects the active runtime artifacts used by the normalized NPI and PRN workflows
- **THEN** it SHALL report whether the canonical processed and output branches look current enough for rerun comparison
- **AND** it SHALL identify which reruns would be needed before a replication pass can be treated as ready

#### Scenario: Compatibility-only processed branch is no longer active
- **WHEN** the audit and downstream reruns confirm that the PRN workflow uses the canonical processed branch rather than the old week4-only compatibility branch
- **THEN** the active runtime tree SHALL no longer require `processed_data/npi_project/output-week4_baseline`
- **AND** the audit SHALL report that compatibility branch as absent from the active runtime path
