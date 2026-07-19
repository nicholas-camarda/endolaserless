# Endolaserless Maintenance Certification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the unfinished Endolaserless work, standardize active path/output boundaries, and prove the established NPI and PRN workflows without expanding the neovascularization study.

**Architecture:** Capture the existing dirty bytes before editing, commit them as exploratory provenance, then use dependency-free R tests to drive one canonical path resolver and runtime-only output behavior. Execute only the established NPI/PRN real-data workflows; neovascularization receives parsing and isolated no-data smoke coverage only.

**Tech Stack:** Git, R/base R, testthat-independent assertions, SHA-256, GitHub Actions/CLI, OneDrive Project Vault.

## Global Constraints

- Preserve all existing OpenSpec records, but do not use OpenSpec CLI validation or change-completion status as an implementation gate.
- Do not execute or extend `scripts/neovascularization_data_audit.R` against real data.
- Raw inputs resolve to `Project Vault/Research/endolaserless/data/raw`.
- Generated output remains beneath `~/Workspaces/endolaserless/runtime`.
- Project Vault `outputs` is written only by an explicit, dry-run-first publish action.
- Do not delete, copy, or broadly hydrate cloud trees.
- Do not add compatibility fallbacks or weaken tests to obtain a passing run.

---

## File and Interface Map

- `scripts/project_paths.R`: returns canonical source, runtime, raw-data, document, reference, and durable-output roots.
- `scripts/neovascularization_project.R`: creates runtime directories only and previews publication without writing by default.
- `scripts/endolaserless_analysis-2.R`: established NPI producer; reads canonical raw inputs and writes runtime artifacts.
- `scripts/count_prn_injections.R`: established PRN consumer/producer; reads NPI runtime output and canonical raw inputs.
- `scripts/neovascularization_data_audit.R`: preserved exploratory audit; parsed but not executed against real data.
- `tests/run_tests.R`: isolated dependency-free R test runner.
- `tests/test_project_paths.R`: canonical defaults and environment-override contract.
- `tests/test_output_boundaries.R`: runtime-only setup, dry-run publishing, and active-path scan.
- `README.md`: concise present-state workflow and boundary documentation.

### Task 1: Capture and Preserve the Existing Dirty Work

**Files:**
- Preserve: `openspec/specs/runtime-layout-assessment/spec.md`
- Preserve: `scripts/project_paths.R`
- Preserve: `openspec/changes/add-neovascularization-data-audit/`
- Preserve: `scripts/neovascularization_data_audit.R`
- Create privately at execution time: `~/Workspaces/endolaserless/archive/pre-certification-dirty-capture-$RUN_ID/`

**Interfaces:**
- Consumes: current dirty branch state based on `main` commit `456aae5c6845b7417adec1299b729165bfddcc0a`.
- Produces: verified local recovery bundle, binary patch, untracked-file archive, hashes, and a provenance commit containing the existing dirty work unchanged.

- [x] **Step 1: Capture the exact live state and hashes**

```bash
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)
CAPTURE="$HOME/Workspaces/endolaserless/archive/pre-certification-dirty-capture-$RUN_ID"
mkdir -p "$CAPTURE"
chmod 700 "$CAPTURE"
git status --porcelain=v2 --branch --untracked-files=all
git diff --binary > "$CAPTURE/tracked-dirty.patch"
git ls-files --others --exclude-standard -z > "$CAPTURE/untracked.zlist"
printf '%s\0' openspec/changes/add-neovascularization-data-audit/.openspec.yaml >> "$CAPTURE/untracked.zlist"
tar -C "$HOME/Workspaces/endolaserless/source" --null -T "$CAPTURE/untracked.zlist" -czf "$CAPTURE/untracked.tar.gz"
git bundle create "$CAPTURE/repository.bundle" --all
find "$CAPTURE" -type f -exec shasum -a 256 {} \; | sort > "$CAPTURE/SHA256SUMS"
```

- [x] **Step 2: Verify the recovery package**

```bash
git bundle verify "$CAPTURE/repository.bundle"
git apply --check "$CAPTURE/tracked-dirty.patch"
tar -tzf "$CAPTURE/untracked.tar.gz" | sort
shasum -a 256 -c "$CAPTURE/SHA256SUMS"
```

Expected: all commands exit 0; the tar contains the five ordinarily untracked files plus the ignored `.openspec.yaml`; no raw workbook or runtime output is present.

- [x] **Step 3: Commit only the captured user work**

```bash
git add openspec/specs/runtime-layout-assessment/spec.md scripts/project_paths.R \
  openspec/changes/add-neovascularization-data-audit scripts/neovascularization_data_audit.R
git add -f openspec/changes/add-neovascularization-data-audit/.openspec.yaml
git diff --cached --check
git commit -m "Preserve exploratory neovascularization audit work"
```

Expected: the commit contains the captured dirty files and no data/output files. The already-committed Superpowers design/plan remain separate provenance commits.

### Task 2: Drive Canonical Paths and Runtime-Only Outputs with TDD

**Files:**
- Create: `tests/run_tests.R`
- Create: `tests/test_project_paths.R`
- Create: `tests/test_output_boundaries.R`
- Modify: `scripts/project_paths.R`
- Modify: `scripts/neovascularization_project.R`
- Modify: `scripts/endolaserless_analysis-2.R`

**Interfaces:**
- Produces: `endolaserless_paths()` fields `cloud_root`, `data_root`, `documents_root`, `references_root`, `durable_outputs_root`, `npi_durable_outputs_root`, and `neovascularization_durable_outputs_root` while retaining all currently consumed runtime fields.
- Produces: `mirror_neovascularization_published_outputs(..., dry_run = TRUE)` and runtime-only `ensure_neovascularization_project_layout()`.

- [x] **Step 1: Write the isolated test runner**

```r
test_files <- sort(list.files("tests", pattern = "^test_.*[.]R$", full.names = TRUE))
stopifnot(length(test_files) >= 2L)
for (test_file in test_files) {
    sys.source(test_file, envir = new.env(parent = globalenv()))
    message("PASS ", test_file)
}
message("PASS all R tests")
```

- [x] **Step 2: Write failing path tests**

`tests/test_project_paths.R` must unset all three path variables, source `scripts/project_paths.R`, and assert:

```r
stopifnot(identical(paths$code_root, path.expand("~/Workspaces/endolaserless/source")))
stopifnot(identical(paths$runtime_root, path.expand("~/Workspaces/endolaserless/runtime")))
stopifnot(identical(paths$data_root, file.path(paths$cloud_root, "data", "raw")))
stopifnot(identical(paths$durable_outputs_root, file.path(paths$cloud_root, "outputs")))
stopifnot(startsWith(paths$npi_canonical_output_root, paste0(paths$runtime_root, "/")))
```

It must then set all three variables to temporary roots and assert every derived path follows those overrides.

- [x] **Step 3: Write failing output-boundary tests**

With temporary source/runtime/cloud roots, source `scripts/neovascularization_project.R`, call ordinary setup, and assert:

```r
layout <- ensure_neovascularization_project_layout()
stopifnot(dir.exists(layout$runtime_output_root))
stopifnot(dir.exists(layout$runtime_processed_root))
stopifnot(!dir.exists(cloud_root))

preview <- mirror_neovascularization_published_outputs(dry_run = TRUE)
stopifnot(all(is.na(preview$copied)), !dir.exists(cloud_root))
```

The same test must scan uncommented active lines in `scripts/*.R` and reject `~/Downloads`, `/OneDrive-Personal/Research/endolaserless`, and generated paths derived from `getwd()`.

- [x] **Step 4: Run RED**

```bash
Rscript tests/run_tests.R
```

Expected: failures identify the old cloud root, `data` instead of `data/raw`, absent durable-output fields, implicit cloud directory creation, publication defaulting to live copy, `getwd()` source default, and the active Downloads workbook write.

- [x] **Step 5: Implement only the tested boundary contract**

Set canonical defaults in `endolaserless_paths()`, derive all generated roots from runtime, derive publish roots from Project Vault `outputs`, make publication dry-run by default, and make ordinary neovascularization setup create only its two runtime directories. Route `npi_vs_npi_baseline-regression.xlsx` and the default graphics device beneath `paths$npi_canonical_output_root`.

- [x] **Step 6: Run GREEN and commit**

```bash
Rscript tests/run_tests.R
Rscript -e 'files <- list.files("scripts", pattern="[.]R$", full.names=TRUE); invisible(lapply(files, parse)); cat("parsed=", length(files), " failed=0\n", sep="")'
git diff --check
git add tests scripts/project_paths.R scripts/neovascularization_project.R scripts/endolaserless_analysis-2.R
git commit -m "Standardize Endolaserless path boundaries"
```

Expected: all tests pass, all active scripts parse, and only tested path/output behavior changes.

### Task 3: Run the Established Workflows and Account for Outputs

**Files:**
- Read exactly: `data/raw/Stats Wisconsin (Nick Edited).xlsx`
- Read exactly: `data/raw/2024-10-22 Endolaserless_RedCap_Data.xlsx`
- Read exactly: `data/raw/prn_injections.xlsx`
- Generate only beneath: `~/Workspaces/endolaserless/runtime/`

**Interfaces:**
- NPI produces `runtime/processed_data/npi_project/output-week4_week16_baseline/cached_long_input_data.xlsx`.
- PRN consumes that workbook and produces `runtime/output/npi_project/count_prn_injections/*.xlsx`.

- [x] **Step 1: Capture source/cloud metadata and runtime workbook signatures**

Record protected-tree path/type/size/mtime metadata without opening unrelated cloud files. For existing runtime `.xlsx` files, record SHA-256 plus sheet names, dimensions, and column names with `openxlsx`.

- [x] **Step 2: Verify and hash the three exact raw inputs**

```bash
RAW="$HOME/Library/CloudStorage/OneDrive-Personal/Project Vault/Research/endolaserless/data/raw"
shasum -a 256 \
  "$RAW/Stats Wisconsin (Nick Edited).xlsx" \
  "$RAW/2024-10-22 Endolaserless_RedCap_Data.xlsx" \
  "$RAW/prn_injections.xlsx"
```

- [x] **Step 3: Run the NPI producer and PRN consumer**

```bash
env -u ENDOLASERLESS_CODE_ROOT -u ENDOLASERLESS_RUNTIME_ROOT -u ENDOLASERLESS_CLOUD_ROOT \
  Rscript scripts/endolaserless_analysis-2.R
env -u ENDOLASERLESS_CODE_ROOT -u ENDOLASERLESS_RUNTIME_ROOT -u ENDOLASERLESS_CLOUD_ROOT \
  Rscript scripts/count_prn_injections.R
```

Expected: both exit 0; no source-root `Rplots.pdf`; NPI and PRN artifacts refresh only in runtime.

- [x] **Step 4: Smoke-check neovascularization without real-data execution**

```bash
Rscript -e 'parse("scripts/neovascularization_data_audit.R"); source("scripts/neovascularization_project.R"); cat("neovascularization_parse=pass\n")'
Rscript tests/run_tests.R
```

Expected: parsing and isolated temporary-root layout tests pass. Do not run `scripts/neovascularization_data_audit.R` as an entry point.

- [x] **Step 5: Compare outputs and protected trees**

Require unchanged source/cloud names and sizes except expected access metadata for the three raw inputs. Compare workbook sheet names, dimensions, columns, subject identifiers, and schedule counts. Investigate any semantic difference; do not accept exit status alone.

### Task 4: Document, Certify, and Publish the Branch

**Files:**
- Modify: `README.md`
- Modify locally only: `AGENTS.md`
- Modify: OpenSpec files containing an active `/OneDrive-Personal/Research/endolaserless` path statement
- Modify locally: `~/Workspaces/endolaserless/manifest.yaml`

**Interfaces:**
- Produces: present-state documentation, passing repository/controller gates, clean branch, and focused GitHub PR.

- [x] **Step 1: Update present-state documentation**

Document the canonical source/runtime/raw/output paths, NPI and PRN commands, exploratory neovascularization status, runtime-only generation, and explicit publishing. State that OpenSpec records are retained context while Superpowers/TDD governs new work. Replace only active old-root path statements found by:

```bash
rg -n '/OneDrive-Personal/Research/endolaserless' README.md AGENTS.md openspec
```

Do not rewrite historical rationale or scientific requirements.

- [x] **Step 2: Update the workspace manifest current state**

Set Project Vault status and raw/output paths to the verified live state; remove active claims that data remains under the absent legacy `Research/endolaserless` root. Retain the old path only as legacy evidence.

- [x] **Step 3: Run final verification**

```bash
Rscript tests/run_tests.R
Rscript -e 'files <- list.files("scripts", pattern="[.]R$", full.names=TRUE); invisible(lapply(files, parse)); cat("parsed=", length(files), " failed=0\n", sep="")'
git diff --check
python3 "$WORKSPACE_CONTROLLER_ROOT/work/file-org-migration/scripts/validate_existing_workspaces.py"
python3 "$WORKSPACE_CONTROLLER_ROOT/work/file-org-migration/scripts/check_readiness.py"
```

Expected: all repository checks pass, controller readiness passes, and Git contains no raw data, runtime artifacts, or private recovery files.

- [x] **Step 4: Commit and publish**

```bash
git add README.md scripts tests docs/superpowers
git commit -m "Certify Endolaserless maintenance workflow"
git push -u origin cutover/project-vault-conformance
gh pr create --base main --head cutover/project-vault-conformance \
  --title "Certify Endolaserless paths and maintenance workflow"
```

Expected: a focused PR containing preservation, tested path/output changes, documentation, and no scientific expansion of neovascularization.
