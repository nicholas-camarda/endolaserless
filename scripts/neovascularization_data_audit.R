# =============================================================================
# NEOVASCULARIZATION DATA AUDIT
# =============================================================================
source(file.path("scripts", "project_paths.R"))

suppressPackageStartupMessages({
    library(digest)
    library(dplyr)
    library(readxl)
    library(tidyr)
})


paths <- endolaserless_paths()

processed_dir <- paths$neovascularization_processed_root
output_dir <- paths$neovascularization_output_root
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)


spreadsheet_ext <- c("xlsx", "xlsm", "xls", "csv")


normalize_subject_id <- function(value) {
    vapply(as.character(value), function(item) {
        if (is.na(item) || !nzchar(item)) {
            return(NA_character_)
        }
        match <- regmatches(item, regexpr("L-?[0-9]+", item, ignore.case = TRUE))
        if (!length(match) || is.na(match) || !nzchar(match)) {
            return(NA_character_)
        }
        digits <- gsub("[^0-9]", "", match)
        number <- suppressWarnings(as.integer(digits))
        if (is.na(number)) {
            return(NA_character_)
        }
        sprintf("L-%02d", number)
    }, character(1))
}


normalize_status <- function(value, allowed = c("yes", "no")) {
    raw <- trimws(as.character(value))
    raw[raw == "" | is.na(raw)] <- NA_character_
    lowered <- tolower(raw)
    dplyr::case_when(
        lowered %in% allowed ~ paste0(toupper(substr(lowered, 1, 1)), substr(lowered, 2, nchar(lowered))),
        lowered %in% c("worse", "worsened") ~ "Worsened",
        lowered %in% c("improved", "imprroved") ~ "Improved",
        lowered %in% c("unchanged", "no change") ~ "Unchanged",
        lowered %in% c("indeterminate", "indeterminant") ~ "Indeterminate",
        lowered %in% c("missed", "missed visit", "lost to follow-up") ~ "Missed",
        TRUE ~ raw
    )
}


normalize_schedule <- function(value) {
    raw <- tolower(trimws(as.character(value)))
    raw[raw == "" | is.na(raw)] <- NA_character_
    dplyr::case_when(
        raw %in% c("q8", "q8week", "q8 week", "8") ~ "q8",
        raw %in% c("q16", "q16week", "q16 week", "16") ~ "q16",
        TRUE ~ NA_character_
    )
}


excel_date_to_date <- function(value) {
    if (inherits(value, "Date")) {
        return(value)
    }
    if (inherits(value, "POSIXt")) {
        return(as.Date(value))
    }

    raw <- trimws(as.character(value))
    raw[raw == "" | is.na(raw)] <- NA_character_

    numeric_value <- suppressWarnings(as.numeric(raw))
    out <- as.Date(rep(NA_real_, length(raw)), origin = "1899-12-30")
    numeric_idx <- !is.na(numeric_value)
    out[numeric_idx] <- as.Date(numeric_value[numeric_idx], origin = "1899-12-30")

    date_idx <- !numeric_idx & !is.na(raw)
    if (any(date_idx)) {
        parsed <- as.Date(raw[date_idx], tryFormats = c(
            "%m/%d/%y",
            "%m/%d/%Y",
            "%Y-%m-%d"
        ))
        out[date_idx] <- parsed
    }

    out
}


clean_numeric_with_threshold <- function(value, threshold) {
    numeric_value <- suppressWarnings(as.numeric(value))
    numeric_value[numeric_value >= threshold] <- NA_real_
    numeric_value
}


spreadsheet_files <- function() {
    candidate_roots <- c(
        paths$data_root,
        paths$neovascularization_published_root
    )
    existing_roots <- candidate_roots[dir.exists(candidate_roots)]
    files <- unlist(lapply(existing_roots, function(root) {
        list.files(root, recursive = TRUE, all.files = FALSE, full.names = TRUE)
    }))
    files[file.exists(files) & tolower(tools::file_ext(files)) %in% spreadsheet_ext]
}


classify_source_role <- function(file_path) {
    normalized <- normalizePath(file_path, winslash = "/", mustWork = FALSE)
    data_root <- normalizePath(paths$data_root, winslash = "/", mustWork = FALSE)
    old_root <- file.path(data_root, "old")
    published_root <- normalizePath(paths$neovascularization_published_root, winslash = "/", mustWork = FALSE)

    dplyr::case_when(
        startsWith(normalized, paste0(old_root, "/")) ~ "historical_data",
        dirname(normalized) == data_root ~ "current_data",
        startsWith(normalized, paste0(published_root, "/")) ~ "neovascularization_published_mirror",
        TRUE ~ "other"
    )
}


inventory_sources <- function() {
    files <- spreadsheet_files()
    if (!length(files)) {
        return(data.frame())
    }

    info <- file.info(files)
    inventory <- data.frame(
        file_path = normalizePath(files, winslash = "/", mustWork = FALSE),
        file_name = basename(files),
        source_role = vapply(files, classify_source_role, character(1)),
        extension = tolower(tools::file_ext(files)),
        size_bytes = info$size,
        modified_time = format(info$mtime, "%Y-%m-%d %H:%M:%S %Z"),
        md5 = vapply(files, digest::digest, character(1), file = TRUE, algo = "md5"),
        stringsAsFactors = FALSE
    )

    inventory %>%
        mutate(
            is_suffixed_export = grepl("\\[[0-9]+\\](?=\\.[^.]+$)", file_name, perl = TRUE),
            candidate_neovascularization_source = grepl(
                "redcap|wisconsin|laserless study data updated|southeastretinalaser|model_summary",
                file_name,
                ignore.case = TRUE
            )
        ) %>%
        arrange(source_role, file_name)
}


duplicate_hash_groups <- function(inventory) {
    if (!nrow(inventory)) {
        return(data.frame())
    }

    inventory %>%
        group_by(md5) %>%
        filter(n() > 1) %>%
        ungroup() %>%
        group_by(md5) %>%
        mutate(
            duplicate_group_id = cur_group_id(),
            preferred_candidate = source_role == "current_data" & !is_suffixed_export
        ) %>%
        ungroup() %>%
        select(
            duplicate_group_id,
            md5,
            preferred_candidate,
            source_role,
            file_name,
            file_path,
            size_bytes,
            modified_time
        ) %>%
        arrange(duplicate_group_id, desc(preferred_candidate), file_name)
}


parse_active_neovascularization_summary <- function() {
    input_file <- file.path(paths$data_root, "Laserless Study DATA Updated for 3 Year Data (1).xlsx")
    if (!file.exists(input_file)) {
        stop("Missing FAFundus source workbook: ", input_file)
    }

    raw <- read_excel(input_file, sheet = "FAFundus Readout", .name_repair = "minimal")
    names(raw) <- c(
        "label",
        "blank",
        "study_eye",
        "first_fa_date_raw",
        "last_fa_date_raw",
        "fa_macular_leakage_raw",
        "fa_macular_leakage_change_raw",
        "active_neovascularization_raw",
        "fa_neovascularization_change_raw",
        "fundus_dme_change_raw"
    )

    schedule <- rep(NA_character_, nrow(raw))
    current_schedule <- NA_character_
    for (i in seq_len(nrow(raw))) {
        label <- as.character(raw$label[i])
        if (!is.na(label) && grepl("Q16", label, ignore.case = TRUE)) {
            current_schedule <- "q16"
        } else if (!is.na(label) && grepl("Q8", label, ignore.case = TRUE)) {
            current_schedule <- "q8"
        }
        schedule[i] <- current_schedule
    }

    raw %>%
        mutate(
            schedule = schedule,
            subject_id = normalize_subject_id(label),
            first_fa_date = excel_date_to_date(first_fa_date_raw),
            last_fa_date = excel_date_to_date(last_fa_date_raw),
            fa_macular_leakage = normalize_status(fa_macular_leakage_raw),
            fa_macular_leakage_change = normalize_status(
                fa_macular_leakage_change_raw,
                allowed = c("improved", "unchanged", "worsened", "indeterminate", "missed")
            ),
            active_neovascularization = normalize_status(active_neovascularization_raw),
            fa_neovascularization_change = normalize_status(
                fa_neovascularization_change_raw,
                allowed = c("improved", "unchanged", "worsened", "indeterminate", "missed")
            )
        ) %>%
        filter(
            !is.na(subject_id),
            !is.na(schedule),
            !is.na(active_neovascularization) | !is.na(fa_neovascularization_change)
        ) %>%
        transmute(
            source_file = input_file,
            source_sheet = "FAFundus Readout",
            schedule,
            subject_id,
            source_label = label,
            study_eye,
            first_fa_date,
            last_fa_date,
            fa_macular_leakage_raw,
            fa_macular_leakage,
            fa_macular_leakage_change_raw,
            fa_macular_leakage_change,
            active_neovascularization_raw,
            active_neovascularization,
            fa_neovascularization_change_raw,
            fa_neovascularization_change,
            fundus_dme_change_raw = normalize_status(
                fundus_dme_change_raw,
                allowed = c("improved", "unchanged", "worsened", "indeterminate", "missed")
            )
        ) %>%
        arrange(schedule, subject_id)
}


read_endpoint_source <- function(source_file, source_sheet, source_id, schedule_lookup) {
    raw <- read_excel(source_file, sheet = source_sheet, .name_repair = "minimal")

    required_names <- c(
        "Subject ID",
        "Group",
        "Event Name",
        "Timepoint",
        "Leakage area within ETDRS grid",
        "Leakage distance to fovea within the ETDRS grid",
        "Leakage area within 7F",
        "Leakage area within eye",
        "Presence of retinal vascular leakage",
        "NVD",
        "Change in NVD (area) from Week 4 (baseline)",
        "Change in NVD (area) from previous visit",
        "NVE within 7F grid",
        "NVE beyond 7F grid",
        "NVE count",
        "Change in NVE (area and count) from Week 4 (baseline)",
        "Change in NVE (area and count) from previous visit"
    )

    for (name in setdiff(required_names, names(raw))) {
        raw[[name]] <- NA
    }

    out <- raw %>%
        transmute(
            source_id = source_id,
            source_file = source_file,
            source_sheet = source_sheet,
            subject_id = normalize_subject_id(`Subject ID`),
            schedule_from_source = normalize_schedule(Group),
            event_name = as.character(`Event Name`),
            timepoint = as.character(Timepoint),
            week = suppressWarnings(as.integer(gsub("[^0-9]", "", as.character(Timepoint)))),
            leakage_area_etdrs_grid_raw = as.character(`Leakage area within ETDRS grid`),
            leakage_distance_to_fovea_etdrs_grid_raw = as.character(`Leakage distance to fovea within the ETDRS grid`),
            leakage_area_7f_raw = as.character(`Leakage area within 7F`),
            leakage_area_eye_raw = as.character(`Leakage area within eye`),
            leakage_presence = normalize_status(
                `Presence of retinal vascular leakage`,
                allowed = c("definite", "absent")
            ),
            nvd = normalize_status(NVD, allowed = c("definite", "absent")),
            nvd_change_from_week4 = normalize_status(
                `Change in NVD (area) from Week 4 (baseline)`,
                allowed = c("definitely less nvd", "definitely more nvd", "nvd the same", "cannot grade")
            ),
            nvd_change_from_previous = normalize_status(
                `Change in NVD (area) from previous visit`,
                allowed = c("definitely less nvd", "definitely more nvd", "nvd the same", "cannot grade")
            ),
            nve_within_7f = normalize_status(`NVE within 7F grid`, allowed = c("definite", "absent")),
            nve_beyond_7f = normalize_status(`NVE beyond 7F grid`, allowed = c("definite", "absent")),
            nve_count = as.character(`NVE count`),
            nve_change_from_week4 = normalize_status(
                `Change in NVE (area and count) from Week 4 (baseline)`,
                allowed = c("definitely less nve", "definitely more nve", "nve the same", "cannot grade")
            ),
            nve_change_from_previous = normalize_status(
                `Change in NVE (area and count) from previous visit`,
                allowed = c("definitely less nve", "definitely more nve", "nve the same", "cannot grade")
            ),
            leakage_area_etdrs_grid = clean_numeric_with_threshold(`Leakage area within ETDRS grid`, 88),
            leakage_distance_to_fovea_etdrs_grid = suppressWarnings(as.numeric(`Leakage distance to fovea within the ETDRS grid`)),
            leakage_area_7f = clean_numeric_with_threshold(`Leakage area within 7F`, 888),
            leakage_area_eye = clean_numeric_with_threshold(`Leakage area within eye`, 8888)
        ) %>%
        filter(!is.na(subject_id), subject_id != "TEST") %>%
        left_join(schedule_lookup, by = "subject_id") %>%
        mutate(
            schedule = coalesce(schedule_from_source, schedule_lookup),
            any_raw_definite_neovascularization = nvd == "Definite" |
                nve_within_7f == "Definite" |
                nve_beyond_7f == "Definite",
            all_raw_neovascularization_absent = nvd == "Absent" &
                nve_within_7f == "Absent" &
                nve_beyond_7f == "Absent",
            raw_neovascularization_status = case_when(
                any_raw_definite_neovascularization ~ "raw_definite_nv",
                all_raw_neovascularization_absent ~ "raw_absent_nv",
                TRUE ~ "raw_insufficient_or_cannot_grade"
            )
        )

    out %>%
        select(
            source_id,
            source_file,
            source_sheet,
            schedule,
            subject_id,
            event_name,
            timepoint,
            week,
            leakage_presence,
            nvd,
            nvd_change_from_week4,
            nvd_change_from_previous,
            nve_within_7f,
            nve_beyond_7f,
            nve_count,
            nve_change_from_week4,
            nve_change_from_previous,
            leakage_area_etdrs_grid_raw,
            leakage_area_etdrs_grid,
            leakage_distance_to_fovea_etdrs_grid_raw,
            leakage_distance_to_fovea_etdrs_grid,
            leakage_area_7f_raw,
            leakage_area_7f,
            leakage_area_eye_raw,
            leakage_area_eye,
            any_raw_definite_neovascularization,
            all_raw_neovascularization_absent,
            raw_neovascularization_status
        )
}


parse_raw_longitudinal_endpoints <- function() {
    redcap_file <- file.path(paths$data_root, "2024-10-22 Endolaserless_RedCap_Data.xlsx")
    wisconsin_file <- file.path(paths$data_root, "Wisconsis_study_data_analysis_FAgradng_MASTERsheet7.10.24.xlsm")
    old_wisconsin_file <- file.path(paths$data_root, "old", "Wisconsin Raw Data.xlsm")

    if (!file.exists(redcap_file)) {
        stop("Missing RedCap source workbook: ", redcap_file)
    }

    redcap_raw <- read_excel(redcap_file, sheet = "RedCap", .name_repair = "minimal")
    schedule_lookup <- redcap_raw %>%
        transmute(
            subject_id = normalize_subject_id(`Subject ID`),
            schedule_lookup = normalize_schedule(Group)
        ) %>%
        filter(!is.na(subject_id), !is.na(schedule_lookup)) %>%
        distinct(subject_id, schedule_lookup)

    sources <- list(
        list(redcap_file, "RedCap", "redcap_current"),
        list(wisconsin_file, "SoutheastRetinaLaser_DATA_org", "wisconsin_master_current"),
        list(old_wisconsin_file, "SoutheastRetinaLaser_DATA_org", "wisconsin_raw_old")
    )

    tables <- lapply(sources, function(source) {
        source_file <- source[[1]]
        source_sheet <- source[[2]]
        source_id <- source[[3]]

        if (!file.exists(source_file)) {
            warning("Skipping missing raw endpoint source: ", source_file)
            return(NULL)
        }

        read_endpoint_source(source_file, source_sheet, source_id, schedule_lookup)
    })

    bind_rows(tables) %>%
        arrange(source_id, schedule, subject_id, week)
}


latest_raw_by_subject <- function(raw_longitudinal) {
    raw_longitudinal %>%
        filter(
            source_id == "redcap_current",
            !is.na(week),
            !is.na(raw_neovascularization_status)
        ) %>%
        arrange(subject_id, desc(week)) %>%
        group_by(subject_id) %>%
        slice(1) %>%
        ungroup() %>%
        transmute(
            subject_id,
            latest_raw_week = week,
            latest_raw_timepoint = timepoint,
            latest_raw_nvd = nvd,
            latest_raw_nve_within_7f = nve_within_7f,
            latest_raw_nve_beyond_7f = nve_beyond_7f,
            latest_raw_nve_count = nve_count,
            latest_raw_neovascularization_status = raw_neovascularization_status
        )
}


reconcile_endpoints <- function(active_summary, raw_longitudinal) {
    active_summary %>%
        left_join(latest_raw_by_subject(raw_longitudinal), by = "subject_id") %>%
        mutate(
            active_nv_binary = case_when(
                active_neovascularization == "Yes" ~ "summary_active_nv_present",
                active_neovascularization == "No" ~ "summary_active_nv_absent",
                TRUE ~ "summary_not_binary"
            ),
            reconciliation_status = case_when(
                is.na(latest_raw_neovascularization_status) ~ "insufficient_raw_evidence",
                active_nv_binary == "summary_not_binary" ~ "summary_not_binary",
                latest_raw_neovascularization_status == "raw_insufficient_or_cannot_grade" ~ "insufficient_raw_evidence",
                active_nv_binary == "summary_active_nv_present" &
                    latest_raw_neovascularization_status == "raw_definite_nv" ~ "concordant_present",
                active_nv_binary == "summary_active_nv_absent" &
                    latest_raw_neovascularization_status == "raw_absent_nv" ~ "concordant_absent",
                active_nv_binary == "summary_active_nv_present" &
                    latest_raw_neovascularization_status == "raw_absent_nv" ~ "discordant_summary_yes_raw_absent",
                active_nv_binary == "summary_active_nv_absent" &
                    latest_raw_neovascularization_status == "raw_definite_nv" ~ "discordant_summary_no_raw_present",
                TRUE ~ "unclassified"
            )
        ) %>%
        arrange(schedule, subject_id)
}


write_report <- function(inventory, duplicates, active_summary, raw_longitudinal, reconciliation) {
    report_path <- file.path(output_dir, "neovascularization_feasibility_report.md")

    active_counts <- active_summary %>%
        count(schedule, active_neovascularization, name = "n") %>%
        arrange(schedule, active_neovascularization)

    raw_counts <- raw_longitudinal %>%
        group_by(source_id) %>%
        summarize(
            rows = n(),
            subjects = n_distinct(subject_id),
            definite_nvd_rows = sum(nvd == "Definite", na.rm = TRUE),
            definite_nve_within_7f_rows = sum(nve_within_7f == "Definite", na.rm = TRUE),
            definite_nve_beyond_7f_rows = sum(nve_beyond_7f == "Definite", na.rm = TRUE),
            definite_leakage_rows = sum(leakage_presence == "Definite", na.rm = TRUE),
            absent_leakage_rows = sum(leakage_presence == "Absent", na.rm = TRUE),
            .groups = "drop"
        ) %>%
        arrange(source_id)

    reconciliation_counts <- reconciliation %>%
        count(reconciliation_status, name = "n") %>%
        arrange(desc(n))

    discordant_summary_yes <- reconciliation %>%
        filter(reconciliation_status == "discordant_summary_yes_raw_absent")

    insufficient_evidence <- reconciliation %>%
        filter(reconciliation_status == "insufficient_raw_evidence")

    duplicate_summary <- duplicates %>%
        group_by(duplicate_group_id, md5) %>%
        summarize(
            files = paste(file_name, collapse = "; "),
            preferred = paste(file_name[preferred_candidate], collapse = "; "),
            .groups = "drop"
        )

    lines <- c(
        "# Neovascularization Data Audit",
        "",
        paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
        paste("Code root:", paths$code_root),
        paste("Cloud data root:", paths$data_root),
        paste("Runtime processed root:", processed_dir),
        paste("Runtime output root:", output_dir),
        "",
        "## Scope",
        "",
        "This audit builds a descriptive neovascularization endpoint dataset. It does not support treatment-effect, causal, predictive, survival, equivalence, or q8/q16 efficacy modeling.",
        "",
        "## Source Inventory",
        "",
        paste("- Spreadsheet files inventoried:", nrow(inventory)),
        paste("- Duplicate-content file rows:", nrow(duplicates)),
        paste("- Duplicate-content groups:", dplyr::n_distinct(duplicates$duplicate_group_id)),
        "",
        "### Duplicate-content groups",
        if (nrow(duplicate_summary)) {
            paste(
                "- Group",
                duplicate_summary$duplicate_group_id,
                "preferred:",
                ifelse(nzchar(duplicate_summary$preferred), duplicate_summary$preferred, "none"),
                "| files:",
                duplicate_summary$files
            )
        } else {
            "- None detected."
        },
        "",
        "## Active Neovascularization Summary",
        "",
        paste("- Parsed FAFundus rows:", nrow(active_summary)),
        paste("- Subjects:", dplyr::n_distinct(active_summary$subject_id)),
        "",
        paste(
            "-",
            active_counts$schedule,
            active_counts$active_neovascularization,
            active_counts$n,
            sep = " "
        ),
        "",
        "## Raw Endpoint Support",
        "",
        paste(
            "-",
            raw_counts$source_id,
            "rows",
            raw_counts$rows,
            "subjects",
            raw_counts$subjects,
            "definite NVD",
            raw_counts$definite_nvd_rows,
            "definite NVE within 7F",
            raw_counts$definite_nve_within_7f_rows,
            "definite NVE beyond 7F",
            raw_counts$definite_nve_beyond_7f_rows,
            "definite leakage",
            raw_counts$definite_leakage_rows
        ),
        "",
        "## Endpoint Reconciliation",
        "",
        paste("- Reconciled subjects:", nrow(reconciliation)),
        paste("-",
              reconciliation_counts$reconciliation_status,
              reconciliation_counts$n,
              sep = " "),
        "",
        "### Endpoint decision point",
        "",
        paste(
            "- Summary-positive active neovascularization rows with latest raw NVD/NVE absent:",
            nrow(discordant_summary_yes)
        ),
        paste(
            "- Summary rows with insufficient latest raw NVD/NVE evidence:",
            nrow(insufficient_evidence)
        ),
        "- These rows are the main provenance/adjudication issue for the neovascularization project.",
        "- Before treating `FAFundus Readout` as an authoritative active-neovascularization endpoint, a clinician or source-data owner should review `endpoint_reconciliation.csv` and decide whether the summary field reflects adjudicated clinical active NV beyond the raw NVD/NVE fields, or whether the raw Wisconsin/RedCap NVD/NVE fields should govern.",
        "- Until that decision is documented, the active-neovascularization summary should be used only for descriptive feasibility reporting and not as a validated clinical outcome.",
        if (nrow(discordant_summary_yes)) {
            paste(
                "- Discordant summary-positive subjects:",
                paste(discordant_summary_yes$subject_id, collapse = ", ")
            )
        } else {
            "- Discordant summary-positive subjects: none"
        },
        if (nrow(insufficient_evidence)) {
            paste(
                "- Insufficient raw-evidence subjects:",
                paste(insufficient_evidence$subject_id, collapse = ", ")
            )
        } else {
            "- Insufficient raw-evidence subjects: none"
        },
        "",
        "## Feasibility Conclusion",
        "",
        "- Primary active-neovascularization summary endpoint: usable for descriptive source and feasibility reporting.",
        "- Strict NVD endpoint: sparse; not suitable for modeling or q8/q16 efficacy claims.",
        "- Raw NVE endpoints: limited and subject-concentrated; suitable as descriptive context only.",
        "- Retinal vascular leakage: richer than NVD/NVE and suitable for descriptive context, but it is not the primary endpoint in this audit.",
        "- Existing `model_summary_combined.xlsx` is not reused by this workflow and should not be treated as validated evidence without regeneration from cleaned source data.",
        "",
        "## Output Artifacts",
        "",
        paste("- Processed:", file.path(processed_dir, "source_inventory.csv")),
        paste("- Processed:", file.path(processed_dir, "duplicate_hash_groups.csv")),
        paste("- Processed:", file.path(processed_dir, "active_neovascularization_summary.csv")),
        paste("- Processed:", file.path(processed_dir, "raw_longitudinal_neovascularization.csv")),
        paste("- Processed:", file.path(processed_dir, "endpoint_reconciliation.csv")),
        paste("- Report:", report_path)
    )

    writeLines(lines, report_path)
    report_path
}


run_neovascularization_data_audit <- function() {
    inventory <- inventory_sources()
    duplicates <- duplicate_hash_groups(inventory)
    active_summary <- parse_active_neovascularization_summary()
    raw_longitudinal <- parse_raw_longitudinal_endpoints()
    reconciliation <- reconcile_endpoints(active_summary, raw_longitudinal)

    write.csv(inventory, file.path(processed_dir, "source_inventory.csv"), row.names = FALSE)
    write.csv(duplicates, file.path(processed_dir, "duplicate_hash_groups.csv"), row.names = FALSE)
    write.csv(active_summary, file.path(processed_dir, "active_neovascularization_summary.csv"), row.names = FALSE)
    write.csv(raw_longitudinal, file.path(processed_dir, "raw_longitudinal_neovascularization.csv"), row.names = FALSE)
    write.csv(reconciliation, file.path(processed_dir, "endpoint_reconciliation.csv"), row.names = FALSE)

    report_path <- write_report(inventory, duplicates, active_summary, raw_longitudinal, reconciliation)

    list(
        inventory = inventory,
        duplicates = duplicates,
        active_summary = active_summary,
        raw_longitudinal = raw_longitudinal,
        reconciliation = reconciliation,
        report_path = report_path
    )
}


if (identical(environment(), globalenv())) {
    result <- run_neovascularization_data_audit()
    message("Wrote neovascularization feasibility report: ", result$report_path)
}
