#!/usr/bin/env Rscript
# Figure 5: campaign BC distributions and observed spatial autocorrelation.
# 图 5：按稿件的 a–b 顺序输出，不混入其他图的地图或相关性子图。
if (!exists("ROOT", inherits = TRUE)) {
  script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (!length(script_arg)) stop("Run this file with Rscript, or source 00_setup.R first.")
  script_path <- sub("^--file=", "", script_arg[1L])
  if (!file.exists(script_path)) script_path <- gsub("~+~", " ", script_path, fixed=TRUE)
  source(file.path(dirname(normalizePath(script_path)), "00_setup.R"))
}

observed <- fread(file.path(DATA, "observed_bc.csv"))
moran <- fread(file.path(DATA, "observed_moran.csv"))
stopifnot(!anyDuplicated(observed[, .(year, GRID_ID)]),
          all(is.finite(observed$BC)),
          setequal(unique(observed$year), YEARS),
          !anyDuplicated(moran$year), setequal(moran$year, YEARS))
observed[, campaign := factor(year, levels = YEARS)]
moran[, campaign := factor(year, levels = YEARS)]

# BC is the original mean concentration of each observed 500 m cell (µg/m³).
# The violin uses all observations, is trimmed at each campaign's observed
# range, and has equal normalized area across campaigns.
# White boxes show median and interquartile range; outliers remain in the density.
# BC 为观测网格的原始均值；小提琴使用全部观测，白框为中位数和四分位区间。
distribution_colours <- c("2016" = "#3B648F", "2022" = "#209E91", "2026" = "#F56B50")
panel_a <- ggplot(observed, aes(campaign, BC, fill = campaign)) +
  geom_violin(width = .85, scale = "area", trim = TRUE,
              linewidth = .25, colour = NA) +
  geom_boxplot(width = .18, outlier.shape = NA, linewidth = .4,
               fill = "white", colour = "#333333") +
  scale_fill_manual(values = distribution_colours, guide = "none") +
  scale_y_continuous(breaks = seq(0, 25, 5), expand = expansion(mult = c(0, .02))) +
  coord_cartesian(ylim = c(0, 25)) +
  labs(x = "Survey year", y = "BC concentration (µg/m³)",
       title = "Distribution of BC concentrations", tag = "(a)")

# Preserve the published observed-response Moran statistics, rather than
# accidentally substituting residual Moran statistics from prediction models.
# These values use directed 8-nearest-neighbour, row-standardized weights.
# 保留稿件的观测 BC Moran's I；不能替换为模型残差的 Moran's I。
panel_b <- ggplot(moran, aes(campaign, moran_i, colour = campaign)) +
  geom_segment(aes(xend = campaign, y = 0, yend = moran_i), linewidth = .4) +
  geom_point(aes(shape = campaign), size = 2.4) +
  geom_text(aes(label = sprintf("%.3f", moran_i)),
            nudge_y = .085, colour = "#111111", size = 3) +
  scale_colour_manual(values = distribution_colours, guide = "none") +
  scale_shape_manual(values = YEAR_SHAPES, guide = "none") +
  scale_y_continuous(breaks = seq(0, 1, .25), limits = c(-.05, 1.05),
                     labels = label_number(accuracy = .01), expand = expansion(mult = 0)) +
  labs(x = "Survey year", y = "Moran's I",
       title = "Temporal variation in Moran's I", tag = "(b)")

# The manuscript has exactly two horizontal panels in this figure.
figure_05 <- (panel_a | panel_b) + plot_layout(widths = c(1.1, 1))
save_fig(figure_05, "Fig05", width = 183, height = 76)
