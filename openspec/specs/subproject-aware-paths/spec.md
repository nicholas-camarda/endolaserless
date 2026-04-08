## ADDED Requirements

### Requirement: Resolve umbrella and subproject roots from one shared helper
The repo SHALL provide a shared path resolver in `scripts/project_paths.R` that returns stable local, runtime, and cloud roots for the umbrella Endolaserless analysis and for each supported subproject.

#### Scenario: Default roots are used locally
- **WHEN** no `ENDOLASERLESS_CODE_ROOT`, `ENDOLASERLESS_RUNTIME_ROOT`, or `ENDOLASERLESS_CLOUD_ROOT` overrides are set
- **THEN** the resolver SHALL return the canonical local repo, runtime, and cloud roots for the umbrella project
- **AND** the resolver SHALL expose subproject paths for at least `npi_project` and `neovascularization_project`

#### Scenario: Environment overrides are set
- **WHEN** one or more `ENDOLASERLESS_*_ROOT` overrides are set
- **THEN** the resolver SHALL honor those overrides
- **AND** the derived umbrella and subproject paths SHALL be recomputed from the overridden roots

### Requirement: Preserve NPI compatibility while adding subproject support
The shared path resolver SHALL preserve the path fields required by the current NPI scripts while adding new subproject-aware fields for the broader umbrella repo.

#### Scenario: Existing NPI script uses the resolver
- **WHEN** `scripts/endolaserless_analysis-2.R` or `scripts/count_prn_injections.R` calls the shared path resolver
- **THEN** the resolver SHALL still provide the fields needed for the current NPI workflow
- **AND** any changed default path SHALL be documented as part of the migration

#### Scenario: Neovascularization scaffold uses the resolver
- **WHEN** a local neovascularization scaffold or helper calls the shared path resolver
- **THEN** the resolver SHALL provide raw, processed, output, archive, notes, and published roots for the neovascularization track
- **AND** those roots SHALL stay consistent with the umbrella runtime and cloud homes
