# Endolaserless Maintenance Certification Design

## Goal

Keep Endolaserless runnable and correctly routed without expanding the unfinished neovascularization work into a new research-development effort.

## Scope

This certification will:

- preserve the existing uncommitted path and neovascularization audit work without changing its scientific meaning;
- standardize active defaults to the canonical workspace, Project Vault `data/raw`, local runtime, and explicit Project Vault `outputs` boundary;
- run the established NPI and PRN workflows against their real inputs;
- parse and smoke-check the unfinished neovascularization code without hydrating additional inputs, generating reviewer-facing results, adjudicating endpoints, or making scientific claims;
- prove that ordinary generation writes only beneath local runtime and that durable publication requires an explicit action; and
- update concise present-state operator documentation.

This certification will not complete the neovascularization study, add models or endpoints, interpret its exploratory audit, normalize unrelated cloud residue, delete legacy material, or perform a broad archive cleanup.

## Documentation Contract

Superpowers specifications and tests govern new implementation work. Existing OpenSpec specifications and archived changes remain committed as valuable repository history and technical context. They may receive narrowly necessary path corrections, but OpenSpec CLI validation and change-completion status are not certification gates.

## Data and Output Boundaries

- Source: `/Users/ncamarda/Workspaces/endolaserless/source`
- Runtime: `/Users/ncamarda/Workspaces/endolaserless/runtime`
- Raw inputs: `/Users/ncamarda/Library/CloudStorage/OneDrive-Personal/Project Vault/Research/endolaserless/data/raw`
- Durable selected outputs: `/Users/ncamarda/Library/CloudStorage/OneDrive-Personal/Project Vault/Research/endolaserless/outputs`

No ordinary workflow may write generated output into source, Downloads, the raw-data tree, or Project Vault outputs. Publishing remains explicit and dry-run-first.

## Implementation Shape

1. Capture and verify a private local recovery package for the existing dirty files.
2. Commit those existing files unchanged and label the neovascularization work as exploratory.
3. Add failing tests for canonical defaults, environment overrides, runtime-only generation, and no implicit publication.
4. Make only the path and output-routing changes required to pass those tests.
5. Run the NPI and PRN workflows from canonical raw inputs and compare their regenerated artifacts semantically.
6. Parse and smoke-check the neovascularization scripts without executing the real-data audit.
7. Verify source and Project Vault protected trees did not receive generated writes.
8. Open a focused GitHub pull request after repository tests and controller checks pass.

## Failure Handling

Missing raw inputs, unexplained artifact drift, writes outside runtime, or scientific behavior changes fail the certification. They are investigated directly; no compatibility fallback, silent skip, copied legacy tree, or weakened test is permitted.

## Success Criteria

- Existing unfinished work is recoverable and committed without private/raw data.
- Active path defaults and overrides resolve correctly.
- NPI and PRN workflows exit successfully using canonical inputs.
- Their generated changes are confined to runtime and are semantically accounted for.
- Neovascularization source parses and its non-data setup can be smoke-tested without cloud writes.
- OpenSpec records remain present but are not active tooling gates.
- The branch is clean, reviewed, and represented by a focused pull request.
