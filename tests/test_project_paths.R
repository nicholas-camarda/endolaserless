path_env_names <- c(
    "ENDOLASERLESS_CODE_ROOT",
    "ENDOLASERLESS_RUNTIME_ROOT",
    "ENDOLASERLESS_CLOUD_ROOT"
)

restore_path_environment <- function(old_values) {
    Sys.unsetenv(path_env_names)
    present <- !is.na(old_values)
    if (any(present)) {
        do.call(Sys.setenv, as.list(old_values[present]))
    }
}

run_project_path_contract <- function() {
    old_values <- Sys.getenv(path_env_names, unset = NA_character_)
    names(old_values) <- path_env_names
    on.exit(restore_path_environment(old_values), add = TRUE)

    Sys.unsetenv(path_env_names)
    source(file.path("scripts", "project_paths.R"), local = TRUE)

    paths <- endolaserless_paths()
    expected_cloud_root <- paste0(
        "/Users/ncamarda/Library/CloudStorage/OneDrive-Personal/",
        "Project Vault/Research/endolaserless"
    )

    stopifnot(
        identical(paths$code_root, "/Users/ncamarda/Workspaces/endolaserless/source"),
        identical(paths$runtime_root, "/Users/ncamarda/Workspaces/endolaserless/runtime"),
        identical(paths$cloud_root, expected_cloud_root),
        identical(paths$data_root, file.path(paths$cloud_root, "data", "raw")),
        identical(paths$documents_root, file.path(paths$cloud_root, "documents")),
        identical(paths$references_root, file.path(paths$cloud_root, "references")),
        identical(paths$durable_outputs_root, file.path(paths$cloud_root, "outputs")),
        identical(
            paths$npi_durable_outputs_root,
            file.path(paths$durable_outputs_root, "npi-project")
        ),
        identical(
            paths$neovascularization_durable_outputs_root,
            file.path(paths$durable_outputs_root, "neovascularization-project")
        ),
        startsWith(paths$npi_canonical_processed_root, paste0(paths$runtime_root, "/")),
        startsWith(paths$npi_canonical_output_root, paste0(paths$runtime_root, "/")),
        startsWith(paths$npi_prn_output_root, paste0(paths$runtime_root, "/")),
        startsWith(paths$neovascularization_processed_root, paste0(paths$runtime_root, "/")),
        startsWith(paths$neovascularization_output_root, paste0(paths$runtime_root, "/"))
    )

    temporary_root <- tempfile("endolaserless-path-contract-")
    override_values <- c(
        ENDOLASERLESS_CODE_ROOT = file.path(temporary_root, "source"),
        ENDOLASERLESS_RUNTIME_ROOT = file.path(temporary_root, "runtime"),
        ENDOLASERLESS_CLOUD_ROOT = file.path(temporary_root, "vault")
    )
    do.call(Sys.setenv, as.list(override_values))

    overridden <- endolaserless_paths()
    stopifnot(
        identical(overridden$code_root, override_values[["ENDOLASERLESS_CODE_ROOT"]]),
        identical(overridden$runtime_root, override_values[["ENDOLASERLESS_RUNTIME_ROOT"]]),
        identical(overridden$cloud_root, override_values[["ENDOLASERLESS_CLOUD_ROOT"]]),
        identical(overridden$data_root, file.path(overridden$cloud_root, "data", "raw")),
        identical(
            overridden$npi_canonical_output_root,
            file.path(
                overridden$runtime_root,
                "output",
                "npi_project",
                "output-week4_week16_baseline"
            )
        ),
        identical(
            overridden$neovascularization_durable_outputs_root,
            file.path(overridden$cloud_root, "outputs", "neovascularization-project")
        )
    )
}

run_project_path_contract()
