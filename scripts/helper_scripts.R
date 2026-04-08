my_base_pptx_size <- 18
my_pptx_theme <- theme_prism(base_size = my_base_pptx_size) +
    theme(
        plot.title = element_text(size = rel(2), face = "bold"),
        strip.text.x = element_text(size = rel(1.35), face = "bold.italic"),
        # axis.text.x = element_text(size = rel(0.75)), # , hjust = 1, vjust = 1), # angle = 45,
        panel.grid.major = element_line(colour = "gray", linetype = 3, linewidth = 0.5),
        panel.grid.minor = element_line(colour = "gray", linetype = 2, linewidth = 0.25),
        legend.position = "bottom",
        axis.title = element_text(size = rel(1.5)),
        axis.text.y = element_text(size = rel(1.15)),
        axis.text.x = element_text(size = rel(1.1), angle = 45, hjust = 1, vjust = 1),
        axis.ticks = element_line(linewidth = rel(1.25)),
        axis.line = element_line(linewidth = rel(1.5))
    )
line_color1 <- "#d4d4d4"
point_color1 <- "#535252"

line_color2 <- "#CCD7E9"
point_color2 <- "#9BB3D3"

line_color3 <- "#E3938A"
point_color3 <- "#B53530"
# my_levels <- raw_data$schedule %>%
#     unique()
# line_colors <- c(line_color1, line_color2, line_color3)[my_levels] %>%
#     set_names(my_levels)
# point_colors <- c(point_color1, point_color2, point_color3)[my_levels] %>%
#     set_names(my_levels)
# point_shapes <- c(24, 21, 23)[my_levels] %>%
#     set_names(my_levels)

# Corrected AUC calculation function
calculate_auc <- function(x, y) {
    # Remove rows where y is NA
    valid_data <- na.omit(data.frame(x, y))
    x <- as.numeric(x)

    # Check if there's enough data for AUC calculation
    if (nrow(valid_data) < 2) {
        return(NA) # Not enough data to compute AUC
    }

    # Ensure data is sorted by x
    valid_data <- valid_data[order(valid_data$x), ]

    # Calculate differences in x
    diff_x <- diff(valid_data$x)

    # Calculate trapezoid areas and sum them to get AUC
    trapezoid_areas <- diff_x * (valid_data$y[-nrow(valid_data)] + valid_data$y[-1]) / 2
    auc <- sum(trapezoid_areas) # Calculate AUC

    return(auc)
}


remove_x_pct_missing_data <- function(data, missing_pct = 50) {
    result <- data %>%
        group_by(subject_id) %>%
        # Calculate the percentage of non-NA entries for 'npi' for each subject
        summarize(
            non_missing_count = sum(!is.na(npi)),
            total_count = n(),
            percentage_non_missing = non_missing_count / total_count * 100, .groups = "drop"
        ) %>%
        # Keep subjects with at least 50% non-missing entries
        filter(percentage_non_missing >= missing_pct) %>%
        inner_join(data, by = "subject_id") %>%
        dplyr::select(-non_missing_count, -total_count, -percentage_non_missing)
    return(result)
}


get_pairs_df <- function(data, verbose = FALSE) {
    all_week_combinations <- expand.grid(Var1 = levels(data$week), Var2 = levels(data$week)) %>%
        mutate(
            Week1 = as.numeric(gsub("week", "", Var1)),
            Week2 = as.numeric(gsub("week", "", Var2))
        ) %>%
        filter(Week1 < Week2) %>%
        select(Var1, Var2) %>%
        arrange(Var1, Var2)

    paired_week_bound_lst <- lapply(seq_len(nrow(all_week_combinations)), FUN = function(idx) {
        # idx <- 11
        my_week1 <- all_week_combinations$Var1[idx]
        my_week2 <- all_week_combinations$Var2[idx]

        if (my_week1 != my_week2) {
            week_levels <- levels(data$week)
            week_range <- week_levels[which(week_levels == my_week1):which(week_levels == my_week2)]

            result <- data %>%
                group_by(subject_id) %>%
                arrange(schedule, subject_id, week) %>%
                filter(week %in% week_range) %>%
                mutate(x = as.numeric(gsub("week", "", week))) %>%
                mutate(comparison = paste0(my_week1, " vs ", my_week2))

            summarized_result <- result %>%
                group_by(subject_id, schedule) %>%
                summarize(comparison_auc = calculate_auc(x, npi), .groups = "drop") %>%
                mutate(comparison = paste0(my_week1, " vs ", my_week2)) %>%
                left_join(result, by = c("subject_id", "schedule", "comparison"))

            if (verbose) {
                message(my_week1, " vs ", my_week2)
                print(summarized_result, n = 100)
            }

            return(summarized_result)
        }
    }) %>%
        bind_rows()

    comparison_factor_order <- paired_week_bound_lst %>%
        distinct(comparison) %>%
        separate(comparison, into = c("week1", "week2"), remove = FALSE, sep = " vs ") %>%
        mutate(
            week1_num = as.numeric(str_extract(week1, "\\d+")),
            week2_num = as.numeric(str_extract(week2, "\\d+"))
        ) %>%
        arrange(week1_num, week2_num) %>%
        pull(comparison)

    paired_week_df <- paired_week_bound_lst %>%
        mutate(comparison = factor(comparison, levels = comparison_factor_order)) %>%
        arrange(schedule, comparison)
    return(paired_week_df)
}


calculate_auc_intervals <- function(data, intervals, auc_function) {
    # Example usage
    # Assuming 'data' is your data frame and 'calculate_auc' is your AUC calculation function
    # intervals <- list("week4 to week12" = c("week4", "week12"),
    #                   "week16 to week24" = c("week16", "week24"))
    # auc_data <- calculate_auc_intervals(data, intervals, calculate_auc)
    # print(auc_data)

    # Create a data frame from the intervals list
    interval_data <- tibble(
        interval = names(intervals),
        start = sapply(intervals, `[[`, 1), # The 'sapply' function is used to access the list elements
        end = sapply(intervals, `[[`, 2)
    ) %>%
        mutate(
            start_num = as.numeric(gsub("week", "", start)),
            end_num = as.numeric(gsub("week", "", end))
        ) %>%
        filter(start_num < end_num)

    # Calculate AUC for each interval
    auc_results <- map_df(seq_len(nrow(interval_data)), function(idx) {
        start_week <- interval_data$start[idx]
        end_week <- interval_data$end[idx]

        week_range <- levels(data$week)[which(levels(data$week) == start_week):which(levels(data$week) == end_week)]

        result <- data %>%
            filter(week %in% week_range) %>%
            mutate(x = as.numeric(gsub("week", "", week))) %>%
            group_by(subject_id, schedule) %>%
            summarize(comparison_auc = auc_function(x, npi), .groups = "drop") %>%
            mutate(interval = paste0(start_week, " vs ", end_week))

        return(result)
    })

    return(auc_results)
}


# This function calculates the running AUC up to each week for each subject
calculate_running_auc <- function(data) {
    # Group by subject to perform calculations for each subject separately
    data %>%
        group_by(subject_id) %>%
        # Use arrange in case the data is not sorted by week_num
        arrange(schedule, subject_id, week_num) %>%
        # Calculate the running AUC for each row
        mutate(running_auc = map_dbl(week_num, function(w) {
            # Select the subset of data up to the current week
            subset_data <- filter(data, week_num <= w)
            # Use the calculate_auc function on the subset
            calculate_auc(subset_data$week_num, subset_data$delta_npi_from_baseline)
        })) %>%
        ungroup() # Remove the grouping
}

#' Pad DataFrame Groups with NA Columns
#'
#' This function takes a dataframe and pads groups of columns based on their prefixes
#' so that each group has the same number of columns. It's particularly useful for
#' preparing data for software like Prism, where groups of columns need to be equal in size
#' but might not inherently be due to missing data or unequal group sizes.
#'
#' @param df A dataframe with columns named in a "prefix_identifier" format, where
#'   the prefix indicates the group to which the column belongs. The first column
#'   is not considered for padding and is assumed to be an index or non-group identifier.
#'
#' @return A dataframe with the original data and added NA columns to ensure each
#'   group of columns based on prefixes have the same number of columns. It also
#'   sorts the columns to maintain the original order of groups, with padding columns
#'   at the end of each group. Additionally, a message is printed indicating the number
#'   to set for 'n' in Prism, representing the maximum group size.
#'
#' @examples
#' # Assuming df is your dataframe with the first column as an identifier
#' # and other columns named like "q8_1", "q16_1", ..., "q8_n", "q16_n":
#' padded_df <- pad_df_groups(df)
pad_df_groups <- function(df) {
    # Extract column prefixes and unique identifiers
    col_info <- str_split(names(df)[-1], "_", simplify = FALSE)
    prefixes <- sapply(col_info, function(x) x[1])
    unique_prefixes <- unique(prefixes)

    # Calculate max count for each prefix group
    prefix_counts <- sapply(unique_prefixes, function(prefix) sum(prefixes == prefix))
    max_count <- max(prefix_counts)

    # Create a list to collect padded columns for each prefix
    padded_cols_list <- list()

    for (prefix in unique_prefixes) {
        current_count <- sum(prefixes == prefix)
        pad_count <- max_count - current_count

        # if the prefix has the max number of columns, skip it
        if (pad_count == 0) next

        # Generate NA columns for padding
        pad_cols <- replicate(pad_count, NA_real_, simplify = FALSE)
        names(pad_cols) <- paste0(prefix, "_PAD_", seq_len(pad_count))

        # Collect padded columns
        padded_cols_list[[prefix]] <- pad_cols
    }

    # Add padding columns to the original dataframe and sort columns
    df_padded <- bind_cols(df, padded_cols_list)

    df_padded_sorted <- df_padded %>%
        pivot_longer(2:ncol(df_padded), names_to = "cols", values_to = "vals") %>%
        mutate(group = factor(str_split(cols, "_", simplify = TRUE)[, 1], levels = unique_prefixes)) %>%
        arrange(group) %>%
        dplyr::select(-group) %>%
        pivot_wider(names_from = cols, values_from = vals)

    message("Set prism n to: ", max_count)

    return(df_padded_sorted)
}


plot_line_graph <- function(df, t_test_df, hide_ns = FALSE, anova_res = NA, x = "week", y = "auc", group = "schedule", use_stars = FALSE, use_adjusted_p = TRUE) {
    # df = auc_plot_df; t_test_df = t_test_auc; x = "comparison"; y = "auc"; group = "schedule"; use_stars = FALSE; use_adjusted_p = TRUE
    if (!(x %in% colnames(df) || y %in% colnames(df))) {
        message("Colnames in df: ", colnames(df))
        stop("x, y must be columns in df")
    }

    my_x <- sym(x)
    my_y <- sym(y)


    my_label <- case_when(
        use_stars & use_adjusted_p ~ "p.adj.signif",
        !use_stars & use_adjusted_p ~ "p = {p.adj}",
        use_stars & !use_adjusted_p ~ "p.signif",
        !use_stars & !use_adjusted_p ~ "p = {p}",
        TRUE ~ NA
    )

    my_caption <- case_when(
        use_stars & use_adjusted_p ~ "Paired T-test with FDR corrected p-value",
        !use_stars & use_adjusted_p ~ "Paired T-test with FDR corrected p-value",
        use_stars & !use_adjusted_p ~ "Paired T-test (uncorrected p-value)",
        !use_stars & !use_adjusted_p ~ "Paired T-test (uncorrected p-value)",
        TRUE ~ NA
    )

    if (hide_ns) {
        new_t_test_df <- t_test_df %>%
            filter(p.adj.signif != "ns") %>%
            ungroup() %>%
            add_y_position("mean_se")
    } else {
        new_t_test_df <- t_test_df %>%
            ungroup() %>%
            add_y_position("mean_se")
    }
    # assign symbol for group here
    my_group <- sym(group)
    #
    my_plot <- ggplot(
        df,
        aes(x = !!my_x, y = !!my_y)
    ) +
        ggtitle(qq("Comparison of @{toupper(y)} by Schedule")) +
        my_pptx_theme +
        scale_color_manual(values = point_colors) +
        scale_fill_manual(values = line_colors) +
        scale_shape_manual(values = point_shapes) +
        stat_summary(
            geom = "line", fun = "mean",
            mapping = aes(group = !!my_group, color = !!my_group),
            linewidth = rel(1.5), show.legend = FALSE
        ) +
        stat_summary(
            geom = "errorbar", fun.data = "mean_se", width = 0.1,
            mapping = aes(group = !!my_group, color = !!my_group),
            linewidth = rel(1.1), show.legend = FALSE
        ) +
        stat_summary(
            geom = "point", fun = "mean",
            mapping = aes(group = !!my_group, fill = !!my_group, shape = !!my_group),
            color = "black",
            size = rel(5)
        ) +
        stat_pvalue_manual(new_t_test_df,
            label = my_label,
            tip.length = 0.005,
            size = rel(6)
        ) +
        facet_wrap(~schedule, scales = "free_x") +
        labs(caption = my_caption)



    if (!any(is.na(anova_res))) {
        my_plot <- my_plot +
            labs(subtitle = get_test_label(anova_res, detailed = TRUE))
    }
    return(my_plot)
}

plot_ungrouped_line_graph <- function(df, use_stars = FALSE, hide_ns = FALSE, use_adjusted_p = TRUE, size_stars = rel(10), my_step_increase = 0.085) {
    my_label <- case_when(
        use_stars & use_adjusted_p ~ "p.adj.signif",
        !use_stars & use_adjusted_p ~ "p = {p.adj}",
        use_stars & !use_adjusted_p ~ "p.signif",
        !use_stars & !use_adjusted_p ~ "p = {p}",
        TRUE ~ NA
    )


    anova_dat <- df %>%
        distinct(schedule, subject_id, week, npi) %>%
        group_by(subject_id) %>%
        arrange(schedule, subject_id, week) %>%
        filter(max(n()) == 4) %>%
        ungroup()

    anova_res <- anova_test(anova_dat, npi ~ week, wid = subject_id)

    ungrouped_t_test <- anova_dat %>%
        pairwise_t_test(npi ~ week, paired = TRUE, p.adjust.method = "fdr", detailed = TRUE) %>%
        add_significance("p")

    if (hide_ns) {
        new_ungrouped_t_test <- ungrouped_t_test %>%
            filter(p.adj.signif != "ns") %>%
            ungroup() %>%
            add_y_position("mean_se") %>%
            mutate(y.position = y.position + (0.05 * y.position))
    } else {
        new_ungrouped_t_test <- ungrouped_t_test %>%
            ungroup() %>%
            add_y_position("mean_se") %>%
            mutate(y.position = y.position + (0.05 * y.position))
    }

    my_plot <- ggplot(
        anova_dat,
        aes(x = week, y = npi)
    ) +
        ggtitle(qq("Comparison of @{toupper(y)} by Schedule")) +
        my_pptx_theme +
        scale_color_manual(values = point_colors) +
        scale_fill_manual(values = line_colors) +
        scale_shape_manual(values = point_shapes) +
        stat_summary(
            mapping = aes(group = schedule, color = schedule),
            geom = "line", fun = "mean",
            linewidth = rel(1.5), show.legend = FALSE
        ) +
        stat_summary(
            mapping = aes(group = schedule, color = schedule),
            geom = "errorbar", fun.data = "mean_se", width = 0.1,
            linewidth = rel(1.1), show.legend = FALSE
        ) +
        stat_summary(
            mapping = aes(group = schedule, fill = schedule, shape = schedule),
            geom = "point", fun = "mean",
            color = "black",
            size = rel(5)
        ) +
        stat_pvalue_manual(
            new_ungrouped_t_test,
            label = my_label,
            step.increase = my_step_increase,
            hide.ns = TRUE,
            size = size_stars
        ) +
        labs(
            subtitle = get_test_label(anova_res, detailed = TRUE),
            caption = get_pwc_label(new_ungrouped_t_test)
        )
    my_plot
}


plot_bar_graph <- function(df, t_test_df, hide_ns = FALSE, anova_res = NA, x = "week", y = "auc", group = "schedule", use_stars = FALSE, use_adjusted_p = TRUE, my_step_increase = 0.15) {
    # df = auc_plot_df; t_test_df = t_test_auc; x = "comparison"; y = "auc"; group = "schedule"; use_stars = FALSE; use_adjusted_p = TRUE
    if (!(x %in% colnames(df) || y %in% colnames(df) || group %in% colnames(df))) {
        message("Colnames in df: ", colnames(df))
        stop("x, y, and group must be columns in df")
    }

    my_x <- sym(x)
    my_y <- sym(y)
    my_group <- sym(group)

    my_label <- case_when(
        use_stars & use_adjusted_p ~ "p.adj.signif",
        !use_stars & use_adjusted_p ~ "p = {p.adj}",
        use_stars & !use_adjusted_p ~ "p.signif",
        !use_stars & !use_adjusted_p ~ "p = {p}"
    )

    my_caption <- case_when(
        use_stars & use_adjusted_p ~ "Paired T-test with FDR corrected p-value",
        !use_stars & use_adjusted_p ~ "Paired T-test with FDR corrected p-value",
        use_stars & !use_adjusted_p ~ "Paired T-test (uncorrected p-value)",
        !use_stars & !use_adjusted_p ~ "Paired T-test (uncorrected p-value)",
        TRUE ~ NA
    )

    if (hide_ns) {
        new_t_test_df <- t_test_df %>%
            filter(p.adj.signif != "ns") %>%
            ungroup() %>%
            add_y_position("max")
    } else {
        new_t_test_df <- t_test_df %>%
            ungroup() %>%
            add_y_position("max")
    }

    my_plot <- ggplot(
        df,
        aes(x = !!my_x, y = !!my_y)
    ) +
        ggtitle(qq("Comparison of @{toupper(y)} by Schedule")) +
        my_pptx_theme +
        facet_wrap(~schedule, scales = "free_x") +
        scale_color_manual(values = point_colors) +
        scale_fill_manual(values = line_colors) +
        scale_shape_manual(values = point_shapes) +
        stat_summary(
            geom = "col", fun = "mean",
            mapping = aes(group = !!my_group, fill = !!my_group),
            linewidth = rel(0.5), show.legend = FALSE,
            color = "black",
        ) +
        stat_summary(
            geom = "errorbar", fun.data = "mean_se", width = 0.1,
            mapping = aes(group = !!my_group, color = !!my_group),
            linewidth = rel(1.1), show.legend = FALSE,
        ) +
        geom_jitter(
            mapping = aes(group = !!my_group, fill = !!my_group, shape = !!my_group),
            color = "black",
            width = 0.1, alpha = 0.65,
            size = rel(5),
            stroke = rel(0.9)
        ) +
        stat_pvalue_manual(
            new_t_test_df,
            label = my_label,
            tip.length = 0.005,
            step.increase = my_step_increase,
            size = rel(6)
        ) +
        labs(caption = my_caption)

    my_plot
    if (!any(is.na(anova_res))) {
        my_plot <- my_plot +
            labs(subtitle = get_test_label(anova_res, detailed = TRUE))
    }
    return(my_plot)
}
