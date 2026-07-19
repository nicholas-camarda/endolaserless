## Context

The neovascularization project folder exists only as an archive/scaffold. The actual usable source evidence is spread across the shared cloud `data` root:

- `Laserless Study DATA Updated for 3 Year Data (1).xlsx`, sheet `FAFundus Readout`, contains a collaborator-facing subject-level active-neovascularization summary and FA neovascularization change fields.
- `2024-10-22 Endolaserless_RedCap_Data.xlsx`, sheet `RedCap`, contains longitudinal NVD, NVE, leakage, NPI, and nonperfusion fields.
- `Wisconsis_study_data_analysis_FAgradng_MASTERsheet7.10.24.xlsm` and older Wisconsin workbooks contain overlapping long-form and primary-outcome tabs, plus historical summaries.

Prior inspection found that strict NVD is sparse, NVE is limited, and leakage is richer. It also found that 2026 suffixed files can be duplicate-content exports rather than new data. The workflow must therefore be an evidence audit and dataset spin-up, not a treatment-comparison analysis.

## Goals / Non-Goals

**Goals:**

- Create a reproducible script that inventories neovascularization-relevant cloud spreadsheets and identifies duplicate-content exports.
- Build a cleaned subject-level active-neovascularization table from `FAFundus Readout`.
- Build a cleaned raw longitudinal endpoint table from RedCap/Wisconsin NVD, NVE, and leakage fields.
- Reconcile the active-neovascularization summary against raw endpoint evidence at each subject's latest available raw FA visit.
- Emit a concise feasibility report that classifies endpoints as usable, sparse, or unsupported for descriptive analysis.

**Non-Goals:**

- Do not modify source Excel/CSV files.
- Do not rerun or alter the NPI/PRN manuscript workflows.
- Do not update `docs/*.png` mirrors or published neovascularization mirrors.
- Do not fit treatment-effect, causal, predictive, Cox, Kaplan-Meier, or equivalence models.

## Decisions

### Decision: use `FAFundus Readout` as the primary endpoint source

The primary table will parse `Presence of active neovascularization: Yes, No, Missed` and `FA neovascularization compared to baseline: Unchanged, worsened, improved, indeterminate, missed` from `Laserless Study DATA Updated for 3 Year Data (1).xlsx`. This source captures the collaborator-facing summary endpoint and has enough subject-level variation to support a descriptive feasibility report.

### Decision: use raw NVD/NVE/leakage fields for reconciliation, not primary efficacy modeling

The raw RedCap/Wisconsin fields will be normalized into a long table with subject, schedule, timepoint, week, NVD, NVE within 7F, NVE beyond 7F, NVE count, leakage presence, and cleaned leakage area fields. Strict NVD and NVE counts will be reported as endpoint support/sparsity evidence rather than used to make comparative treatment claims.

### Decision: write runtime artifacts only

All generated CSV/Markdown artifacts will be written under the neovascularization runtime processed/output roots. The cloud neovascularization archive remains a publish/mirror destination and is not updated by default.

### Decision: exclude known non-study rows

Rows with missing subject IDs, header rows, and synthetic/test subjects such as `TEST` will be excluded from processed endpoint datasets while still being mentionable in the audit report if discovered.

## Output Shape

The script will write:

- `source_inventory.csv`: spreadsheet inventory with path, size, timestamp, hash, and source role.
- `duplicate_hash_groups.csv`: duplicate-content file groups.
- `active_neovascularization_summary.csv`: parsed `FAFundus Readout` subject-level endpoint table.
- `raw_longitudinal_neovascularization.csv`: cleaned raw longitudinal NVD/NVE/leakage table.
- `endpoint_reconciliation.csv`: subject-level reconciliation of active NV summary against latest raw NVD/NVE evidence.
- `neovascularization_feasibility_report.md`: concise descriptive report with endpoint counts, source agreement, limitations, and readiness.

## Risks / Trade-offs

- The active-neovascularization summary may not align exactly with raw NVD/NVE fields because it may reflect adjudicated or broader clinical interpretation. Mitigation: report agreement and discordance explicitly.
- Subject IDs in `FAFundus Readout` are embedded in labels. Mitigation: parse only `L` identifiers and normalize to `L-##`; keep unparseable rows out of the processed dataset.
- Historical workbooks may contain overlapping or stale summaries. Mitigation: inventory them but treat top-level current workbooks and explicit source roles as primary.
- Existing `model_summary_combined.xlsx` may contain stale or sentinel-contaminated models. Mitigation: do not reuse it as evidence; mention it only as an existing published mirror outside this change's generated outputs.
