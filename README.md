# Endolaserless

## Overview

This repository is the canonical local codebase for the broader Endolaserless analysis workspace around the Laserless Study (NCT02976012), a prospective randomized trial of aflibercept monotherapy after endolaserless vitrectomy for proliferative diabetic retinopathy-related vitreous hemorrhage.

The project currently has two analysis tracks:

- `npi_project`: the active nonperfusion index (NPI) and PRN injection workflow that supports the submitted manuscript
- `neovascularization_project`: an intentionally scaffold-only track whose endpoint inventory, processed tables, and analysis pipeline have not been finalized yet

The local repo is the source of truth for scripts, workflow definitions, and OpenSpec changes. Cloud and runtime paths are part of the working architecture, but they are not the active codebase.

## Canonical Roots

- Code root: `~/Projects/endolaserless`
- Runtime root: `~/ProjectsRuntime/endolaserless`
- Cloud archive and source-data root: `~/Library/CloudStorage/OneDrive-Personal/Research/endolaserless`

Path resolution is centralized in [scripts/project_paths.R](/Users/ncamarda/Projects/endolaserless/scripts/project_paths.R). It supports:

- `ENDOLASERLESS_CODE_ROOT`
- `ENDOLASERLESS_RUNTIME_ROOT`
- `ENDOLASERLESS_CLOUD_ROOT`

## Architecture

The project is split across three roles:

1. Local repo
   Holds canonical scripts, lightweight README figures, and OpenSpec artifacts.
2. Runtime root
   Holds regenerated processed workbooks, logs, scratch outputs, and other non-synced analysis artifacts.
3. Cloud root
   Holds shared raw data, archived project materials, manuscript assets, and published mirrors copied from runtime when appropriate.

Cloud-side script or README copies are treated as legacy migration material or archive snapshots, not as the active implementation source.

## Track Layout

### Shared Umbrella Assets

- Cloud `data/`: shared study-wide raw inputs reused across tracks
- Cloud `docs/`: manuscript drafts, presentations, and working documents
- Cloud `references/`: reference PDFs and supporting literature

### NPI Track

Main entry points:

- [scripts/endolaserless_analysis-2.R](/Users/ncamarda/Projects/endolaserless/scripts/endolaserless_analysis-2.R)
- [scripts/count_prn_injections.R](/Users/ncamarda/Projects/endolaserless/scripts/count_prn_injections.R)

Key runtime destinations:

- Canonical processed branch: `~/ProjectsRuntime/endolaserless/processed_data/npi_project/output-week4_week16_baseline`
- Canonical analysis output branch: `~/ProjectsRuntime/endolaserless/output/npi_project/output-week4_week16_baseline`
- Canonical PRN export branch: `~/ProjectsRuntime/endolaserless/output/npi_project/count_prn_injections`
- Archived compatibility branch: `~/ProjectsRuntime/endolaserless/processed_data/npi_project/archive/output-week4_baseline-legacy-20260408`

Key cloud archive destination:

- `~/Library/CloudStorage/OneDrive-Personal/Research/endolaserless/npi_project`

### Neovascularization Track

Scaffold entry point:

- [scripts/neovascularization_project.R](/Users/ncamarda/Projects/endolaserless/scripts/neovascularization_project.R)

Expected runtime destinations:

- `~/ProjectsRuntime/endolaserless/processed_data/neovascularization_project`
- `~/ProjectsRuntime/endolaserless/output/neovascularization_project`

Expected cloud archive destinations:

- `~/Library/CloudStorage/OneDrive-Personal/Research/endolaserless/neovascularization_project/data/raw`
- `~/Library/CloudStorage/OneDrive-Personal/Research/endolaserless/neovascularization_project/data/processed`
- `~/Library/CloudStorage/OneDrive-Personal/Research/endolaserless/neovascularization_project/archive/notes`
- `~/Library/CloudStorage/OneDrive-Personal/Research/endolaserless/neovascularization_project/output/published`

This track is scaffold-only for now. The local helper sets up layout, inventories the archive, and mirrors publishable outputs from runtime while excluding transient files.

The existing cloud file `neovascularization_project/output/published/model_summary_combined.xlsx` should be treated as legacy archive material until it is regenerated from a runtime source under the canonical local workflow.

## Code And Archive Boundaries

- Keep analysis code in this local repo.
- Keep shared raw source data in the cloud `data/` root.
- Keep regenerated workbooks, logs, caches, and scratch outputs in the runtime root.
- Keep published or shareable mirrored artifacts in the cloud subproject archives.
- Treat repo `docs/*.png` as lightweight display mirrors for the README, not as canonical figure-generation sources.
- Keep cross-project admin backups out of project runtime roots when possible. For this repo, the removed cloud git metadata backup lives under `~/ProjectsRuntime/workspace-governor/backups/endolaserless`.

For neovascularization published mirrors, transient files such as logs, caches, temp files, `.DS_Store`, and `output_log.txt` should not be copied into `output/published/`.

## NPI Status

The current NPI workflow supports these descriptive and associational findings:

- retinal nonperfusion increased over 3 years despite anti-VEGF therapy
- q16 eyes showed significant progression while q8 eyes did not
- q16 eyes required more PRN rescue injections
- in q16, higher cumulative injections were associated with greater NPI burden

Current publication-display figures in this repo:

![Figure 1](docs/Figure1.png)
![Figure 2](docs/Figure2.png)
![Figure 3](docs/Figure3.png)
![Supplementary Figure 1](docs/SupplementalFigure1.png)

## Usage

1. Ensure R and the required packages are installed.
2. Keep shared raw inputs under the cloud `data/` root.
3. Run scripts from the local repo.
4. Review runtime outputs before mirroring any publication-facing artifacts into cloud archives or repo `docs/`.

Typical entry points:

- `Rscript scripts/latest_data_intake_audit.R`
- `Rscript scripts/endolaserless_analysis-2.R`
- `Rscript scripts/count_prn_injections.R`
- `Rscript -e "source('scripts/neovascularization_project.R'); run_neovascularization_project_scaffold()"`

## Validation Notes

- There is no automated in-repo test suite.
- Validation should include checking both direct script outputs and downstream artifacts that consume them.
- `scripts/latest_data_intake_audit.R` writes a read-only intake report plus inventory CSVs under `output/npi_project/latest_data_intake_audit`.
- `scripts/endolaserless_analysis-2.R` writes the canonical processed NPI branch at `processed_data/npi_project/output-week4_week16_baseline/...`.
- `scripts/count_prn_injections.R` now reads `cached_long_input_data.xlsx` from that same canonical processed branch and writes PRN exports under `output/npi_project/count_prn_injections`.
- The old compatibility branch has been archived at `processed_data/npi_project/archive/output-week4_baseline-legacy-20260408`.

## Dependencies

Common packages include:

- `tidyverse`
- `readxl`
- `openxlsx`
- `ggplot2`
- `ggprism`
- `lmerTest`

Additional statistical packages are specified in the scripts that use them.

## License

This repository contains research analysis code. Please contact the authors for usage permissions.
