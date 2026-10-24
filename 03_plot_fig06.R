#!/usr/bin/env Rscript
# Figure 6: local OPGD q, Spearman direction, and four ordered-stratum contrasts.
# 图 6：a 为 q 与区间，b 为相关方向，c 为四个变量的分层 BC 对比。
if (!exists("ROOT", inherits = TRUE)) {
  script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(script_arg)) stop("Run this file with Rscript, or source 00_setup.R first.")
  script_path <- sub("^--file=", "", script_arg[1L])
  if (!file.exists(script_path)) script_path <- gsub("~+~", " ", script_path, fixed=TRUE)
  source(file.path(dirname(normalizePath(script_path)), "00_setup.R"))
}

local <- fread(file.path(DATA, "local_opgd.csv"))
strata <- fread(file.path(DATA, "local_opgd_strata.csv"))
observed <- fread(file.path(DATA, "observed_bc.csv"))
variables <- c("TRL", "MLL", "RRL", "DTS", "ILF", "RLF", "BAF", "NDVI", "WBF", "NTL", "POI", "POPD")
stopifnot(nrow(local) == 36L, !anyDuplicated(local[, .(year, variable)]),
          setequal(local$variable, variables), setequal(local$year, YEARS),
          !anyDuplicated(strata[, .(year, feature, ordered_stratum)]),
          all(strata$n > 0), all(is.finite(strata$mean_bc)))

# The full-precision published q values and 95% spatial-block bootstrap intervals
# are supplied as source data. Replotting does not rerun or change OPGD fits.
# Sort all twelve variables by their mean estimable q, as in the manuscript.
# 直接读取原始结果；不可把 q 解读成相关系数或排放贡献比例。
variable_order <- local[, .(mean_q = mean(q, na.rm = TRUE)), by = variable][order(mean_q)]$variable
local[, variable := factor(variable, levels = variable_order)]
local[, campaign := factor(year, levels = YEARS)]
offset <- position_dodge(width = .62)
panel_a <- ggplot(local, aes(q, variable, colour = campaign, shape = campaign)) +
  geom_errorbar(data = local[is.finite(q)],
                aes(xmin = q_boot_lo, xmax = q_boot_hi), orientation = "y",
                width = 0, position = offset, linewidth = .4) +
  geom_point(data = local[is.finite(q)], position = offset, size = 1.5) +
  year_scale() +
  scale_x_continuous(breaks = seq(0, .6, .2), limits = c(-.03, .62),
                     expand = expansion(mult = 0)) +
  labs(x = "Optimised q", y = NULL, title = "Local associations", tag = "(a)") +
  theme(legend.position = "inside", legend.position.inside = c(.88, .20),
        legend.background = element_rect(fill = "white", colour = NA),
        legend.margin = margin(1, 1, 1, 1))

# q has no sign. Spearman rho is therefore displayed separately to show the
# direction of association. A non-estimable q never becomes an artificial zero.
# q 本身无正负号；另画 Spearman ρ 表示方向。不可估计的 q 保留为缺失。
panel_b <- ggplot(local, aes(rho, variable, colour = campaign, shape = campaign)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = .35, colour = "#C4CBCF") +
  geom_point(position = offset, size = 1.5) +
  year_scale() +
  scale_x_continuous(breaks = seq(-.6, .6, .3), limits = c(-.64, .60),
                     expand = expansion(mult = 0)) +
  labs(x = "Spearman association with BC", y = NULL,
       title = "Direction outside the q statistic", tag = "(b)") +
  theme(legend.position = "none")

# Normalize stratum mean BC by the median of all observed cell means in the
# SAME campaign, not by the mean or the median of that stratum.
# 分层均值 / 同一调查年份全部观测网格的 BC 中位数；标签同时保留样本量。
medians <- observed[, .(campaign_median = median(BC)), by = year]
strata <- merge(strata, medians, by = "year", all.x = TRUE, sort = FALSE)
strata[, relative_mean := mean_bc / campaign_median]
feature_order <- c("POPD", "DTS", "TRL", "NDVI")

# Explicitly add absent strata as NA so grey cells and dashes remain visible.
# A shared scale centred at ratio = 1 makes the four heatmaps comparable.
# 显式补齐不存在的分层，并用灰色加破折号表示；绝不补成零。
cells <- merge(CJ(year = YEARS, feature = feature_order, ordered_stratum = 1:5),
               strata, by = c("year", "feature", "ordered_stratum"), all.x = TRUE)
cells[, feature := factor(feature, levels = feature_order)]
cells[, campaign := factor(year, levels = rev(YEARS))]
cells[, cell_label := ifelse(is.finite(relative_mean),
                             sprintf("%.2f\nn=%d", relative_mean, n), "—")]
spread <- max(abs(cells$relative_mean - 1), na.rm = TRUE)
ratio_limits <- 1 + c(-spread, spread)
ratio_palette <- c("#2563EB", "#F8FAFC", "#E11D48")
panel_c <- ggplot(cells, aes(factor(ordered_stratum), campaign, fill = relative_mean)) +
  geom_tile(colour = "white", linewidth = .35) +
  geom_text(aes(label = cell_label,
                colour = contrast_text(relative_mean, ratio_palette, ratio_limits)),
            size = 2.25, lineheight = 1.05) +
  scale_colour_identity() +
  scale_fill_gradientn(colours = ratio_palette, limits = ratio_limits,
                        na.value = MISSING_COLOR, guide = "none") +
  scale_x_discrete(expand = c(0, 0)) + scale_y_discrete(expand = c(0, 0)) +
  facet_wrap(~feature, nrow = 2) +
  labs(x = "Ordered stratum", y = NULL,
       title = "BC contrasts across ordered strata", tag = "(c)") +
  theme(axis.line = element_blank(), axis.ticks = element_blank(),
        panel.spacing = unit(4, "mm"), strip.text = element_text(face = "plain"),
        axis.text = element_text(size = 7))

# Preserve the PDF's three-panel organization: a/b above, c centred below,
# with POPD/DTS above TRL/NDVI within c. No fixed-partition panel is introduced.
bottom <- wrap_elements(full = panel_c)  # Keep c's internal 2 × 2 facets together.
figure_06 <- (panel_a | panel_b) /
  (plot_spacer() + bottom + plot_spacer() + plot_layout(widths = c(.16, 1, .16))) +
  plot_layout(heights = c(1, 1.12))
save_fig(figure_06, "Fig06", width = 183, height = 157)
