## Context

The Endolaserless repo is a script-first R analysis workflow centered on `scripts/endolaserless_analysis-2.R` for the main q8/q16 NPI pipeline and `scripts/count_prn_injections.R` for downstream PRN rescue injection summaries. Both scripts depend on external workbooks under the cloud-backed data root and on cached `.xlsx` workbooks under the runtime root.

The current state that motivated this change had two concrete intake reliability problems plus one project-prioritization problem:

- The newest files by timestamp in `/Users/ncamarda/Library/CloudStorage/OneDrive-Personal/Research/endolaserless/data` include duplicate-content suffixed exports such as `...[23]`, `...[48]`, and `...[79]`, so timestamp alone does not identify the canonical input.
- The raw inputs themselves still contain conventions that need explicit interpretation, including starred numeric strings, mixed week labels, and RedCap NPA missing-value tokens such as `"not gradable"` and sentinel values around `8888.88`.
- We do not yet have a decision-complete, evidence-backed shortlist that says which next subproject should be attempted first now that the runtime layout is normalized.

The current scripts already strip `*` markers from numeric cells in `Stats Wisconsin (Nick Edited).xlsx`, parse mixed week labels in `prn_injections.xlsx`, and now recode `"not gradable"` plus values `>= 8888` in `2024-10-22 Endolaserless_RedCap_Data.xlsx`. During implementation, the audit also exposed one real parser gap in `scripts/count_prn_injections.R`: `20 wk post op` and `1-2 wk post-op` were not being normalized into the active PRN workflow. That parser alignment is now part of the implemented state and the audit rerun marks the workflow as ready.

## Goals / Non-Goals

**Goals:**

- Add a reproducible intake audit that inspects the cloud data root and identifies the canonical raw input file for each analysis dependency used by the NPI and PRN scripts.
- Surface file-level, sheet-level, column-level, and value-level cleaning issues before rerunning the q8/q16 analyses.
- Recommend canonical cleaning rules when the evidence is already clear, without mutating source files or silently changing analysis behavior.
- Produce a short, prioritized follow-on project shortlist grounded in the audited data, current processed workbooks, and the study's descriptive or associational scope.
- Preserve the existing script-first workflow and runtime artifact layout rather than introducing a package or database abstraction.

**Non-Goals:**

- Rewriting the NPI or PRN analysis logic into a package.
- Replacing Prism-facing `.xlsx` exports with a new plotting system.
- Making new causal claims beyond the current descriptive and associational scope of the study.
- Fully cleaning or reanalyzing every historical workbook under `data/old`.
- Reopening the already completed runtime-root or processed-cache normalization changes.

## Decisions

### Decision: add a dedicated read-only audit script rather than burying checks inside the analysis scripts

The change will add a repo-local audit entry point under `scripts/` that can run before `endolaserless_analysis-2.R` and `count_prn_injections.R`. The audit will inspect the exact inputs the current scripts use:

- `Stats Wisconsin (Nick Edited).xlsx` sheet 6 for q8/q16 NPI and cumulative injection inputs
- `prn_injections.xlsx` sheet 1 for PRN rescue injections
- `2024-10-22 Endolaserless_RedCap_Data.xlsx` for NPA and related RedCap fields

This keeps the implementation close to the existing workflow while making the cleaning assumptions explicit and testable.

Alternative considered: add the checks directly to `endolaserless_analysis-2.R` and `count_prn_injections.R`.
Why not: that would make the scripts even more coupled, would not audit duplicate raw files that are not currently selected, and would not produce a reusable project shortlist artifact.

### Decision: keep the audit read-only, but let validation fix proven parser drift

The audit itself remains read-only. However, if validation shows that a currently used downstream script is silently missing real input content because of a proven header or value-parsing mismatch, the change may include the minimal script fix needed to align the live workflow with the audited raw input. In this repo that meant updating PRN visit-header normalization so `20 wk post op` and `1-2 wk post-op` are no longer dropped or malformed during PRN summary generation.

Alternative considered: leave the parser gap as a documented warning only.
Why not: the audit showed that the dropped PRN header contained actual `**1` marker cells, so leaving it unresolved would have kept known bad downstream exports in place.

### Decision: treat top-level `data/` as canonical intake scope and use a content-and-name rule inside it

The audit will scan the top-level cloud `data/` directory as the canonical candidate pool. It will record modification time, file size, and content hash for candidate raw files. When two files in that canonical pool have identical hashes, the audit will treat them as duplicate exports and prefer the unsuffixed filename as canonical unless configuration says otherwise. Historical files under `data/old` may be mentioned as context but are not equal candidates for current canonical selection.

Alternative considered: scan `data/old` and top-level `data/` as equal candidates.
Why not: that would increase noise and ambiguity even though the repo now has a clearer canonical runtime workflow built around the main `data/` root.

### Decision: recommend cleaning rules when the evidence is clear

The audit should stay read-only, but it should still state canonical cleaning assumptions when the source data clearly indicate them. In the current repo, the clearest example is RedCap NPA handling: explicit `"not gradable"` tokens and numeric values at or above `8888` should be recommended as missing-value conventions rather than left as ambiguous warnings.

Alternative considered: strict report-only audit with no recommended rules.
Why not: that would miss the value of the audit as a decision aid and would leave already-settled cleaning conventions undocumented.

### Decision: write audit outputs as runtime artifacts, not docs mirrors

The audit outputs should land under the runtime `output` and, when helpful, `processed_data` trees so they stay close to other regenerated artifacts and do not confuse `docs/*.png` publication mirrors with canonical data products. The final report should name affected workbooks and whether rerunning the main pipeline is required before rerunning the PRN summary script.

Alternative considered: write the audit only into repo docs.
Why not: docs mirrors are not the canonical runtime output path and are easier to let drift away from the underlying workbooks.

### Decision: finish the runtime cleanup once the audit confirms the old compatibility branch is no longer active

The change can close the runtime cleanup loop once the audit and reruns confirm that `scripts/count_prn_injections.R` no longer depends on `processed_data/npi_project/output-week4_baseline`. In the implemented state, that week4-only compatibility branch has been archived under `processed_data/npi_project/archive/output-week4_baseline-legacy-20260408`, and the cloud git metadata backup was moved out of the project runtime root into `~/ProjectsRuntime/workspace-governor/backups/endolaserless`.

Alternative considered: leave the compatibility branch and admin backup in place indefinitely.
Why not: that would keep the active runtime tree noisier than necessary and preserve ambiguity after the workflow had already been validated against the canonical branch.

### Decision: generate a small project shortlist with replication first

The audit will emit a short set of candidate follow-on projects, each tied to:

- the exact source workbook or cached artifact it depends on
- whether the project is descriptive, associational, causal, or predictive
- the cleaning or path blockers that must be resolved first
- the downstream workbooks or figure mirrors it could change

The first-ranked candidate should be a replication/cache-consistency pass, because the runtime normalization is complete and the lowest-risk next step is to confirm that current canonical inputs regenerate stable downstream artifacts before starting a new substantive analysis. RedCap NPA refresh and PRN reason stratification remain valid secondary ideas.

Alternative considered: keep project ideation in README notes only.
Why not: that would not capture readiness or dependency information derived from the actual audited data.

## Risks / Trade-offs

- [Audit rules may overfit the current workbook names] → Mitigation: define the audit around required script inputs and sheet/column expectations, while still reporting alternate matching files discovered under the cloud data root.
- [The audit could make cleaning recommendations that feel too strong] → Mitigation: keep the audit read-only and require each recommended cleaning rule to cite the exact workbook field pattern it is based on.
- [Validation-time parser fixes could expand change scope] → Mitigation: keep any script change narrowly limited to proven input alignment issues surfaced by the audit, and rerun the affected outputs immediately.
- [A shortlist of spin-up projects could encourage analyses before cleaning is complete] → Mitigation: require each project idea to include a readiness tier and blocking data-quality issues.
- [No automated test suite exists] → Mitigation: validate by rerunning the audit, then rerunning the affected scripts and comparing the specific processed workbooks and PRN outputs they write.

## Migration Plan

1. Update the change artifacts so they no longer reopen the completed runtime normalization work.
2. Add the audit script and report outputs.
3. Run the audit against the canonical top-level cloud `data/` root and current runtime roots.
4. Review the audit report for canonical input selection, cleaning issues, recommended rules, and rerun readiness.
5. If the audit surfaces a proven live parser mismatch, apply the minimal downstream script alignment needed for valid reruns.
6. Rerun `scripts/endolaserless_analysis-2.R`, then rerun `scripts/count_prn_injections.R`, and compare the regenerated workbooks against the prior runtime artifacts.
7. Archive the old compatibility branch out of the active runtime tree once validation confirms it is no longer needed.

## Open Questions

- None. The current decisions are:
- scan the top-level cloud `data/` directory as canonical intake scope
- keep the audit read-only but allow it to recommend clear cleaning rules
- rank replication/cache-consistency first in the follow-on shortlist
