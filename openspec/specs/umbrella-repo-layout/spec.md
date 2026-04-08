## ADDED Requirements

### Requirement: Represent Endolaserless as an umbrella analysis repo
The local repo SHALL document and expose Endolaserless as a multi-subproject analysis codebase with shared infrastructure plus explicit NPI and neovascularization tracks.

#### Scenario: Repo documentation describes the project layout
- **WHEN** a collaborator reads the local repo documentation
- **THEN** the documentation SHALL identify the umbrella roots shared across the study
- **AND** the documentation SHALL distinguish the NPI track from the neovascularization track
- **AND** the documentation SHALL state which track is analysis-ready versus scaffold-only

#### Scenario: Local repo includes the neovascularization track
- **WHEN** a collaborator inspects the local `scripts/` workflow entry points
- **THEN** the repo SHALL include a local neovascularization scaffold or helper
- **AND** that scaffold SHALL use the same shared path conventions as the NPI scripts

### Requirement: Separate shared versus subproject-specific assets
The repo SHALL define which artifacts belong to shared umbrella roots and which belong to specific subprojects across local, runtime, and cloud storage.

#### Scenario: Shared study inputs are referenced
- **WHEN** a script needs study-wide raw inputs reused by multiple tracks
- **THEN** the workflow SHALL resolve those inputs from the umbrella cloud `data` root
- **AND** the documentation SHALL not require duplicate raw copies inside each subproject

#### Scenario: Subproject-specific outputs are produced
- **WHEN** NPI or neovascularization outputs are regenerated
- **THEN** runtime processed outputs SHALL land under the matching subproject directory
- **AND** archive or published copies SHALL land under the matching cloud subproject directory
