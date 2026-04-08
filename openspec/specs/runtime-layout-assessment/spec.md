## ADDED Requirements

### Requirement: Inventory the active runtime tree
The repo SHALL provide a runtime-layout assessment that inventories the active directories and key workbooks under `~/ProjectsRuntime/endolaserless` and records their role in the current workflow.

#### Scenario: NPI runtime tree is assessed
- **WHEN** the assessment runs against the current runtime root
- **THEN** it SHALL inventory the major directories under `processed_data/npi_project` and `output/npi_project`
- **AND** it SHALL identify key workbooks such as cached inputs, processed summaries, and PRN exports

#### Scenario: A runtime path is not present
- **WHEN** an expected runtime directory or workbook is missing
- **THEN** the assessment SHALL record it as missing
- **AND** it SHALL state whether the path is expected from current scripts or only from historical layout

### Requirement: Map runtime artifacts to producers and consumers
The assessment SHALL tie each important runtime folder or workbook to the scripts that produce it, consume it, or mirror it.

#### Scenario: A runtime workbook is produced and consumed
- **WHEN** a workbook is written by one script and later read by another
- **THEN** the assessment SHALL identify the producer script and consumer script
- **AND** it SHALL record the relevant runtime path

#### Scenario: A runtime artifact has no current script reference
- **WHEN** a runtime path is not referenced by active scripts
- **THEN** the assessment SHALL flag it as a potential legacy or unresolved artifact
- **AND** it SHALL not treat the path as canonical without additional evidence
