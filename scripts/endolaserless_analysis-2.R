# =============================================================================
# PATH CONFIGURATION
# =============================================================================
source(file.path("scripts", "project_paths.R"))

paths <- endolaserless_paths()

# Set the base output directory - modify this to change where all output goes
base_output_dir <- paths$npi_output_root

# Set the specific analysis output directory
top_output_dir <- paths$npi_canonical_output_root

# =============================================================================
# LIBRARIES AND SETUP
# =============================================================================
library(tidyverse)
library(readxl)
library(GetoptLong)
library(openxlsx)
library(skimr) # summarize dfs
library(ggprism)
library(lmerTest)

source(file.path("scripts", "helper_scripts.R"))


# Set logical variables based on output directory string
all_4week_baseline <- grepl("week4", top_output_dir)
all_16week_baseline <- grepl("week16", top_output_dir)


# make directory for processed data, for reproducibility
processed_dir <- paths$npi_canonical_processed_root
dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)

message("Writing standard messages to logs/message_log.txt")

# Open a connection to a file for logging output
# dir.create(file.path(processed_dir, "logs"), recursive = TRUE, showWarnings = FALSE)
message_log_file <- file(qq("@{processed_dir}/output_log.txt"), open = "wt")
sink(message_log_file, type = "message")

# make other dirs
week4_152_output_data_dir <- file.path(top_output_dir, "quarterly_analysis", "week4_152-all_data")
week4_152_complete_output_data_dir <- file.path(top_output_dir, "quarterly_analysis", "week4_152-complete_cases_data")
week16_152_output_data_dir <- file.path(top_output_dir, "quarterly_analysis", "week16_152-all_data")
week16_152_complete_output_data_dir <- file.path(top_output_dir, "quarterly_analysis", "week16_152-complete_cases_data")
week4_output_data_dir <- file.path(top_output_dir, "using_all_available_data", "from_week4-all_data")
week16_output_data_dir <- file.path(top_output_dir, "using_all_available_data", "from_week16-all_data")
week4_complete_output_data_dir <- file.path(top_output_dir, "using_all_available_data", "from_week4-complete_cases_data")
week16_complete_output_data_dir <- file.path(top_output_dir, "using_all_available_data", "from_week16-complete_cases_data")

walk(
    list(
        week4_152_output_data_dir,
        week4_152_complete_output_data_dir,
        week16_152_output_data_dir,
        week16_152_complete_output_data_dir,
        week4_output_data_dir,
        week16_output_data_dir,
        week4_complete_output_data_dir,
        week16_complete_output_data_dir
    ),
    ~ dir.create(.x, showWarnings = FALSE, recursive = TRUE)
)

full_dataset <- read_excel(file.path(paths$data_root, "Stats Wisconsin (Nick Edited).xlsx"), sheet = 6, n_max = 31) %>% # Nick All NPI and Injections
    dplyr::select(-starts_with("D from")) %>%
    # there's a star in one of these columns, just remove from all to avoid numeric error
    mutate(across(everything(), .fns = function(x) gsub(pattern = "\\*", replacement = "", x = x))) %>%
    rename(subject_id = `Subject ID`) %>%
    mutate(across(-c(subject_id, schedule), as.numeric)) %>%
    mutate(subject_id = as.factor(subject_id)) %>%
    rename_with(
        .fn = function(names) {
            # Find columns that start with '...' and have an adjacent 'Week' column
            map_chr(seq_along(names), function(i) {
                if (str_starts(names[i], "...") && i < length(names) && str_starts(names[i + 1], "Week")) {
                    week_number <- str_extract(names[i + 1], "\\d+")
                    return(paste("num_injections_before_week", week_number, sep = "_"))
                } else {
                    return(names[i])
                }
            })
        },
        .cols = everything() # Apply the function to all columns
    ) %>%
    rowwise() %>%
    mutate(total_injections = max(c_across(starts_with("num_injections_before_week")), na.rm = TRUE)) %>%
    ungroup() %>%
    dplyr::select(subject_id, schedule, total_injections, everything()) %>%
    # remove these initially so you can see what it is yelling about
    suppressMessages() %>%
    suppressWarnings()

# if (all_4week_baseline) {
#     full_dataset <- full_dataset %>%
#         filter(!subject_id %in% c("L-05", "L-08", "L-09", "L-18", "L-25", "L-01", "L-30")) # week4 no baseline
# }

# if (all_16week_baseline) {
#     full_dataset <- full_dataset %>%
#         filter(!subject_id %in% c("L-13", "L-17", "L-38")) # week16 no baseline
# }

# Identify subjects missing Week 4 baseline or having only Week 4 baseline without any other points
missing_week4_subjects <- full_dataset %>%
    filter((is.na(`Week 4`)) |
        (!is.na(`Week 4`) & rowSums(!is.na(select(., starts_with("Week")))) == 1)) %>%
    pull(subject_id)

# Identify subjects missing Week 16 baseline or having only Week 16 baseline without any other points
missing_week16_subjects <- full_dataset %>%
    filter((is.na(`Week 16`)) |
        (!is.na(`Week 16`) & rowSums(!is.na(select(., starts_with("Week")))) == 1)) %>%
    pull(subject_id)

# Combine subjects missing either Week 4 or Week 16 baselines, or having only one non-NA value
missing_baseline_subjects <- union(missing_week4_subjects, missing_week16_subjects)

full_dataset %>%
    dplyr::select(subject_id, starts_with("Week")) %>%
    filter(subject_id %in% missing_week4_subjects)

full_dataset %>%
    dplyr::select(subject_id, starts_with("Week")) %>%
    filter(subject_id %in% missing_week16_subjects)
# Display the subjects removed for missing baselines or only having a baseline
missing_week4_subjects
missing_week16_subjects

# If you want to store all subjects removed for any missing baseline
missing_baseline_subjects <- union(missing_week4_subjects, missing_week16_subjects)

## FILTERING OF DATASET HAPPENS UP FRONT NOW
if (all_4week_baseline) {
    full_dataset <- full_dataset %>%
        filter(!subject_id %in% missing_week4_subjects)
} else if (all_16week_baseline) {
    full_dataset <- full_dataset %>%
        filter(!subject_id %in% missing_week16_subjects)
} else if (all_4week_baseline && all_16week_baseline) {
    full_dataset <- full_dataset %>%
        filter(!subject_id %in% missing_baseline_subjects)
} else {
    full_dataset <- full_dataset
}

write.xlsx(
    full_dataset,
    file.path(processed_dir, "cached_wide_input_data.xlsx")
)

long_full_dataset_temp <- full_dataset %>%
    pivot_longer(
        cols = -c(subject_id, schedule, total_injections), # Exclude these columns from the transformation
        values_to = "value",
        names_pattern = "(num_injections_before_week_|Week )([0-9]+)", # Extract week numbers
        names_to = c(".value", "week") # Separate into two columns: one for injections and one for weeks
    ) %>%
    rename(npi = `Week `, num_injections_count = `num_injections_before_week_`) %>%
    dplyr::select(schedule, subject_id, week, npi, num_injections_count, total_injections) %>%
    mutate(week = str_c("week", week)) %>%
    filter(!is.na(week)) %>%
    group_by(subject_id) %>%
    filter(!all(is.na(npi))) %>%
    ungroup()

schedule_factors <- long_full_dataset_temp %>%
    distinct(schedule) %>%
    arrange(desc(schedule)) %>%
    # this gives q8 -> q16
    mutate(order = seq_len(n())) %>%
    deframe()
schedule_factors

# long_full_dataset_temp %>% print(n = 100)
week_factors <- long_full_dataset_temp %>%
    distinct(week) %>%
    # this gives q8 -> q16
    mutate(order = seq_len(n())) %>%
    deframe()
week_factors

long_full_dataset <- long_full_dataset_temp %>%
    mutate(
        schedule = factor(schedule, levels = names(schedule_factors)),
        week = factor(week, levels = names(week_factors))
    ) %>%
    arrange(schedule, subject_id, week)

write.xlsx(
    long_full_dataset,
    file.path(processed_dir, "cached_long_input_data.xlsx")
)

long_full_dataset %>%
    mutate(week = gsub(pattern = "week", replacement = "", x = week)) %>%
    pivot_wider(id_cols = week, names_from = c(schedule, subject_id), values_from = num_injections_count) %>%
    pad_df_groups() %>%
    write.xlsx(file.path(processed_dir, "ALL-wide_cumulative_injections.xlsx"))

# long_full_dataset %>%
#     filter(!subject_id %in% c("L-05", "L-08", "L-09", "L-25", "L-01", "L-30")) %>%
#     mutate(week = gsub(pattern = "week", replacement = "", x = week)) %>%
#     pivot_wider(id_cols = week, names_from = c(schedule, subject_id), values_from = num_injections_count) %>%
#     pad_df_groups() %>%
#     write.xlsx(file.path(processed_dir, "subset-wide_cumulative_injections.xlsx"))

long_full_dataset %>%
    group_by(subject_id) %>%
    mutate(injections_per_week = if_else(week == "week4", num_injections_count, num_injections_count - lag(num_injections_count))) %>%
    mutate(week = gsub(pattern = "week", replacement = "", x = week)) %>%
    pivot_wider(id_cols = week, names_from = c(schedule, subject_id), values_from = injections_per_week) %>%
    pad_df_groups() %>%
    write.xlsx(file.path(processed_dir, "injections_per_week.xlsx"))

long_full_dataset %>%
    group_by(subject_id) %>%
    mutate(injections_per_week = if_else(week == "week4", num_injections_count, num_injections_count - lag(num_injections_count))) %>%
    mutate(week = as.numeric(gsub(pattern = "week", replacement = "", x = week)), grouper = if_else(week < 80, "< week 80", ">= week 80")) %>%
    group_by(subject_id, grouper, schedule) %>%
    summarize(total_injections_by_phase = mean(injections_per_week, na.rm = TRUE), .groups = "drop") %>%
    arrange(schedule) %>%
    pivot_wider(id_cols = grouper, names_from = c(schedule, subject_id), values_from = total_injections_by_phase) %>%
    pad_df_groups() %>%
    write.xlsx(file.path(processed_dir, "mean_injections_by_phase_80.xlsx"))

long_full_dataset %>%
    group_by(subject_id) %>%
    mutate(injections_per_week = if_else(week == "week4", num_injections_count, num_injections_count - lag(num_injections_count))) %>%
    mutate(week = as.numeric(gsub(pattern = "week", replacement = "", x = week)), grouper = if_else(week < 80, "< week 80", ">= week 80")) %>%
    group_by(subject_id, grouper, schedule) %>%
    summarize(
        total_injections_by_phase = mean(injections_per_week, na.rm = TRUE),
        mean_npi = mean(npi, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    group_by(subject_id) %>%
    mutate(diff_npi = mean_npi - first(mean_npi), diff_inj = total_injections_by_phase - first(total_injections_by_phase)) %>%
    ungroup() %>%
    filter(grouper != "< week 80") %>%
    mutate(grouper = "Difference before and after week 80") %>%
    na.omit() %>%
    arrange(schedule) %>%
    pivot_wider(id_cols = c(grouper, subject_id, diff_inj), names_from = c(schedule), values_from = c(diff_npi)) %>%
    write.xlsx(file.path(processed_dir, "mean_diff_inj_and_npi_by_phase_80.xlsx"))

long_full_dataset

# this doesn't really add anything
diff_long_full_dataset <- long_full_dataset %>%
    group_by(subject_id) %>%
    mutate(diff_npi_from_baseline = npi - first(npi)) %>%
    mutate(diff_npi_from_prev = if_else(week == "week4", npi, npi - lag(npi))) %>%
    mutate(week_helper = as.numeric(gsub(pattern = "week", replacement = "", x = week))) %>%
    mutate(injections_per_week = if_else(week == "week4", num_injections_count, num_injections_count - lag(num_injections_count))) %>%
    mutate(
        measurement_type = factor(if_else(week == "week4", "baseline", "followup")),
        npi_baseline = first(npi)
    ) %>%
    ungroup()



res <- lmer(diff_npi_from_baseline ~ week * schedule + (1 | subject_id), data = diff_long_full_dataset, na.action = na.exclude)
summary(res)
tidy_res <- broom.mixed::tidy(res) %>%
    # filter(effect == "fixed") %>%
    dplyr::select(-group) %>%
    rstatix::add_significance(
        cutpoints = c(0, 1e-04, 0.001, 0.01, 0.05, 0.1, 1),
        symbols = c("****", "***", "**", "*", ".", "ns"),
        "p.value"
    )
# write.xlsx(tidy_res, file.path("output", "mixed_model_results", "diff_npi_injection_per_week_interaction-mixed_model.xlsx"))


res <- lmer(num_injections_count ~ npi_baseline + diff_npi_from_baseline + schedule + (1 | subject_id), data = diff_long_full_dataset, na.action = na.exclude)
summary(res)
broom.mixed::tidy(res) %>%
    filter(effect == "fixed") %>%
    rstatix::add_significance("p.value")

res <- lmer(diff_npi_from_baseline ~ npi_baseline + schedule + (1 | subject_id), data = diff_long_full_dataset, na.action = na.exclude)
summary(res)
broom.mixed::tidy(res) %>%
    filter(effect == "fixed") %>%
    rstatix::add_significance("p.value")

res <- lmer(diff_npi_from_baseline ~ npi_baseline + schedule + (1 | subject_id), data = diff_long_full_dataset, na.action = na.exclude)
summary(res)
broom.mixed::tidy(res) %>%
    filter(effect == "fixed") %>%
    rstatix::add_significance("p.value")

res <- lmer(npi ~ npi_baseline + schedule + (1 | subject_id), data = diff_long_full_dataset, na.action = na.exclude)
summary(res)
broom.mixed::tidy(res) %>%
    filter(effect == "fixed") %>%
    rstatix::add_significance("p.value") %>%
    write.xlsx("~/Downloads/npi_vs_npi_baseline-regression.xlsx")

# diff_long_full_dataset %>%
#     print(n = Inf)
# # Example of a mixed effects model with time as a fixed effect and subject-specific random intercepts
# model <- lmer(diff_npi_from_baseline ~ num_injections_count * schedule * week + (1 | subject_id), data = diff_long_full_dataset, na.action = na.exclude)
# summary(model)
# broom.mixed::tidy(model) %>%
#     mutate(Y = "diff_npi_from_baseline", X = str_c("num_injections_count * Schedule * Week")) %>%
#     rstatix::add_significance("p.value") %>%
#     write.xlsx(
#         file.path("output", "mixed_model_results  ", "diff_npi_vs--lmer-mixed_effects_model.xlsx")
#     )


###############################################################################
######################## Pipeline Script ######################################
###############################################################################

run_endolaserless_analysis <- function(long_df, name_helper = "complete_cases", output_data_dir = NA, week_range = c("week4", "week52", "week104", "week152")) {
    # DEBUG:long_df = long_full_dataset; name_helper = "week4_152-all_data"; output_data_dir = week4_152_output_data_dir; week_range =  str_c("week", c(4, 52, 104, 152))

    # get all possible pairs
    long_df <- long_df %>%
        mutate(
            week = droplevels(week),
            subject_id = droplevels(subject_id)
        ) %>%
        # group_by(subject_id) %>%
        ## gets rid of subjects with missing baselines and/or only 1 value
        # filter(!any(first(is.na(npi))) & sum(!is.na(npi)) > 1) %>%
        ungroup()

    # long_df %>%
    #     distinct(subject_id, schedule, total_injections) %>%
    #     write.xlsx("~/Downloads/total_injections.xlsx")

    pairs_df <- get_pairs_df(long_df) %>%
        group_by(subject_id)

    # plotting auc df
    auc_pairs_plot_df <- pairs_df %>%
        distinct(schedule, subject_id, comparison, comparison_auc, .keep_all = TRUE)

    # prism auc
    wide_auc_pairs_plot_df <- auc_pairs_plot_df %>%
        pivot_wider(
            id_cols = c(comparison),
            names_from = c(schedule, subject_id),
            values_from = comparison_auc
        )

    wide_auc_pairs_plot_df
    # dir.create(file.path(output_data_dir, "auc"), showWarnings = FALSE, recursive = TRUE)

    week1 <- first(week_range)
    week2 <- last(week_range)
    week_check <- str_c(week1, " vs ", week2)

    auc_x_injections <- auc_pairs_plot_df %>%
        left_join(long_df, by = join_by(subject_id, schedule, week, npi, total_injections)) %>%
        dplyr::select(schedule, subject_id, comparison, comparison_auc, total_injections) %>%
        filter(as.character(comparison) == week_check) %>%
        filter(!is.na(comparison_auc)) %>%
        dplyr::select(subject_id, comparison, schedule, total_injections, comparison_auc, everything())
    auc_x_injections



    # plotting npi df
    npi_plot_df <- pairs_df %>%
        distinct(schedule, subject_id, week, npi)
    # prism npi df
    wide_npi_plot_df <- npi_plot_df %>%
        # arrange(desc(schedule)) %>%
        pivot_wider(
            id_cols = c(week),
            names_from = c(schedule, subject_id),
            values_from = npi
        )
    wide_npi_plot_df


    # write the data
    message(qq("1-1@{name_helper}_prism_data-NPI.xlsx"))
    write.xlsx(
        wide_npi_plot_df %>%
            mutate(week = gsub(pattern = "week", "", x = week)) %>%
            pad_df_groups(),
        file.path(output_data_dir, qq("1-1@{name_helper}_prism_data-NPI.xlsx"))
    )

    message(qq("1-11@{name_helper}_prism_data-NPI_ALL_HAVE_BASELINE.xlsx"))
    npi_all_have_baseline <- npi_plot_df %>%
        group_by(subject_id) %>%
        filter(!any(is.na(first(npi))) & n() > 1) %>%
        ungroup()

    write.xlsx(
        # Remove subjects with missing first NPI or only one NPI value
        npi_all_have_baseline %>%
            pivot_wider(
                id_cols = c(week),
                names_from = c(schedule, subject_id),
                values_from = npi
            ) %>%
            mutate(week = gsub(pattern = "week", "", x = week)) %>%
            pad_df_groups(),
        file.path(output_data_dir, qq("1-11@{name_helper}_prism_data-NPI_ALL_HAVE_BASELINE.xlsx"))
    )


    delta_npi_plot_df <- npi_plot_df %>%
        group_by(subject_id) %>%
        mutate(delta_npi_from_baseline = npi - first(npi))

    delta_npi_plot_df_wide <- delta_npi_plot_df %>%
        pivot_wider(
            id_cols = c(week),
            names_from = c(schedule, subject_id),
            values_from = delta_npi_from_baseline
        )


    message(qq("1-2@{name_helper}_prism_data-DIFF_NPI.xlsx"))
    write.xlsx(
        delta_npi_plot_df_wide %>%
            mutate(week = gsub(pattern = "week", "", x = week)) %>%
            pad_df_groups(),
        file.path(output_data_dir, qq("1-2@{name_helper}_prism_data-DIFF_NPI.xlsx"))
    )



    # auc
    message(qq("2-1@{name_helper}_prism_data-AUC_NPI.xlsx"))
    write.xlsx(
        wide_auc_pairs_plot_df %>%
            pad_df_groups(),
        file.path(output_data_dir, qq("2-1@{name_helper}_prism_data-AUC_NPI.xlsx"))
    )

    # first and last - auc of the npi curve
    first_last_auc_npi_plot_df <- npi_plot_df %>%
        arrange(schedule, subject_id, week) %>%
        calculate_auc_intervals(list(c(first(sort(npi_plot_df$week)), last(sort(npi_plot_df$week)))), calculate_auc) %>%
        rename(comparison = interval) %>%
        arrange(schedule) %>%
        pivot_wider(
            id_cols = c(comparison, subject_id),
            names_from = c(schedule),
            values_from = comparison_auc
        )

    message(qq("2-2@{name_helper}_prism_data-firstlast_AUC_NPI.xlsx"))
    write.xlsx(
        first_last_auc_npi_plot_df,
        file.path(output_data_dir, qq("2-2@{name_helper}_prism_data-firstlast_AUC_NPI.xlsx"))
    )


    # first and last - auc of the diff curve
    diff_first_last_auc_plot_df <- delta_npi_plot_df %>%
        arrange(schedule, subject_id, week) %>%
        # crucial for this function to work
        mutate(npi = delta_npi_from_baseline) %>%
        calculate_auc_intervals(list(c(first(sort(delta_npi_plot_df$week)), last(sort(delta_npi_plot_df$week)))), calculate_auc) %>%
        rename(diff_comparison_auc = comparison_auc) %>%
        rename(comparison = interval) %>%
        arrange(schedule)

    message(qq("2-3@{name_helper}_prism_data-firstlast_AUC_NPI_DIFF.xlsx"))
    write.xlsx(
        diff_first_last_auc_plot_df %>%
            pivot_wider(
                id_cols = c(comparison, subject_id),
                names_from = c(schedule),
                values_from = diff_comparison_auc
            ),
        file.path(output_data_dir, qq("2-3@{name_helper}_prism_data-firstlast_AUC_NPI_DIFF.xlsx"))
    )

    # tranpose
    transposed_npi_plot_df <- npi_plot_df %>%
        pivot_wider(id_cols = c(schedule, subject_id), values_from = npi, names_from = week)

    message(qq("3@{name_helper}_transposed_prism_data-NPI.xlsx"))
    write.xlsx(
        transposed_npi_plot_df,
        file.path(output_data_dir, qq("3@{name_helper}_transposed_prism_data-NPI.xlsx"))
    )

    message(qq("4@{name_helper}_q8_transposed_prism_data-NPI.xlsx"))
    write.xlsx(
        transposed_npi_plot_df %>% filter(as.character(schedule) == "q8"),
        file.path(output_data_dir, qq("4@{name_helper}_q8_transposed_prism_data-NPI.xlsx"))
    )
    message(qq("5@{name_helper}_q16_transposed_prism_data-NPI.xlsx"))
    write.xlsx(
        transposed_npi_plot_df %>% filter(as.character(schedule) == "q16"),
        file.path(output_data_dir, qq("5@{name_helper}_q16_transposed_prism_data-NPI.xlsx"))
    )

    week_check_npi <- str_split(week_check, " vs ", simplify = TRUE)
    npi_x_injections <- npi_plot_df %>%
        left_join(long_df, by = join_by(schedule, subject_id, week, npi)) %>%
        filter(as.character(week) %in% week_check_npi) %>%
        group_by(subject_id) %>%
        arrange(schedule, subject_id, week) %>%
        mutate(diff_npi = last(npi) - first(npi)) %>%
        distinct(schedule, subject_id, diff_npi, total_injections) %>%
        filter(!is.na(diff_npi)) %>%
        mutate(comparison = week_check, .before = 2) %>%
        dplyr::select(subject_id, comparison, schedule, total_injections, diff_npi, everything())
    npi_x_injections

    message(qq("6@{name_helper}-prism_data-separated-npi_x_injections.xlsx"))
    write.xlsx(
        npi_x_injections %>%
            pivot_wider(id_cols = c(subject_id, total_injections), names_from = c(schedule), values_from = c(diff_npi)),
        file.path(output_data_dir, qq("6@{name_helper}-prism_data-separated-npi_x_injections.xlsx"))
    )

    message(qq("7@{name_helper}-prism_data-together-npi_x_injections.xlsx"))
    write.xlsx(
        npi_x_injections,
        file.path(output_data_dir, qq("7@{name_helper}-prism_data-together-npi_x_injections.xlsx"))
    )

    ### this one
    # message(qq("8-1@{name_helper}-prism_data-separated-AUC_x_injections_ALL_HAVE_BASELINE.xlsx"))

    message(qq("8@{name_helper}-prism_data-separated-AUC_x_injections.xlsx"))
    write.xlsx(
        auc_x_injections %>%
            pivot_wider(id_cols = c(subject_id, comparison, total_injections), names_from = c(schedule), values_from = c(comparison_auc)),
        file.path(output_data_dir, qq("8@{name_helper}-prism_data-separated-AUC_x_injections.xlsx"))
    )

    message(qq("9@{name_helper}-prism_data-together-AUC_x_injections.xlsx"))
    write.xlsx(
        auc_x_injections,
        file.path(output_data_dir, qq("9@{name_helper}-prism_data-together-AUC_x_injections.xlsx"))
    )

    diff_auc_x_injections <- auc_x_injections %>%
        dplyr::select(-comparison_auc) %>%
        left_join(diff_first_last_auc_plot_df, by = join_by(subject_id, comparison, schedule))
    message(qq("9@{name_helper}-prism_data-together-DIFF_AUC_x_injections.xlsx"))
    write.xlsx(
        diff_auc_x_injections,
        file.path(output_data_dir, qq("9@{name_helper}-prism_data-together-DIFF_AUC_x_injections.xlsx"))
    )

    diff_auc_x_injections_separated <- diff_auc_x_injections %>%
        pivot_wider(id_cols = c(subject_id, comparison, total_injections), names_from = c(schedule), values_from = c(diff_comparison_auc))

    message(qq("9@{name_helper}-prism_data-separated-DIFF_AUC_x_injections.xlsx\n"))
    write.xlsx(
        diff_auc_x_injections_separated,
        file.path(output_data_dir, qq("9@{name_helper}-prism_data-separated-DIFF_AUC_x_injections.xlsx"))
    )

    baseline_npi <- npi_plot_df %>%
        filter(week == week1) %>%
        pivot_wider(id_cols = c(week, subject_id), names_from = c(schedule), values_from = c(npi))
    message(qq("99@{name_helper}-prism_data-baseline_npi.xlsx\n"))
    write.xlsx(
        baseline_npi,
        file.path(output_data_dir, qq("99@{name_helper}-prism_data-baseline_npi.xlsx"))
    )

    first_vs_last_week_wide <- npi_plot_df %>%
        filter(week %in% week_check_npi) %>%
        pivot_wider(id_cols = c(week), names_from = c(schedule, subject_id), values_from = c(npi))

    message(qq("99@{name_helper}-prism_data-first_vs_last_week-q8_vs_q16.xlsx\n"))
    write.xlsx(
        first_vs_last_week_wide %>% pad_df_groups(),
        file.path(output_data_dir, qq("99@{name_helper}-prism_data-first_vs_last_week-q8_vs_q16.xlsx"))
    )


    delta_first_vs_last_week_wide <- delta_npi_plot_df %>%
        filter(week == week2) %>%
        pivot_wider(id_cols = c(week, subject_id), names_from = c(schedule), values_from = c(delta_npi_from_baseline))
    message(qq("999@{name_helper}-prism_data-DIFF_first_vs_last_week-q8_vs_q16.xlsx\n"))
    write.xlsx(
        delta_first_vs_last_week_wide,
        file.path(output_data_dir, qq("999@{name_helper}-prism_data-DIFF_first_vs_last_week-q8_vs_q16.xlsx"))
    )


    return(list(auc_pairs_plot_df, npi_plot_df) %>% set_names(c("auc", "npi")))
}

###############################################################################
######################## Complete Cases Analysis - Week 4, 52, 105, 152 #######
###############################################################################

first_analysis_wr <- str_c("week", c(4, 52, 104, 152))
week4_152_complete_cases_df <- long_full_dataset %>%
    filter(week %in% first_analysis_wr) %>%
    group_by(subject_id) %>%
    filter(!any(is.na(npi)))

message("Complete Cases Analysis - Week 4, 52, 105, 152")
run_endolaserless_analysis(
    long_df = week4_152_complete_cases_df,
    name_helper = "week4_152-complete_cases",
    output_data_dir = week4_152_complete_output_data_dir,
    week_range = first_analysis_wr
)

###############################################################################
######################## Full Data - Week 4, 52, 105, 152 ################
###############################################################################

week4_152_all_df <- long_full_dataset %>%
    filter(week %in% first_analysis_wr) %>%
    group_by(subject_id)

message("Full Data - Week 4, 52, 105, 152")
run_endolaserless_analysis(
    long_df = week4_152_all_df,
    name_helper = "week4_152-all_data",
    output_data_dir = week4_152_output_data_dir,
    week_range = first_analysis_wr
)

###############################################################################
######################## Complete Cases Analysis - Week 16*, 52, 105, 152 #######
###############################################################################

message("Complete Cases Analysis - Week 16*, 52, 105, 152")
second_analysis_wr <- str_c("week", c(16, 52, 104, 152))
week16_152_complete_cases_df <- long_full_dataset %>%
    filter(week %in% second_analysis_wr) %>%
    group_by(subject_id) %>%
    filter(!any(is.na(npi)))

run_endolaserless_analysis(
    long_df = week16_152_complete_cases_df,
    name_helper = "week16_152-complete_cases",
    output_data_dir = week16_152_complete_output_data_dir,
    week_range = second_analysis_wr
)

###############################################################################
######################## Full Data - Week 16*, 52, 105, 152 ################
###############################################################################

message("Full Data - Week 16*, 52, 105, 152")
week16_152_all_df <- long_full_dataset %>%
    filter(week %in% second_analysis_wr) %>%
    group_by(subject_id)

run_endolaserless_analysis(
    long_df = week16_152_all_df,
    name_helper = "week16_152-all_data",
    output_data_dir = week16_152_output_data_dir,
    week_range = second_analysis_wr
)

###############################################################################
######################## Full Data and >50% Complete Data - From Week 4 ################
###############################################################################

all_weeks <- levels(long_full_dataset$week)

message("Full Data - From Week 4")
full_data_from_week4_lst <- run_endolaserless_analysis(
    long_df = long_full_dataset,
    name_helper = "from_week4-all_data",
    output_data_dir = week4_output_data_dir,
    week_range = all_weeks
)


n_per_week <- full_data_from_week4_lst$npi %>%
    arrange(subject_id, week) %>%
    group_by(subject_id) %>%
    group_by(week, schedule) %>%
    summarize(n = sum(!is.na(npi))) %>%
    pivot_wider(id_cols = schedule, names_from = week, values_from = n)

write.xlsx(n_per_week, file.path(week4_output_data_dir, "n_per_week.xlsx"))

message("Full Data - From Week 4 - 3-way AUC")
three_intervals <- list(
    "week4 to week40" = c("week4", "week40"),
    "week96 to week64" = c("week52", "week96"),
    "week104 to week152" = c("week104", "week152")
)
week4_three_way_auc_data <- calculate_auc_intervals(long_full_dataset, three_intervals, calculate_auc) %>%
    arrange(schedule) %>%
    group_by(subject_id) %>%
    filter(!any(is.na(comparison_auc)))
write.xlsx(
    week4_three_way_auc_data %>%
        pivot_wider(id_cols = c(interval), names_from = c(schedule, subject_id), values_from = comparison_auc) %>%
        pad_df_groups(),
    file.path(week4_output_data_dir, "week4_three_way_auc_data.xlsx")
)

unbalanced_intervals <- list(
    "week4 to week80" = c("week4", "week80"),
    "week80 to week152" = c("week80", "week152")
)
from_week4_two_part_unbalanced_auc_data <- calculate_auc_intervals(long_full_dataset, unbalanced_intervals, calculate_auc) %>%
    arrange(schedule) %>%
    group_by(subject_id) %>%
    filter(!any(is.na(comparison_auc)))

write.xlsx(
    from_week4_two_part_unbalanced_auc_data %>%
        pivot_wider(id_cols = c(interval), names_from = c(schedule, subject_id), values_from = comparison_auc) %>%
        pad_df_groups(),
    file.path(week4_output_data_dir, "999from_week4-two_part_unbalanced_auc_data.xlsx")
)


message("Full Data - From Week 4 - 50% complete data")
filtered_4week_dataset <- long_full_dataset %>%
    remove_x_pct_missing_data(missing_pct = 50) %>%
    group_by(subject_id) %>%
    filter(any(week == "week64" & !is.na(npi)), any(week == "week80" & !is.na(npi))) %>%
    ungroup()

run_endolaserless_analysis(
    long_df = filtered_4week_dataset,
    name_helper = "from_week4-complete_cases_data",
    output_data_dir = week4_complete_output_data_dir,
    week_range = all_weeks
)


###############################################################################
######################## Full Data and >50% Complete Data - Week 16 ################
###############################################################################

message("Full Data - From Week 16")
from_week16 <- all_weeks[-1]
from_week16_data <- long_full_dataset %>%
    filter(week %in% from_week16)

run_endolaserless_analysis(
    long_df = from_week16_data,
    name_helper = "from_week16-all_data",
    output_data_dir = week16_output_data_dir,
    week_range = from_week16
)

message("Full Data - From Week 16 - 3-way AUC")
week16_three_way_auc_data <- calculate_auc_intervals(from_week16_data, three_intervals, calculate_auc) %>%
    arrange(schedule) %>%
    group_by(subject_id) %>%
    filter(!any(is.na(comparison_auc))) %>%
    ungroup()

write.xlsx(
    week16_three_way_auc_data %>%
        pivot_wider(id_cols = c(interval), names_from = c(schedule, subject_id), values_from = comparison_auc) %>%
        pad_df_groups(),
    file.path(week16_output_data_dir, "week16_three_way_auc_data.xlsx")
)

message("Full Data - From Week 16 - 50% complete data")
filtered_16week_dataset <- from_week16_data %>%
    remove_x_pct_missing_data(missing_pct = 50) %>%
    group_by(subject_id) %>%
    filter(any(week == "week64" & !is.na(npi)), any(week == "week80" & !is.na(npi))) %>%
    ungroup()

run_endolaserless_analysis(
    long_df = filtered_16week_dataset,
    name_helper = "from_week16-complete_cases_data",
    output_data_dir = week16_complete_output_data_dir,
    week_range = from_week16
)



###############################################################################
######################## NPI Tables ###########################################
###############################################################################

average_npi_by_week_and_schedule_df <- long_full_dataset %>%
    group_by(week, schedule) %>%
    summarize(avg_npi = mean(npi, na.rm = TRUE))

average_npi_by_week_df <- average_npi_by_week_and_schedule_df %>%
    group_by(week) %>%
    summarize(avg_npi = mean(avg_npi, na.rm = TRUE))


write.xlsx(
    average_npi_by_week_df,
    file.path(processed_dir, qq("avg_npi_by_week.xlsx"))
)

write.xlsx(
    average_npi_by_week_and_schedule_df %>%
        pivot_wider(
            id_cols = week,
            names_from = schedule,
            values_from = avg_npi
        ),
    file.path(processed_dir, qq("avg_npi_by_schedule_and_week.xlsx"))
)

message(paste0("\nDone! Refer to ", base_output_dir, " for results."))

# Closes the message sink
sink(type = "message")
