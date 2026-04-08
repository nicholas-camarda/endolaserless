## ADDED Requirements

### Requirement: Use one canonical processed branch for the active NPI pipeline
The Endolaserless NPI workflow SHALL treat `processed_data/npi_project/output-week4_week16_baseline` as the canonical processed workbook branch for the active local pipeline.

#### Scenario: Main NPI pipeline refreshes processed workbooks
- **WHEN** `scripts/endolaserless_analysis-2.R` is rerun against the current cloud `data` inputs
- **THEN** it SHALL refresh the active cached NPI workbooks under `processed_data/npi_project/output-week4_week16_baseline`
- **AND** the normalized workflow SHALL not require `processed_data/npi_project/output-week4_baseline` to be refreshed as a second active branch

#### Scenario: Legacy branch remains present during migration
- **WHEN** `processed_data/npi_project/output-week4_baseline` still exists in runtime during the transition
- **THEN** the workflow SHALL classify it as compatibility-only or archive-only rather than as the canonical processed destination
- **AND** the change documentation SHALL state why that branch is being retained temporarily

### Requirement: Distinguish canonical output paths from runtime archive branches
The NPI workflow SHALL identify which runtime `output` and `processed_data` branches are active destinations versus runtime archive history.

#### Scenario: A collaborator inspects the runtime layout
- **WHEN** a collaborator reviews the NPI runtime layout after normalization
- **THEN** the workflow documentation SHALL identify `output/npi_project/output-week4_week16_baseline` and `output/npi_project/count_prn_injections` as active output destinations
- **AND** it SHALL distinguish `processed_data/npi_project/archive` and `output/npi_project/archive` as archive-only branches

#### Scenario: Derived publication-display assets are reviewed
- **WHEN** repo `docs/*.png` or Prism-facing tables are refreshed or reviewed after normalization
- **THEN** the workflow SHALL treat them as derived mirrors of runtime outputs
- **AND** it SHALL not treat those mirrors as the canonical source of processed NPI data
