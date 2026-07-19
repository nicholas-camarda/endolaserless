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

find_protected_write_calls <- function(input) {
    tree <- if (is.character(input) && length(input) == 1L) parse(input) else input
    mutating_functions <- c(
        "dir.create", "file", "file.copy", "file.rename", "ggsave", "pdf",
        "png", "save", "save.image", "saveRDS", "sink", "unlink",
        "write.csv", "write.csv2", "write.table", "write.xlsx", "writeLines"
    )
    protected_roots <- c(
        "paths$code_root",
        "paths$cloud_root",
        "paths$data_root",
        "paths$documents_root",
        "paths$durable_outputs_root",
        "paths$npi_archive_root",
        "paths$npi_durable_outputs_root",
        "paths$npi_project_root",
        "paths$neovascularization_archive_notes_root",
        "paths$neovascularization_archive_root",
        "paths$neovascularization_durable_outputs_root",
        "paths$neovascularization_processed_archive_root",
        "paths$neovascularization_project_root",
        "paths$neovascularization_published_root",
        "paths$neovascularization_raw_root",
        "paths$references_root"
    )
    findings <- character()
    protected_aliases <- character()

    call_name <- function(node) {
        head <- node[[1L]]
        if (is.symbol(head)) {
            return(as.character(head))
        }
        if (is.call(head) && as.character(head[[1L]]) %in% c("::", ":::")) {
            return(as.character(head[[3L]]))
        }
        ""
    }

    is_protected_path_expression <- function(node) {
        rendered <- paste(deparse(node, width.cutoff = 500L), collapse = " ")
        if (rendered %in% protected_roots) {
            return(TRUE)
        }
        if (is.symbol(node) && as.character(node) %in% protected_aliases) {
            return(TRUE)
        }
        if (is.call(node) && call_name(node) %in% c("file.path", "normalizePath", "path.expand")) {
            return(any(vapply(as.list(node)[-1L], is_protected_path_expression, logical(1))))
        }
        FALSE
    }

    mutation_targets <- function(node) {
        name <- call_name(node)
        arguments <- as.list(node)[-1L]
        if (name %in% c("file.copy", "file.rename")) {
            return(arguments[intersect(2L, seq_along(arguments))])
        }
        if (name %in% c(
            "write.csv", "write.csv2", "write.table", "write.xlsx", "writeLines"
        )) {
            index <- if (length(arguments) == 1L) 1L else 2L
            return(arguments[intersect(index, seq_along(arguments))])
        }
        if (name == "save") {
            named_file <- which(names(arguments) == "file")
            return(arguments[named_file])
        }
        arguments[intersect(1L, seq_along(arguments))]
    }

    collect_aliases <- function(node) {
        changed <- FALSE
        if (is.call(node)) {
            if (
                call_name(node) %in% c("<-", "=") && length(node) >= 3L &&
                is.symbol(node[[2L]]) && is_protected_path_expression(node[[3L]])
            ) {
                alias <- as.character(node[[2L]])
                if (!alias %in% protected_aliases) {
                    protected_aliases <<- c(protected_aliases, alias)
                    changed <- TRUE
                }
            }
            if (length(node) > 1L) {
                child_changes <- vapply(as.list(node)[-1L], collect_aliases, logical(1))
                changed <- changed || any(child_changes)
            }
        } else if (is.expression(node) || is.pairlist(node) || is.list(node)) {
            child_changes <- vapply(node, collect_aliases, logical(1))
            changed <- changed || any(child_changes)
        }
        changed
    }

    while (collect_aliases(tree)) {
        invisible(NULL)
    }

    visit <- function(node) {
        if (is.call(node)) {
            if (
                call_name(node) %in% mutating_functions &&
                any(vapply(mutation_targets(node), is_protected_path_expression, logical(1)))
            ) {
                rendered <- paste(deparse(node, width.cutoff = 500L), collapse = " ")
                findings <<- c(findings, rendered)
            }
            if (length(node) > 1L) {
                invisible(lapply(as.list(node)[-1L], visit))
            }
        } else if (is.expression(node) || is.pairlist(node) || is.list(node)) {
            invisible(lapply(node, visit))
        }
        invisible(NULL)
    }

    visit(tree)
    structure(unique(findings), protected_aliases = sort(unique(protected_aliases)))
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
    producer_files <- c(
        file.path("scripts", "endolaserless_analysis-2.R"),
        file.path("scripts", "count_prn_injections.R"),
        file.path("scripts", "latest_data_intake_audit.R"),
        file.path("scripts", "neovascularization_data_audit.R")
    )
    protected_write_calls <- unlist(
        lapply(producer_files, find_protected_write_calls),
        use.names = FALSE
    )
    synthetic_source_write <- parse(
        text = 'write.csv(x, file.path(paths$code_root, "x.csv"))'
    )
    synthetic_cloud_write <- parse(
        text = 'write.xlsx(x, file.path(paths$durable_outputs_root, "x.xlsx"))'
    )
    synthetic_file_write <- parse(
        text = 'file(file.path(paths$code_root, "x.log"), open = "wt")'
    )
    synthetic_cloud_copy <- parse(
        text = 'file.copy(src, file.path(paths$neovascularization_published_root, "x.xlsx"))'
    )
    synthetic_alias_write <- parse(text = paste(
        'target <- paths$durable_outputs_root',
        'write.csv(x, file.path(target, "x.csv"))',
        sep = "\n"
    ))
    stopifnot(
        length(protected_write_calls) == 0L,
        length(find_protected_write_calls(synthetic_source_write)) == 1L,
        length(find_protected_write_calls(synthetic_cloud_write)) == 1L,
        length(find_protected_write_calls(synthetic_file_write)) == 1L,
        length(find_protected_write_calls(synthetic_cloud_copy)) == 1L,
        length(find_protected_write_calls(synthetic_alias_write)) == 1L,
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
