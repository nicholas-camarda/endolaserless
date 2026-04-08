# =============================================================================
# PATH CONFIGURATION
# =============================================================================
source(file.path("scripts", "project_paths.R"))


neovascularization_project_paths <- function(paths = endolaserless_paths()) {
    list(
        cloud_root = paths$neovascularization_project_root,
        runtime_output_root = paths$neovascularization_output_root,
        runtime_processed_root = paths$neovascularization_processed_root,
        raw_root = paths$neovascularization_raw_root,
        processed_root = paths$neovascularization_processed_archive_root,
        archive_root = paths$neovascularization_archive_root,
        notes_root = paths$neovascularization_archive_notes_root,
        published_root = paths$neovascularization_published_root
    )
}


ensure_neovascularization_project_layout <- function(paths = endolaserless_paths()) {
    layout <- neovascularization_project_paths(paths)
    all_dirs <- unique(unname(unlist(layout, use.names = FALSE)))

    invisible(lapply(all_dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
    layout
}


is_transient_neovascularization_path <- function(path) {
    normalized_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    path_parts <- strsplit(normalized_path, "/", fixed = TRUE)[[1]]
    file_name <- basename(normalized_path)

    any(path_parts %in% c("logs", "log", "tmp", "temp", "cache", "caches")) ||
        file_name %in% c(".DS_Store", "output_log.txt") ||
        grepl("\\.(log|tmp|temp|swp|bak)$", file_name, ignore.case = TRUE) ||
        grepl("(^|[._-])log([._-]|$)", file_name, ignore.case = TRUE)
}


relative_path_from_root <- function(path, root) {
    normalized_root <- normalizePath(root, winslash = "/", mustWork = FALSE)
    normalized_path <- normalizePath(path, winslash = "/", mustWork = FALSE)
    root_prefix <- paste0(normalized_root, "/")

    if (startsWith(normalized_path, root_prefix)) {
        substring(normalized_path, nchar(root_prefix) + 1)
    } else {
        basename(normalized_path)
    }
}


count_files_in_tree <- function(root) {
    if (!dir.exists(root)) {
        return(data.frame(
            file_count = 0L,
            total_bytes = 0,
            stringsAsFactors = FALSE
        ))
    }

    files <- list.files(
        root,
        recursive = TRUE,
        all.files = TRUE,
        include.dirs = FALSE,
        full.names = TRUE
    )
    files <- files[file.exists(files)]

    if (!length(files)) {
        return(data.frame(
            file_count = 0L,
            total_bytes = 0,
            stringsAsFactors = FALSE
        ))
    }

    file_info <- file.info(files)
    data.frame(
        file_count = length(files),
        total_bytes = sum(file_info$size, na.rm = TRUE),
        stringsAsFactors = FALSE
    )
}


inventory_neovascularization_project <- function(paths = endolaserless_paths()) {
    layout <- neovascularization_project_paths(paths)

    root_labels <- c(
        "cloud_root",
        "raw_root",
        "processed_root",
        "archive_root",
        "notes_root",
        "runtime_output_root",
        "runtime_processed_root",
        "published_root"
    )

    root_paths <- unname(unlist(layout[root_labels], use.names = FALSE))

    counts <- lapply(root_paths, count_files_in_tree)
    counts <- do.call(rbind, counts)

    data.frame(
        root = root_labels,
        path = root_paths,
        file_count = counts$file_count,
        total_bytes = counts$total_bytes,
        stringsAsFactors = FALSE
    )
}


mirror_neovascularization_published_outputs <- function(
    source_root = endolaserless_paths()$neovascularization_output_root,
    destination_root = endolaserless_paths()$neovascularization_published_root,
    overwrite = FALSE,
    dry_run = FALSE
) {
    if (!dir.exists(source_root)) {
        warning("Source root does not exist: ", source_root)
        return(data.frame(
            source = character(),
            destination = character(),
            copied = logical(),
            stringsAsFactors = FALSE
        ))
    }

    source_root <- normalizePath(source_root, winslash = "/", mustWork = FALSE)
    destination_root <- normalizePath(destination_root, winslash = "/", mustWork = FALSE)

    files <- list.files(
        source_root,
        recursive = TRUE,
        all.files = TRUE,
        include.dirs = FALSE,
        full.names = TRUE
    )
    files <- files[file.exists(files)]
    files <- files[!vapply(files, is_transient_neovascularization_path, logical(1))]

    if (!length(files)) {
        return(data.frame(
            source = character(),
            destination = character(),
            copied = logical(),
            stringsAsFactors = FALSE
        ))
    }

    results <- lapply(files, function(source_file) {
        relative_file <- relative_path_from_root(source_file, source_root)
        destination_file <- file.path(destination_root, relative_file)

        copied <- NA
        if (!dry_run) {
            dir.create(dirname(destination_file), recursive = TRUE, showWarnings = FALSE)
            copied <- file.copy(source_file, destination_file, overwrite = overwrite)
        }

        data.frame(
            source = source_file,
            destination = destination_file,
            copied = copied,
            stringsAsFactors = FALSE
        )
    })

    do.call(rbind, results)
}


run_neovascularization_project_scaffold <- function(
    sync_published_outputs = FALSE,
    overwrite = FALSE
) {
    layout <- ensure_neovascularization_project_layout()
    inventory <- inventory_neovascularization_project()
    sync_result <- NULL

    if (isTRUE(sync_published_outputs)) {
        sync_result <- mirror_neovascularization_published_outputs(
            overwrite = overwrite
        )
    }

    list(
        layout = layout,
        inventory = inventory,
        published_sync = sync_result
    )
}


# The scientific analysis for this track is intentionally left as a scaffold
# until the raw input inventory and endpoint dictionary are finalized.
# Planned stages:
# - inventory raw inputs and define the neovascularization endpoint map
# - build longitudinal processed tables from the raw source data
# - fit mixed-effects and time-to-event models
# - export and mirror publishable outputs into the cloud archive
