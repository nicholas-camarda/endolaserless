source(file.path("scripts", "project_paths.R"))

suppressPackageStartupMessages({
    library(dplyr)
    library(purrr)
    library(readxl)
    library(stringr)
    library(tibble)
})

paths <- endolaserless_paths()

audit_output_dir <- file.path(paths$npi_output_root, "latest_data_intake_audit")
dir.create(audit_output_dir, recursive = TRUE, showWarnings = FALSE)

timestamp_iso <- function(x) {
    ifelse(
        is.na(x),
        NA_character_,
        format(as.POSIXct(x, tz = Sys.timezone()), "%Y-%m-%d %H:%M:%S %Z")
    )
}

strip_export_suffix <- function(filename) {
    str_replace(filename, "\\[[0-9]+\\](\\.[^.]+)$", "\\1")
}

read_excel_quiet <- function(path, sheet = NULL, n_max = Inf) {
    suppressMessages(read_excel(path, sheet = sheet, n_max = n_max))
}

normalize_prn_week_headers <- function(column_names) {
    column_names %>%
        str_squish() %>%
        str_replace_all(
            regex("^(\\d+)\\s*-\\s*(\\d+)\\s+wk\\s+post[- ]op$", ignore_case = TRUE),
            "week\\2"
        ) %>%
        str_replace_all(
            regex("^(\\d+)\\s+[- ]?\\s*(wk|week)\\s+post[- ]op$", ignore_case = TRUE),
            "week\\1"
        )
}

latest_file_timestamp <- function(path) {
    if (!dir.exists(path)) {
        return(as.POSIXct(NA))
    }

    files <- list.files(path, recursive = TRUE, full.names = TRUE, all.files = TRUE, no.. = TRUE)
    files <- files[file.exists(files) & !dir.exists(files)]

    if (!length(files)) {
        return(as.POSIXct(NA))
    }

    max(file.info(files)$mtime, na.rm = TRUE)
}

choose_canonical_file <- function(inventory, expected_filename) {
    normalized_name <- strip_export_suffix(expected_filename)
    candidates <- inventory %>%
        filter(normalized_filename == normalized_name)

    if (!nrow(candidates)) {
        return(tibble(
            selected_filename = NA_character_,
            selected_path = NA_character_,
            selection_reason = "missing",
            candidate_count = 0L
        ))
    }

    exact_match <- candidates %>%
        filter(filename == expected_filename)
    unsuffixed <- candidates %>%
        filter(!is_suffix_export)

    selected <- if (nrow(exact_match)) {
        exact_match %>% slice(1)
    } else if (nrow(unsuffixed)) {
        unsuffixed %>% arrange(desc(modified_at), filename) %>% slice(1)
    } else {
        candidates %>% arrange(desc(modified_at), filename) %>% slice(1)
    }

    selection_reason <- case_when(
        nrow(exact_match) > 0 ~ "preferred exact unsuffixed filename",
        nrow(unsuffixed) > 0 ~ "preferred unsuffixed filename among matching candidates",
        TRUE ~ "used most recent suffixed export because no unsuffixed filename was present"
    )

    tibble(
        selected_filename = selected$filename,
        selected_path = selected$path,
        selection_reason = selection_reason,
        candidate_count = nrow(candidates)
    )
}

data_files <- list.files(
    paths$data_root,
    full.names = TRUE,
    recursive = FALSE,
    all.files = FALSE
)
data_files <- data_files[file.exists(data_files) & !dir.exists(data_files)]

data_inventory <- tibble(path = data_files) %>%
    mutate(
        filename = basename(path),
        normalized_filename = strip_export_suffix(filename),
        extension = tools::file_ext(filename),
        is_suffix_export = str_detect(filename, "\\[[0-9]+\\](?=\\.[^.]+$)"),
        size_bytes = file.info(path)$size,
        modified_at = file.info(path)$mtime,
        modified_at_iso = timestamp_iso(modified_at),
        md5 = unname(tools::md5sum(path))
    ) %>%
    add_count(md5, name = "hash_group_size") %>%
    arrange(desc(modified_at), filename)

duplicate_groups <- data_inventory %>%
    filter(hash_group_size > 1) %>%
    group_by(md5) %>%
    summarize(
        canonical_filename = {
            unsuffixed <- filename[!is_suffix_export]
            if (length(unsuffixed)) sort(unsuffixed)[1] else sort(filename)[1]
        },
        duplicate_filenames = paste(sort(filename), collapse = "; "),
        duplicate_count = n(),
        .groups = "drop"
    )

required_inputs <- tribble(
    ~logical_name, ~expected_filename, ~dependent_script,
    "stats_wisconsin", "Stats Wisconsin (Nick Edited).xlsx", "scripts/endolaserless_analysis-2.R",
    "prn_injections", "prn_injections.xlsx", "scripts/count_prn_injections.R",
    "redcap_npa", "2024-10-22 Endolaserless_RedCap_Data.xlsx", "scripts/count_prn_injections.R"
)

required_input_selection <- required_inputs %>%
    mutate(selection = map(expected_filename, ~ choose_canonical_file(data_inventory, .x))) %>%
    tidyr::unnest(selection) %>%
    mutate(
        exists = !is.na(selected_path),
        normalized_filename = strip_export_suffix(expected_filename)
    )

stats_selection <- required_input_selection %>%
    filter(logical_name == "stats_wisconsin") %>%
    slice(1)
prn_selection <- required_input_selection %>%
    filter(logical_name == "prn_injections") %>%
    slice(1)
redcap_selection <- required_input_selection %>%
    filter(logical_name == "redcap_npa") %>%
    slice(1)

stats_expected_columns <- c("Subject ID", "schedule", "Week 4", "Week 16", "Week 152")
stats_required <- list(
    main_sheet = "Nick All NPI and Injections",
    missing_columns = character(),
    non_numeric_week_cells = tibble(),
    star_columns = tibble(),
    subject_coverage = tibble(),
    has_q8 = FALSE,
    has_q16 = FALSE
)

if (stats_selection$exists) {
    stats_sheets <- excel_sheets(stats_selection$selected_path)
    stats_sheet_name <- stats_sheets[6]
    stats_dat <- read_excel_quiet(stats_selection$selected_path, sheet = 6, n_max = 31)
    stats_week_columns <- names(stats_dat)[startsWith(names(stats_dat), "Week ")]
    stats_missing_columns <- setdiff(stats_expected_columns, names(stats_dat))
    stats_star_columns <- tibble(
        column = names(stats_dat),
        star_cells = vapply(stats_dat, function(col) {
            sum(str_detect(as.character(col), fixed("*")), na.rm = TRUE)
        }, integer(1))
    ) %>%
        filter(star_cells > 0)

    stats_non_numeric <- map_dfr(stats_week_columns, function(column_name) {
        raw_values <- as.character(stats_dat[[column_name]])
        cleaned_values <- gsub("*", "", raw_values, fixed = TRUE)
        bad_values <- raw_values[
            !is.na(raw_values) &
                is.na(suppressWarnings(as.numeric(cleaned_values)))
        ]

        tibble(
            column = column_name,
            issue_count = length(bad_values),
            example_values = paste(sort(unique(bad_values)), collapse = "; ")
        )
    }) %>%
        filter(issue_count > 0)

    stats_subject_coverage <- stats_dat %>%
        transmute(
            subject_id = .data[["Subject ID"]],
            schedule = as.character(schedule)
        ) %>%
        filter(!is.na(subject_id), !is.na(schedule), nzchar(schedule)) %>%
        distinct(subject_id, schedule) %>%
        count(schedule, name = "subject_count") %>%
        arrange(schedule)

    stats_required <- list(
        main_sheet = stats_sheet_name,
        missing_columns = stats_missing_columns,
        non_numeric_week_cells = stats_non_numeric,
        star_columns = stats_star_columns,
        subject_coverage = stats_subject_coverage,
        has_q8 = "q8" %in% stats_subject_coverage$schedule,
        has_q16 = "q16" %in% stats_subject_coverage$schedule
    )
}

prn_expected_columns <- c("subject_id", "group")
prn_required <- list(
    sheet_name = "all",
    missing_columns = character(),
    group_missing_count = NA_integer_,
    subject_coverage = tibble(),
    marker_columns = tibble(),
    week_label_patterns = tibble(),
    parse_caveat_columns = tibble()
)

if (prn_selection$exists) {
    prn_dat <- read_excel_quiet(prn_selection$selected_path, sheet = 1, n_max = 31)
    prn_week_columns <- names(prn_dat)[str_detect(names(prn_dat), regex("wk|week|post-op|post op", ignore_case = TRUE))]
    prn_missing_columns <- setdiff(prn_expected_columns, names(prn_dat))
    prn_group_missing_count <- sum(is.na(prn_dat$group) | str_trim(as.character(prn_dat$group)) == "")
    prn_subject_coverage <- prn_dat %>%
        transmute(subject_id, group = as.character(group)) %>%
        filter(!is.na(subject_id), !is.na(group), nzchar(group)) %>%
        distinct(subject_id, group) %>%
        count(group, name = "subject_count") %>%
        arrange(group)

    prn_marker_columns <- tibble(
        column = prn_week_columns,
        marker_cells = vapply(prn_dat[prn_week_columns], function(col) {
            sum(str_detect(as.character(col), fixed("*")), na.rm = TRUE)
        }, integer(1))
    ) %>%
        filter(marker_cells > 0)

    prn_week_label_patterns <- tibble(
        column = prn_week_columns,
        contains_wk = str_detect(prn_week_columns, regex("wk", ignore_case = TRUE)),
        contains_week = str_detect(prn_week_columns, regex("week", ignore_case = TRUE)),
        contains_post_op = str_detect(prn_week_columns, regex("post op", ignore_case = TRUE)),
        contains_post_dash = str_detect(prn_week_columns, regex("post-op", ignore_case = TRUE))
    )

    prn_transformed_columns <- normalize_prn_week_headers(prn_week_columns)
    prn_parse_caveat_columns <- tibble(
        original_column = prn_week_columns,
        transformed_column = prn_transformed_columns,
        becomes_standard_week = str_detect(prn_transformed_columns, "^week\\d+$")
    ) %>%
        filter(!becomes_standard_week)

    prn_required <- list(
        sheet_name = "all",
        missing_columns = prn_missing_columns,
        group_missing_count = prn_group_missing_count,
        subject_coverage = prn_subject_coverage,
        marker_columns = prn_marker_columns,
        week_label_patterns = prn_week_label_patterns,
        parse_caveat_columns = prn_parse_caveat_columns
    )
}

redcap_expected_columns <- c("Subject ID", "Group", "Event Name", "Nonperfusion area within eye")
redcap_required <- list(
    missing_columns = character(),
    group_missing_count = NA_integer_,
    group_missing_nonbaseline = tibble(),
    event_values = character(),
    not_gradable_count = NA_integer_,
    npa_sentinel_count = NA_integer_,
    npa_examples = tibble()
)

if (redcap_selection$exists) {
    redcap_dat <- read_excel_quiet(redcap_selection$selected_path)
    redcap_missing_columns <- setdiff(redcap_expected_columns, names(redcap_dat))
    redcap_group_missing_rows <- redcap_dat %>%
        transmute(
            subject_id = .data[["Subject ID"]],
            group = as.character(.data[["Group"]]),
            event_name = .data[["Event Name"]]
        ) %>%
        mutate(group_missing = is.na(group) | str_trim(group) == "")

    redcap_npa <- as.character(redcap_dat$`Nonperfusion area within eye`)
    redcap_npa_numeric <- suppressWarnings(as.numeric(redcap_npa))
    redcap_sentinel_rows <- redcap_dat %>%
        transmute(
            subject_id = .data[["Subject ID"]],
            event_name = .data[["Event Name"]],
            npa = as.character(.data[["Nonperfusion area within eye"]])
        ) %>%
        filter(
            str_to_lower(str_trim(npa)) == "not gradable" |
                suppressWarnings(as.numeric(npa)) >= 8888
        )

    redcap_required <- list(
        missing_columns = redcap_missing_columns,
        group_missing_count = sum(redcap_group_missing_rows$group_missing),
        group_missing_nonbaseline = redcap_group_missing_rows %>%
            filter(group_missing, event_name != "Week4 (baseline)") %>%
            select(subject_id, event_name) %>%
            distinct() %>%
            slice_head(n = 10),
        event_values = sort(unique(redcap_dat$`Event Name`)),
        not_gradable_count = sum(str_to_lower(str_trim(redcap_npa)) == "not gradable", na.rm = TRUE),
        npa_sentinel_count = sum(redcap_npa_numeric >= 8888, na.rm = TRUE),
        npa_examples = redcap_sentinel_rows %>% slice_head(n = 10)
    )
}

runtime_targets <- tribble(
    ~label, ~path,
    "canonical_processed_root", paths$npi_canonical_processed_root,
    "canonical_output_root", paths$npi_canonical_output_root,
    "prn_output_root", paths$npi_prn_output_root,
    "compatibility_processed_root", paths$npi_compatibility_processed_root
) %>%
    mutate(
        exists = dir.exists(path),
        latest_artifact_at = map(path, latest_file_timestamp),
        latest_artifact_at_iso = map_chr(latest_artifact_at, timestamp_iso),
        latest_artifact_at = as.POSIXct(unlist(latest_artifact_at), origin = "1970-01-01", tz = Sys.timezone())
    )

required_runtime_files <- tribble(
    ~label, ~path,
    "cached_long_input_data", file.path(paths$npi_canonical_processed_root, "cached_long_input_data.xlsx"),
    "cached_wide_input_data", file.path(paths$npi_canonical_processed_root, "cached_wide_input_data.xlsx"),
    "final_processed_workbook", file.path(paths$npi_processed_root, "FINAL_PROCESSED-npi_plus_all_injection_data.xlsx"),
    "prn_npa_by_week", file.path(paths$npi_prn_output_root, "npa_by_week.xlsx"),
    "prn_time_to_10", file.path(paths$npi_prn_output_root, "time_to_10_injections.xlsx")
) %>%
    mutate(
        exists = file.exists(path),
        modified_at = ifelse(exists, file.info(path)$mtime, as.POSIXct(NA)),
        modified_at_iso = timestamp_iso(as.POSIXct(modified_at, origin = "1970-01-01", tz = Sys.timezone()))
    )

docs_mirrors <- tibble(
    path = list.files("docs", pattern = "\\.png$", full.names = TRUE)
) %>%
    mutate(
        exists = file.exists(path),
        modified_at = ifelse(exists, file.info(path)$mtime, as.POSIXct(NA)),
        modified_at_iso = timestamp_iso(as.POSIXct(modified_at, origin = "1970-01-01", tz = Sys.timezone()))
    )

required_inputs_ready <- all(required_input_selection$exists)
runtime_ready <- all(required_runtime_files$exists)
prn_parse_has_caveat <- nrow(prn_required$parse_caveat_columns) > 0

rerun_readiness <- case_when(
    !required_inputs_ready ~ "not ready",
    !runtime_ready ~ "not ready",
    prn_parse_has_caveat ~ "ready with warnings",
    TRUE ~ "ready"
)

follow_on_shortlist <- tribble(
    ~priority_rank, ~project_name, ~claim_type, ~readiness_tier, ~blocking_issues, ~exact_input_files, ~affected_processed_workbooks, ~affected_outputs, ~docs_mirror_risk,
    1L,
    "Replication/cache-consistency pass",
    "descriptive",
    rerun_readiness,
    if (prn_parse_has_caveat) {
        "PRN week headers include 1-2 wk post-op and 20 wk post op; current rename rule does not fully standardize them."
    } else {
        "No blocking input issues detected for a rerun comparison."
    },
    paste(
        c(
            stats_selection$selected_filename,
            prn_selection$selected_filename,
            redcap_selection$selected_filename
        ),
        collapse = "; "
    ),
    paste(
        c(
            "processed_data/npi_project/output-week4_week16_baseline/cached_long_input_data.xlsx",
            "processed_data/npi_project/output-week4_week16_baseline/cached_wide_input_data.xlsx",
            "processed_data/npi_project/FINAL_PROCESSED-npi_plus_all_injection_data.xlsx"
        ),
        collapse = "; "
    ),
    paste(
        c(
            "output/npi_project/output-week4_week16_baseline",
            "output/npi_project/count_prn_injections"
        ),
        collapse = "; "
    ),
    "Repo docs/Figure*.png and docs/SupplementalFigure1.png are older than the latest runtime outputs and should be reviewed before treating them as current mirrors.",
    2L,
    "RedCap NPA refresh",
    "descriptive",
    "ready",
    "NPA missing-value handling is now clear, but downstream figure/table provenance still needs review.",
    redcap_selection$selected_filename,
    "processed_data/npi_project/FINAL_PROCESSED-npi_plus_all_injection_data.xlsx",
    "output/npi_project/count_prn_injections/npa_by_week.xlsx",
    "No direct docs/*.png dependency proven; review manuscript tables before mirroring any new NPA summary.",
    3L,
    "PRN reason stratification",
    "descriptive",
    if (prn_parse_has_caveat) "blocked" else "ready",
    if (prn_parse_has_caveat) {
        "Current PRN header normalization still leaves non-standard visit labels, so marker-by-week stratification is not yet robust."
    } else {
        "The PRN visit headers now normalize into a consistent week-based scheme."
    },
    prn_selection$selected_filename,
    "processed_data/npi_project/output-week4_week16_baseline/cached_long_input_data.xlsx",
    "output/npi_project/count_prn_injections",
    "No existing docs/*.png mirror appears to depend on PRN reason breakdowns.",
    4L,
    "Neovascularization modeling spin-up",
    "predictive",
    "not currently supported",
    "The neovascularization track is still scaffold-only and the audited top-level data files do not define a validated modeling-ready endpoint set for it.",
    "No canonical neovascularization raw workbook in top-level data/",
    "processed_data/neovascularization_project",
    "output/neovascularization_project",
    "No current repo docs mirror for this track."
)

write.csv(data_inventory, file.path(audit_output_dir, "raw_input_inventory.csv"), row.names = FALSE)
write.csv(duplicate_groups, file.path(audit_output_dir, "duplicate_hash_groups.csv"), row.names = FALSE)
write.csv(required_input_selection, file.path(audit_output_dir, "required_input_selection.csv"), row.names = FALSE)
write.csv(runtime_targets, file.path(audit_output_dir, "runtime_readiness.csv"), row.names = FALSE)
write.csv(follow_on_shortlist, file.path(audit_output_dir, "follow_on_project_shortlist.csv"), row.names = FALSE)

report_lines <- c(
    "# Latest Data Intake Audit",
    "",
    paste0("Generated: ", timestamp_iso(Sys.time())),
    paste0("Code root: ", paths$code_root),
    paste0("Cloud data root: ", paths$data_root),
    paste0("Runtime root: ", paths$runtime_root),
    paste0("Audit status: ", rerun_readiness),
    "",
    "## Canonical Required Inputs",
    ""
)

for (i in seq_len(nrow(required_input_selection))) {
    row <- required_input_selection[i, ]
    report_lines <- c(
        report_lines,
        paste0(
            "- `", row$logical_name, "` -> `", row$selected_filename, "`",
            if (!is.na(row$selected_path)) paste0(" (", row$selection_reason, ")") else " (missing)"
        ),
        paste0("  Path: ", row$selected_path),
        paste0("  Dependent script: ", row$dependent_script)
    )
}

report_lines <- c(report_lines, "", "## Duplicate Export Findings", "")

if (nrow(duplicate_groups)) {
    for (i in seq_len(nrow(duplicate_groups))) {
        row <- duplicate_groups[i, ]
        report_lines <- c(
            report_lines,
            paste0(
                "- Canonical `", row$canonical_filename, "` has ",
                row$duplicate_count - 1,
                " duplicate-content export(s): ",
                row$duplicate_filenames
            )
        )
    }
} else {
    report_lines <- c(report_lines, "- No duplicate-content top-level exports were found.")
}

report_lines <- c(
    report_lines,
    "",
    "## Stats Wisconsin Sheet 6",
    "",
    paste0("- Expected sheet used by the NPI pipeline: `", stats_required$main_sheet, "`"),
    paste0("- Missing required columns: ", if (length(stats_required$missing_columns)) paste(stats_required$missing_columns, collapse = ", ") else "none"),
    paste0(
        "- q8/q16 subject coverage: ",
        if (nrow(stats_required$subject_coverage)) {
            paste(
                paste0(stats_required$subject_coverage$schedule, "=", stats_required$subject_coverage$subject_count),
                collapse = "; "
            )
        } else {
            "not available"
        }
    )
)

if (nrow(stats_required$star_columns)) {
    report_lines <- c(
        report_lines,
        paste0(
            "- Starred cells detected in imported columns: ",
            paste(
                paste0(stats_required$star_columns$column, " (", stats_required$star_columns$star_cells, ")"),
                collapse = "; "
            )
        )
    )
}

if (nrow(stats_required$non_numeric_week_cells)) {
    report_lines <- c(report_lines, "- Non-numeric week-cell examples after stripping `*`:")
    for (i in seq_len(nrow(stats_required$non_numeric_week_cells))) {
        row <- stats_required$non_numeric_week_cells[i, ]
        report_lines <- c(
            report_lines,
            paste0("  - ", row$column, ": ", row$example_values, " (n=", row$issue_count, ")")
        )
    }
}

report_lines <- c(report_lines, "", "## PRN Workbook Sheet 1", "")
report_lines <- c(
    report_lines,
    paste0("- Missing required columns: ", if (length(prn_required$missing_columns)) paste(prn_required$missing_columns, collapse = ", ") else "none"),
    paste0("- Missing group rows: ", prn_required$group_missing_count),
    paste0(
        "- Subject coverage by group: ",
        if (nrow(prn_required$subject_coverage)) {
            paste(
                paste0(prn_required$subject_coverage$group, "=", prn_required$subject_coverage$subject_count),
                collapse = "; "
            )
        } else {
            "not available"
        }
    )
)

if (nrow(prn_required$marker_columns)) {
    report_lines <- c(
        report_lines,
        paste0(
            "- PRN marker columns with `*` or `**`: ",
            paste(
                paste0(prn_required$marker_columns$column, " (", prn_required$marker_columns$marker_cells, ")"),
                collapse = "; "
            )
        )
    )
}

report_lines <- c(
    report_lines,
    paste0(
        "- Mixed header formats observed: ",
        paste(prn_required$week_label_patterns$column, collapse = "; ")
    )
)

if (nrow(prn_required$parse_caveat_columns)) {
    report_lines <- c(report_lines, "- Current PRN rename rule does not fully normalize these headers:")
    for (i in seq_len(nrow(prn_required$parse_caveat_columns))) {
        row <- prn_required$parse_caveat_columns[i, ]
        report_lines <- c(
            report_lines,
            paste0("  - `", row$original_column, "` -> `", row$transformed_column, "`")
        )
    }
}

report_lines <- c(report_lines, "", "## RedCap NPA Input", "")
report_lines <- c(
    report_lines,
    paste0("- Missing required columns: ", if (length(redcap_required$missing_columns)) paste(redcap_required$missing_columns, collapse = ", ") else "none"),
    paste0("- Missing `Group` rows: ", redcap_required$group_missing_count),
    paste0("- Distinct event labels: ", paste(redcap_required$event_values, collapse = "; ")),
    paste0("- `not gradable` NPA rows: ", redcap_required$not_gradable_count),
    paste0("- NPA rows with numeric value `>= 8888`: ", redcap_required$npa_sentinel_count),
    "- Recommended canonical cleaning rule: treat `not gradable` and NPA values `>= 8888` as missing."
)

if (nrow(redcap_required$npa_examples)) {
    report_lines <- c(report_lines, "- Example RedCap sentinel rows:")
    for (i in seq_len(nrow(redcap_required$npa_examples))) {
        row <- redcap_required$npa_examples[i, ]
        report_lines <- c(
            report_lines,
            paste0("  - ", row$subject_id, " / ", row$event_name, " / ", row$npa)
        )
    }
}

report_lines <- c(report_lines, "", "## Runtime Readiness", "")

for (i in seq_len(nrow(runtime_targets))) {
    row <- runtime_targets[i, ]
    report_lines <- c(
        report_lines,
        paste0(
            "- `", row$label, "` exists=", row$exists,
            "; latest artifact=", row$latest_artifact_at_iso
        )
    )
}

for (i in seq_len(nrow(required_runtime_files))) {
    row <- required_runtime_files[i, ]
    report_lines <- c(
        report_lines,
        paste0(
            "- Required runtime file `", row$label, "` exists=", row$exists,
            "; modified=", row$modified_at_iso
        )
    )
}

report_lines <- c(
    report_lines,
    paste0("- Overall rerun readiness: ", rerun_readiness)
)

report_lines <- c(report_lines, "", "## Follow-on Project Shortlist", "")

for (i in seq_len(nrow(follow_on_shortlist))) {
    row <- follow_on_shortlist[i, ]
    report_lines <- c(
        report_lines,
        paste0(i, ". ", row$project_name),
        paste0("   Claim type: ", row$claim_type),
        paste0("   Readiness: ", row$readiness_tier),
        paste0("   Blocking issues: ", row$blocking_issues),
        paste0("   Exact inputs: ", row$exact_input_files),
        paste0("   Affected processed workbooks: ", row$affected_processed_workbooks),
        paste0("   Affected outputs: ", row$affected_outputs),
        paste0("   docs/*.png risk: ", row$docs_mirror_risk)
    )
}

report_lines <- c(report_lines, "", "## docs Mirror Review", "")

if (nrow(docs_mirrors)) {
    for (i in seq_len(nrow(docs_mirrors))) {
        row <- docs_mirrors[i, ]
        report_lines <- c(
            report_lines,
            paste0("- `", basename(row$path), "` modified ", row$modified_at_iso)
        )
    }
    report_lines <- c(
        report_lines,
        "- These repo figure mirrors predate the refreshed April 2026 runtime workbooks, so they should be reviewed before being treated as current publication mirrors."
    )
}

writeLines(report_lines, file.path(audit_output_dir, "latest_data_intake_audit.md"))

message("Wrote audit artifacts to: ", audit_output_dir)
