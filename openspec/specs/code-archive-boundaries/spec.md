## ADDED Requirements

### Requirement: Use the local repo as the canonical code source
The Endolaserless workflow SHALL treat the local repo as the canonical source of code, workflow definitions, and specifications, and SHALL not rely on cloud-side script copies as the active implementation source.

#### Scenario: Cloud root contains duplicate scripts or README files
- **WHEN** the cloud project home contains script or documentation copies that differ from the local repo
- **THEN** the documented workflow SHALL name the local repo as canonical
- **AND** the cloud copies SHALL be treated as legacy snapshots, archives, or migration inputs rather than active code

#### Scenario: A collaborator needs the current workflow entry points
- **WHEN** a collaborator looks for the active NPI or neovascularization entry points
- **THEN** the documented workflow SHALL point them to the local repo scripts
- **AND** it SHALL not require executing code from the cloud archive tree

### Requirement: Restrict cloud mirroring to archival and published artifacts
The workflow SHALL define which artifacts may be mirrored from runtime into the cloud project home and SHALL exclude transient files such as logs, caches, or temporary outputs from published archive destinations.

#### Scenario: Published outputs are mirrored for a subproject
- **WHEN** a subproject mirrors shareable outputs from runtime into the cloud archive tree
- **THEN** the mirror operation SHALL copy only approved output artifacts
- **AND** it SHALL exclude transient files such as logs, caches, and scratch outputs

#### Scenario: Publication-display figures are maintained
- **WHEN** publication-display figures such as repo `docs/*.png` or cloud published outputs are refreshed
- **THEN** the workflow SHALL identify the runtime artifacts they were mirrored from
- **AND** it SHALL keep those mirrored figures separate from canonical processed workbooks
