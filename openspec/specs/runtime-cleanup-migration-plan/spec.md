## ADDED Requirements

### Requirement: Recommend a canonical runtime layout
The assessment SHALL recommend a canonical runtime layout for the Endolaserless workspace that distinguishes intermediate processed workbooks from final exported outputs and from local runtime archives.

#### Scenario: Canonical layout is proposed
- **WHEN** the assessment completes
- **THEN** it SHALL recommend which runtime folders should remain active under `processed_data/<subproject>` and `output/<subproject>`
- **AND** it SHALL identify which runtime folders should be archived, retained temporarily, or reviewed further

#### Scenario: Current scripts do not match the recommended layout
- **WHEN** the recommended canonical layout differs from current script read or write paths
- **THEN** the assessment SHALL identify the affected scripts
- **AND** it SHALL state that cleanup requires a follow-on implementation change rather than silent folder moves

### Requirement: Produce a migration safety checklist
The assessment SHALL include a migration safety checklist that names compatibility risks for processed workbooks, downstream PRN outputs, Prism-facing exports, and mirrored `docs/*.png` or published assets.

#### Scenario: A cleanup step could break the PRN pipeline
- **WHEN** removing or renaming a runtime path would affect `scripts/count_prn_injections.R`
- **THEN** the assessment SHALL identify that risk explicitly
- **AND** it SHALL describe the validation needed before the cleanup is implemented

#### Scenario: A cleanup step affects mirrored assets
- **WHEN** a runtime path is upstream of repo figure mirrors or cloud published outputs
- **THEN** the assessment SHALL record those downstream artifacts
- **AND** it SHALL require provenance review before cleanup
