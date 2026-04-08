## ADDED Requirements

### Requirement: Produce a prioritized follow-on project shortlist
The change SHALL produce a follow-on project shortlist derived from the audited latest data and current runtime artifacts, with each candidate project prioritized by readiness and tied to the exact inputs and outputs it would affect.

#### Scenario: Audit identifies ready-to-start analyses
- **WHEN** the intake audit finds candidate analyses whose required inputs are present and whose blocking cleaning issues are absent or already handled
- **THEN** the shortlist SHALL mark those analyses as ready to start
- **AND** the shortlist SHALL identify the exact raw files, processed workbooks, and downstream outputs involved
- **AND** it SHALL rank a replication or cache-consistency pass ahead of new substantive analyses when that pass is ready

#### Scenario: Audit identifies blocked analyses
- **WHEN** a candidate follow-on project depends on unresolved cleaning issues, path mismatches, or stale caches
- **THEN** the shortlist SHALL mark that project as blocked
- **AND** the shortlist SHALL name the blocking issue
- **AND** the shortlist SHALL state what must be resolved before implementation

### Requirement: Classify project claims and methodological scope
Each candidate project in the shortlist SHALL state whether its primary claim type is descriptive, associational, causal, or predictive, and SHALL avoid presenting causal or predictive work as ready when the audited data and current code only support descriptive or associational analysis.

#### Scenario: A project idea is descriptive
- **WHEN** a candidate project only summarizes q8/q16 NPI, NPA, cumulative injections, PRN injections, leakage, or visit-level completeness from the audited inputs
- **THEN** the shortlist SHALL classify it as descriptive
- **AND** the shortlist SHALL identify the exact audited artifacts needed to produce it

#### Scenario: Replication is the first-priority project
- **WHEN** the audit finds that canonical inputs and normalized runtime outputs are available for verification
- **THEN** the shortlist SHALL rank a replication or cache-consistency pass as the first-priority follow-on project
- **AND** it SHALL identify the processed workbooks and output directories that the replication pass would validate

#### Scenario: A project idea extends beyond current support
- **WHEN** a candidate project would require causal inference, prediction modeling, or data not represented in the audited workbooks and runtime artifacts
- **THEN** the shortlist SHALL classify it as not currently supported
- **AND** the shortlist SHALL explain the missing design, data, or validation requirements

### Requirement: Tie project ideas to concrete artifact risk
Each shortlisted project SHALL identify the processed workbooks, Prism-facing exports, and `docs/*.png` mirrors that could change if the project is implemented, so downstream compatibility risk is visible before work starts.

#### Scenario: A project would change downstream artifacts
- **WHEN** a candidate project reuses outputs from `scripts/endolaserless_analysis-2.R` or `scripts/count_prn_injections.R`
- **THEN** the shortlist SHALL name the affected processed workbook or output directory
- **AND** the shortlist SHALL state whether `docs/*.png` mirrors would need review or regeneration

#### Scenario: A project is exploratory only
- **WHEN** a candidate project is purely exploratory and would not alter the current publication-facing outputs
- **THEN** the shortlist SHALL mark the project as not affecting existing figure mirrors
- **AND** the shortlist SHALL still identify the raw and runtime artifacts it depends on
