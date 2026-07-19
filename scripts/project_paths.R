resolve_path_root <- function(env_name, default) {
    value <- Sys.getenv(env_name, unset = "")
    if (nzchar(value)) {
        return(normalizePath(value, winslash = "/", mustWork = FALSE))
    }
    normalizePath(default, winslash = "/", mustWork = FALSE)
}


endolaserless_paths <- function() {
    code_root <- resolve_path_root(
        "ENDOLASERLESS_CODE_ROOT",
        "/Users/ncamarda/Workspaces/endolaserless/source"
    )
    runtime_root <- resolve_path_root(
        "ENDOLASERLESS_RUNTIME_ROOT",
        "/Users/ncamarda/Workspaces/endolaserless/runtime"
    )
    cloud_root <- resolve_path_root(
        "ENDOLASERLESS_CLOUD_ROOT",
        paste0(
            "/Users/ncamarda/Library/CloudStorage/OneDrive-Personal/",
            "Project Vault/Research/endolaserless"
        )
    )

    shared_data_root <- file.path(cloud_root, "data", "raw")
    shared_documents_root <- file.path(cloud_root, "documents")
    shared_references_root <- file.path(cloud_root, "references")
    durable_outputs_root <- file.path(cloud_root, "outputs")
    processed_root <- file.path(runtime_root, "processed_data")
    output_root <- file.path(runtime_root, "output")

    npi_project_root <- file.path(shared_documents_root, "npi-project")
    npi_durable_outputs_root <- file.path(durable_outputs_root, "npi-project")
    npi_processed_root <- file.path(processed_root, "npi_project")
    npi_output_root <- file.path(output_root, "npi_project")
    npi_canonical_processed_root <- file.path(npi_processed_root, "output-week4_week16_baseline")
    npi_compatibility_processed_root <- file.path(npi_processed_root, "output-week4_baseline")
    npi_canonical_output_root <- file.path(npi_output_root, "output-week4_week16_baseline")
    npi_prn_output_root <- file.path(npi_output_root, "count_prn_injections")

    neovascularization_project_root <- file.path(
        shared_documents_root,
        "neovascularization-project"
    )
    neovascularization_archive_root <- file.path(
        cloud_root,
        "archive",
        "neovascularization-project"
    )
    neovascularization_notes_root <- neovascularization_project_root
    neovascularization_raw_root <- shared_data_root
    neovascularization_processed_archive_root <- file.path(
        neovascularization_archive_root,
        "processed"
    )
    neovascularization_durable_outputs_root <- file.path(
        durable_outputs_root,
        "neovascularization-project"
    )
    neovascularization_published_root <- neovascularization_durable_outputs_root
    neovascularization_processed_root <- file.path(processed_root, "neovascularization_project")
    neovascularization_output_root <- file.path(output_root, "neovascularization_project")

    list(
        code_root = code_root,
        runtime_root = runtime_root,
        cloud_root = cloud_root,
        data_root = shared_data_root,
        docs_root = shared_documents_root,
        documents_root = shared_documents_root,
        references_root = shared_references_root,
        durable_outputs_root = durable_outputs_root,
        processed_root = processed_root,
        output_root = output_root,
        npi_project_root = npi_project_root,
        npi_durable_outputs_root = npi_durable_outputs_root,
        npi_processed_root = npi_processed_root,
        npi_output_root = npi_output_root,
        npi_canonical_processed_root = npi_canonical_processed_root,
        npi_compatibility_processed_root = npi_compatibility_processed_root,
        npi_canonical_output_root = npi_canonical_output_root,
        npi_prn_output_root = npi_prn_output_root,
        npi_archive_root = npi_project_root,
        neovascularization_project_root = neovascularization_project_root,
        neovascularization_archive_root = neovascularization_archive_root,
        neovascularization_archive_notes_root = neovascularization_notes_root,
        neovascularization_raw_root = neovascularization_raw_root,
        neovascularization_processed_archive_root = neovascularization_processed_archive_root,
        neovascularization_durable_outputs_root = neovascularization_durable_outputs_root,
        neovascularization_published_root = neovascularization_published_root,
        neovascularization_processed_root = neovascularization_processed_root,
        neovascularization_output_root = neovascularization_output_root
    )
}
