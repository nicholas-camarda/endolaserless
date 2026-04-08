## ADDED Requirements

### Requirement: Classify runtime folders by operational role
The runtime-layout assessment SHALL classify each important runtime folder or workbook as canonical, legacy archive, compatibility-only, duplicated, or unresolved.

#### Scenario: A path is a canonical runtime destination
- **WHEN** a current script writes a runtime path and that path is the intended active destination for the current workflow
- **THEN** the assessment SHALL classify it as canonical
- **AND** it SHALL explain why it is canonical

#### Scenario: A path is retained only for downstream compatibility
- **WHEN** a runtime path is still read by an active downstream script but is no longer the main producer destination
- **THEN** the assessment SHALL classify it as compatibility-only
- **AND** it SHALL identify the downstream dependency that keeps it alive

#### Scenario: A path is purely archive or duplicate history
- **WHEN** a runtime path is not referenced by current scripts and appears to preserve historical snapshots or duplicate layout branches
- **THEN** the assessment SHALL classify it as legacy archive or duplicated
- **AND** it SHALL record the evidence for that classification

### Requirement: Record unresolved cleanup questions explicitly
The assessment SHALL record unresolved classifications rather than forcing uncertain paths into canonical or archive categories without evidence.

#### Scenario: Classification evidence conflicts
- **WHEN** script references, timestamps, or folder contents give conflicting signals about a runtime path
- **THEN** the assessment SHALL classify that path as unresolved
- **AND** it SHALL describe what additional evidence is needed before cleanup
