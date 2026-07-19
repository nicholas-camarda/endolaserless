# =============================================================================
# PATH CONFIGURATION
# =============================================================================
# Set the base output directory - modify this to change where all output goes
source(file.path("scripts", "project_paths.R"))

paths <- endolaserless_paths()

base_output_dir <- paths$npi_prn_output_root
dir.create(base_output_dir, showWarnings = FALSE, recursive = TRUE)

runtime_plot_file <- file.path(base_output_dir, "prn_plots.pdf")
options(device = function(...) grDevices::pdf(file = runtime_plot_file, ...))

# =============================================================================
# LIBRARIES AND SETUP
# =============================================================================
library(tidyverse)
library(ggprism)
library(readxl)
library(openxlsx)

source(file.path("scripts", "helper_scripts.R"))

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

# Consume the active NPI cache written by endolaserless_analysis-2.R.
npi_input_workbook <- file.path(paths$npi_canonical_processed_root, "cached_long_input_data.xlsx")

if (!file.exists(npi_input_workbook)) {
    stop(
        paste(
            "Missing canonical NPI processed workbook:",
            npi_input_workbook,
            "Run scripts/endolaserless_analysis-2.R before scripts/count_prn_injections.R."
        ),
        call. = FALSE
    )
}

init_npi_dat <- read_excel(npi_input_workbook) %>%
    mutate(
        week = as.numeric(str_extract(week, "\\d+")),
        schedule = factor(schedule, levels = c("q8", "q16"))
    )

init_npi_dat %>%
    group_by(schedule, subject_id) %>%
    filter(week %in% c(4, 52, 104, 152)) %>%
    filter(!any(is.na(npi))) 


time_to_10_injections <- init_npi_dat %>%
    group_by(subject_id, schedule) %>%
    summarize(time_to_10 = first(week[num_injections_count > 10])) %>%
    arrange(schedule) %>%
    mutate(event = if_else(is.na(time_to_10), 0, 1)) %>%
    mutate(time_to_10 = if_else(is.na(time_to_10), 152, time_to_10)) %>%
    pivot_wider(id_cols = c(subject_id, time_to_10), names_from = schedule, values_from = event)
time_to_10_injections %>% write.xlsx(file.path(base_output_dir, "time_to_10_injections.xlsx"))

npi_data <- init_npi_dat %>%
    filter(week %in% c("week4", "week52", "week104", "week152")) %>%
    group_by(schedule, week) %>%
    summarize(mean_npi = mean(npi, na.rm = TRUE), n = n())

npi_data %>%
    pivot_wider(id_cols = c(n, schedule), names_from = week, values_from = mean_npi)
signif(npi_data$mean_npi, 4)

redcap_npa_input <- read_excel(file.path(paths$data_root, "2024-10-22 Endolaserless_RedCap_Data.xlsx")) %>%
    rename(subject_id = `Subject ID`, week = `Event Name`, npa = `Nonperfusion area within eye`) %>%
    dplyr::select(subject_id, week, npa)

npa_not_gradable_count <- redcap_npa_input %>%
    summarize(count = sum(str_to_lower(str_trim(as.character(npa))) == "not gradable", na.rm = TRUE)) %>%
    pull(count)

npa_sentinel_count <- redcap_npa_input %>%
    summarize(count = sum(suppressWarnings(as.numeric(npa)) >= 8888, na.rm = TRUE)) %>%
    pull(count)

npa_data <- redcap_npa_input %>%
    left_join(init_npi_dat %>% dplyr::select(subject_id, schedule) %>% distinct(), by = join_by(subject_id)) %>%
    filter(!is.na(schedule)) %>%
    mutate(
        week = as.numeric(str_extract(week, "\\d+")),
        npa_raw = str_trim(as.character(npa)),
        npa = if_else(str_to_lower(npa_raw) == "not gradable", NA_character_, npa_raw),
        npa = suppressWarnings(as.numeric(npa)),
        npa = if_else(!is.na(npa) & npa >= 8888, NA_real_, npa)
    ) %>%
    mutate(
        schedule = factor(schedule, levels = c("q8", "q16"))
    ) %>%
    dplyr::select(-npa_raw) %>%
    group_by(schedule, week) %>%
    arrange(subject_id, schedule, week)

message(
    "Cleaned NPA values: ",
    npa_not_gradable_count,
    " not gradable rows and ",
    npa_sentinel_count,
    " sentinel rows set to NA."
)

npa_data %>%
    arrange(schedule) %>%
    pivot_wider(id_cols = c(schedule, subject_id), names_from = week, values_from = npa) %>%
    write.xlsx(file.path(base_output_dir, "npa_by_week.xlsx"))

npa_data_means <- npa_data %>%
    filter(week %in% c(4, 52, 104, 152)) %>%
    summarize(mean_npa = mean(npa, na.rm = TRUE), n = n())


signif(npa_data_means %>% .$mean_npa, 4)

npa_data_means %>%
    pivot_wider(id_cols = c(n, schedule), names_from = week, values_from = mean_npa)


your_data <- read_excel(file.path(paths$data_root, "prn_injections.xlsx"), sheet = 1, n_max = 31)

# remove these subjects as they are not in the final analysis
subject_ids_to_remove <- c("L-01", "L-18", "L-30", "L-05", "L-08", "L-09", "L-11", "L-25")

s_g_assign <- your_data %>%
    filter(!subject_id %in% subject_ids_to_remove) %>%
    distinct(subject_id, group)

s_g_assign %>% print(n = Inf)

# Sample code to create a cumulative count for * and ** by patient and week
data_long <- your_data %>%
    # Normalize mixed PRN visit headers before selecting week columns.
    rename_with(normalize_prn_week_headers) %>%
    mutate(across(contains("week"), as.character)) %>%
    dplyr::select(subject_id, group, contains("week")) %>%
    # Convert all week columns to a long format while keeping subject_id and group columns
    pivot_longer(
        cols = contains("week"), # Adjust to include all relevant week columns
        names_to = "week",
        values_to = "value"
    ) %>%
    # Filter to include rows that start with * or **
    filter(str_starts(value, "\\*")) %>%
    # Create a new column for color based on value
    mutate(reason = case_when(
        str_starts(value, "\\*\\*") ~ "Leakage",
        str_starts(value, "\\*") ~ "DME"
    )) %>%
    # Create cumulative count per color across the weeks, grouped by subject_id and group
    group_by(subject_id, group, reason) %>%
    mutate(cumulative_count = row_number(), .before = 3) %>%
    ungroup() %>%
    mutate(
        week = as.numeric(str_extract(week, "\\d+")),
        group = factor(group, levels = c("q8", "q16")),
    ) %>%
    arrange(subject_id, week) %>%
    filter(!subject_id %in% subject_ids_to_remove) %>%
    right_join(s_g_assign, by = c("subject_id", "group")) %>%
    mutate(subject_id = factor(subject_id)) %>%
    group_by(subject_id, group) %>%
    complete(week = seq(4, 152, by = 4)) %>%
    mutate(year = floor(week / 52) + 1) %>%
    ungroup() %>%
    # Complete the data so that all subjects have entries for all 3 years, keeping only valid combinations
    complete(subject_id = unique(s_g_assign$subject_id), group, year = 1:3) %>%
    # Filter out rows with NA in 'year'
    filter(!is.na(year)) %>%
    # Replace missing values in 'total' with 0
    replace_na(list(total = 0)) %>%
    # Arrange by group, subject_id, and year
    arrange(group, subject_id, year) %>%
    semi_join(s_g_assign, by = c("subject_id", "group")) %>%
    mutate(group = factor(group, levels = c("q8", "q16"))) %>%
    group_by(subject_id, group) %>%
    fill(cumulative_count, .direction = "down") %>%
    ungroup() %>%
    replace_na(list(cumulative_count = 0))




time_to_avg_prn_injections <- data_long %>%
    group_by(subject_id, group) %>%
    mutate(
        week = as.numeric(str_extract(week, "\\d+")),
        group = factor(group, levels = c("q8", "q16"))
    ) %>%
    summarize(time_to_prn_avg = first(week[cumulative_count >= 1])) %>%
    arrange(group) %>%
    mutate(event = if_else(is.na(time_to_prn_avg), 0, 1)) %>%
    mutate(time_to_prn_avg = if_else(is.na(time_to_prn_avg), 152, time_to_prn_avg)) %>%
    pivot_wider(id_cols = c(subject_id, time_to_prn_avg), names_from = group, values_from = event)
time_to_avg_prn_injections %>% print(n = Inf)
time_to_avg_prn_injections %>% write.xlsx(file.path(base_output_dir, "time_to_avg_prn_injections.xlsx"))


# View the resulting dataset
print(data_long, n = Inf)

# total PRN injections at each year
data_yearly <- data_long %>%
    arrange(group) %>%
    group_by(subject_id, group, year) %>%
    summarize(total = last(cumulative_count), .groups = "drop")

print(data_yearly, n = Inf)
data_wide_yearly <- data_yearly %>%
    arrange(group) %>%
    pivot_wider(id_cols = year, names_from = c(group, subject_id), values_from = total) %>%
    pad_df_groups()
data_wide_yearly %>%
    write.xlsx(file.path(base_output_dir, "from_4weeks-wide_prn_injections_yearly.xlsx"))


data_wide_total <- data_yearly %>%
    group_by(subject_id, group) %>%
    summarize(final_count = last(total)) %>%
    arrange(group) %>%
    pivot_wider(id_cols = subject_id, names_from = c(group), values_from = final_count)

print(data_wide_total, n = Inf)

data_wide_total %>%
    write.xlsx(file.path(base_output_dir, "from_4weeks-wide_prn_injections_total.xlsx"))

# Calculate mean PRN treatment load per group and year
data_average <- data_yearly %>%
    group_by(group, year) %>%
    summarise(mean_total = mean(total, na.rm = TRUE), .groups = "drop")

# View the summary
print(data_average)

# Plotting the results to visualize the difference
ggplot(data_average, aes(x = year, y = mean_total, color = group, group = group)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    labs(
        title = "Average PRN Treatment Load by Year",
        x = "Year",
        y = "Average # Injections",
        color = "Group"
    ) +
    theme_minimal()


# total PRN injections at each year


# all_weeks <- your_data %>%
#     # Convert all columns with "wk post-op" in their names to character type to avoid type conflicts
#     rename_with(~ str_replace_all(., "(\\d+)[ -](?:wk|week) post-op", "week\\1")) %>%
#     mutate(across(contains("week"), as.character)) %>%
#     dplyr::select(subject_id, group, contains("week")) %>%
#     # Convert all week columns to a long format while keeping subject_id and group columns
#     pivot_longer(
#         cols = contains("week"), # Adjust to include all relevant week columns
#         names_to = "week",
#         values_to = "value"
#     ) %>%
#     .$week %>%
#     unique()

data_weekly <- data_long %>%
    arrange(group) %>%
    group_by(subject_id, group, week) %>%
    summarize(total = last(cumulative_count)) %>%
    arrange(group) %>%
    pivot_wider(id_cols = week, names_from = c(group, subject_id), values_from = total) %>%
    pad_df_groups()
print(data_weekly, n = Inf)

data_weekly %>%
    write.xlsx(file.path(base_output_dir, "from_4weeks-wide_prn_injections_weekly.xlsx"))


prn_injections_data <- data_long %>%
    rename(cumulative_prn_injections = cumulative_count, schedule = group) %>%
    mutate(total_prn_injections = max(cumulative_prn_injections)) %>%
    dplyr::select(-value, -reason)


npi_plus_all_injection_data <- init_npi_dat %>%
    left_join(prn_injections_data, by = join_by(subject_id, schedule, week)) %>%
    dplyr::select(schedule, subject_id, week, year, npi, num_injections_count, total_injections, cumulative_prn_injections, total_prn_injections)

write.xlsx(npi_plus_all_injection_data, file.path(paths$npi_processed_root, "FINAL_PROCESSED-npi_plus_all_injection_data.xlsx"))


npi_plus_all_injection_data %>%
    group_by(schedule, subject_id) %>%
    filter(week %in% c(4, 52, 104, 152)) %>%
    filter(!any(is.na(npi)))



npi_plus_all_injection_data %>% filter(subject_id == "L-38")
# auc 1st year of NPI x subject
first_year_auc <- npi_plus_all_injection_data %>%
    group_by(subject_id, schedule) %>%
    filter(week <= 52) %>%
    summarize(
        auc_first_year = calculate_auc(week, npi),
        total_injections = max(num_injections_count),
        prn_injections = max(cumulative_prn_injections), .groups = "drop"
    ) %>%
    arrange(schedule) %>%
    pivot_wider(id_cols = c(subject_id, total_injections, prn_injections), names_from = schedule, values_from = auc_first_year)
first_year_auc %>%
    write.xlsx(file.path(base_output_dir, "first_year_auc_x_injections.xlsx"))

# auc 2-3 year of NPI x subject
second_third_year_auc <- npi_plus_all_injection_data %>%
    group_by(subject_id, schedule) %>%
    filter(week >= 52 & week <= 152) %>%
    summarize(
        auc_second_third_year = calculate_auc(week, npi),
        total_injections = max(num_injections_count),
        prn_injections = max(cumulative_prn_injections), .groups = "drop"
    ) %>%
    arrange(schedule) %>%
    pivot_wider(id_cols = c(subject_id, total_injections, prn_injections), names_from = schedule, values_from = auc_second_third_year)
second_third_year_auc %>%
    write.xlsx(file.path(base_output_dir, "second_third_year_auc_x_injections.xlsx"))
