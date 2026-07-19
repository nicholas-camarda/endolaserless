path_env_names <- c(
    "ENDOLASERLESS_CODE_ROOT",
    "ENDOLASERLESS_RUNTIME_ROOT",
    "ENDOLASERLESS_CLOUD_ROOT"
)

restore_output_test_environment <- function(old_values) {
    Sys.unsetenv(path_env_names)
    present <- !is.na(old_values)
    if (any(present)) {
        do.call(Sys.setenv, as.list(old_values[present]))
    }
}

active_script_text <- function() {
    script_files <- sort(list.files("scripts", pattern = "[.]R$", full.names = TRUE))
    lines <- unlist(lapply(script_files, readLines, warn = FALSE), use.names = FALSE)
    trimmed <- trimws(lines)
    paste(trimmed[nzchar(trimmed) & !startsWith(trimmed, "#")], collapse = "\n")
}

active_file_text <- function(path) {
    lines <- readLines(path, warn = FALSE)
    trimmed <- trimws(lines)
    paste(trimmed[nzchar(trimmed) & !startsWith(trimmed, "#")], collapse = "\n")
}

run_output_boundary_contract <- function() {
    old_values <- Sys.getenv(path_env_names, unset = NA_character_)
    names(old_values) <- path_env_names
    on.exit(restore_output_test_environment(old_values), add = TRUE)

    temporary_root <- tempfile("endolaserless-output-contract-")
    source_root <- file.path(temporary_root, "source")
    runtime_root <- file.path(temporary_root, "runtime")
    cloud_root <- file.path(temporary_root, "vault")
    dir.create(source_root, recursive = TRUE)

    do.call(Sys.setenv, list(
        ENDOLASERLESS_CODE_ROOT = source_root,
        ENDOLASERLESS_RUNTIME_ROOT = runtime_root,
        ENDOLASERLESS_CLOUD_ROOT = cloud_root
    ))

    source(file.path("scripts", "neovascularization_project.R"), local = TRUE)
    layout <- ensure_neovascularization_project_layout()

    stopifnot(
        dir.exists(layout$runtime_output_root),
        dir.exists(layout$runtime_processed_root),
        !dir.exists(cloud_root),
        identical(formals(mirror_neovascularization_published_outputs)$dry_run, TRUE)
    )

    source_file <- file.path(layout$runtime_output_root, "shareable.csv")
    writeLines(c("value", "1"), source_file)
    preview <- mirror_neovascularization_published_outputs(dry_run = TRUE)
    stopifnot(
        nrow(preview) == 1L,
        all(is.na(preview$copied)),
        !dir.exists(cloud_root)
    )

    script_text <- active_script_text()
    npi_text <- active_file_text(file.path("scripts", "endolaserless_analysis-2.R"))
    prn_text <- active_file_text(file.path("scripts", "count_prn_injections.R"))
    stopifnot(
        !grepl("~/Downloads", script_text, fixed = TRUE),
        !grepl("/OneDrive-Personal/Research/endolaserless", script_text, fixed = TRUE),
        !grepl('"ENDOLASERLESS_CODE_ROOT",\ngetwd()', script_text, fixed = TRUE),
        grepl(
            'runtime_plot_file <- file.path(top_output_dir, "npi_plots.pdf")',
            npi_text,
            fixed = TRUE
        ),
        grepl(
            'runtime_plot_file <- file.path(base_output_dir, "prn_plots.pdf")',
            prn_text,
            fixed = TRUE
        ),
        grepl(
            "options(device = function(...) grDevices::pdf(",
            npi_text,
            fixed = TRUE
        ),
        grepl(
            "options(device = function(...) grDevices::pdf(",
            prn_text,
            fixed = TRUE
        )
    )
}

run_output_boundary_contract()
