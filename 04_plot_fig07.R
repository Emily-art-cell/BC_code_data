#!/usr/bin/env Rscript
# Figure 7: donor tails, matched multiscale q, and four SDO maps.
# 图 7：使用稿件中的子图顺序，重绘直方图、尺度比较和四幅地图。
if (!exists("ROOT", inherits = TRUE)) {
  script_arg <- commandArgs(trailingOnly = FALSE)
  script_path <- sub("^--file=", "", script_arg[grepl("^--file=", script_arg)][1L])
  if (is.na(script_path)) stop("Run this file with Rscript, or source 00_setup.R first.")
  if (!file.exists(script_path)) script_path <- gsub("~+~", " ", script_path, fixed=TRUE)
  source(file.path(dirname(normalizePath(script_path)), "00_setup.R"))
}

donors <- fread(file.path(DATA, "fig07_donors.csv"))
q_summary <- fread(file.path(DATA, "fig07_scale_summary.csv"))
sdo_maps <- fread(file.path(DATA, "fig07_sdo_maps.csv"))
boundary_m <- st_read(file.path(DATA, "shanghai_boundary.gpkg"), layer = "boundary", quiet = TRUE)
stopifnot(st_crs(boundary_m)$epsg == 32651,
          all(c("TRL", "NDVI") %in% donors$variable),
          all(is.finite(donors$local_sd) & donors$local_sd > 0),
          nrow(sdo_maps) == 56030L)

# Recompute z from supplied donor values; use strict, signed tails.
# 仅 z > 2 / z < -2 的供体进入相应尾部；负尾保留负号。
donors[, z := (value - local_mean) / local_sd]
donors[, tail_group := factor(fifelse(z > 2, "Positive tail",
                                    fifelse(z < -2, "Negative tail", "Ordinary")),
                              levels = c("Negative tail", "Ordinary", "Positive tail"))]
donors[, variable := factor(variable, levels = c("TRL", "NDVI"))]
tail_sums <- donors[, .(S_pos = sum(z[z > 2]), S_neg = sum(z[z < -2])), by = variable]
tail_labels <- setNames(sprintf("%s: S+ %.2f | S- %.2f",
                               tail_sums$variable, tail_sums$S_pos, tail_sums$S_neg),
                        as.character(tail_sums$variable))
histogram <- ggplot(donors, aes(z, fill = tail_group)) +
  geom_histogram(binwidth = .5, boundary = 0, closed = "right",
                 colour = "white", linewidth = .15) +
  geom_vline(xintercept = c(-2, 2), linetype = "dashed", linewidth = .35, colour = "#64748B") +
  scale_fill_manual(values = c("Negative tail" = "#2563EB", "Ordinary" = "#CBD5E1",
                              "Positive tail" = "#DB2777"), guide = "none") +
  facet_wrap(~variable, ncol = 1, labeller = labeller(variable = tail_labels)) +
  scale_x_continuous(breaks = c(-4, -2, 0, 2, 4)) +
  labs(x = "Neighbour z = (value - mean) / SD", y = "Donor cells",
       title = "How SDO separates the tails") +
  theme(strip.text = element_text(size = 6.3), axis.text = element_text(size = 5.8),
        axis.title = element_text(size = 6.5), panel.spacing.y = grid::unit(2, "mm"))

# The comparison uses the SAME eligible base variables for all four summaries.
# n=0 is not estimable (NE); it must remain missing rather than become q=0.
families <- c("B_mean", "B_sd", "S_pos", "S_neg")
q_summary[, family := factor(family, levels = rev(families))]
q_limits <- c(0, max(q_summary$median_q, na.rm = TRUE))
q_panel <- ggplot(q_summary, aes(factor(radius_km), family, fill = median_q)) +
  geom_tile(colour = "white", linewidth = .3) +
  geom_text(aes(label = ifelse(n_valid > 0,
                             paste0(sprintf("%.2f", median_q), "\nn=", n_valid), "NE\nn=0"),
                colour = contrast_text(median_q, Q_PALETTE, q_limits)),
            size = 1.8, lineheight = 1.05) +
  scale_colour_identity() +
  scale_y_discrete(labels = c(B_mean = "B mean", B_sd = "B SD", S_pos = "S+", S_neg = "S-")) +
  scale_fill_gradientn(colours = Q_PALETTE, limits = q_limits,
                       na.value = MISSING_COLOR, name = "Median q") +
  facet_wrap(~year, nrow = 1) +
  labs(x = "Cumulative radius (km)", y = NULL, title = "Association across all five buffers") +
  theme(axis.line = element_blank(), axis.ticks = element_blank(),
        axis.text = element_text(size = 5.8), axis.text.y = element_text(angle = -25),
        strip.text = element_text(size = 7), panel.spacing.x = grid::unit(1.5, "mm"),
        legend.position = "right", legend.title = element_text(size = 6.2),
        legend.text = element_text(size = 5.8)) +
  guides(fill = guide_colourbar(barwidth = grid::unit(2.5, "mm"),
                               barheight = grid::unit(38, "mm"), title.position = "right"))

# Coordinates are EPSG:32651 metres; display in kilometres without reprojecting.
# 四幅地图各自使用完整带符号色标，不能用颜色跨子图比较数值。
boundary_km <- boundary_m
st_geometry(boundary_km) <- st_geometry(boundary_km) / 1000
st_crs(boundary_km) <- NA
bbox <- st_bbox(boundary_km)
x_limits <- unname(c(bbox["xmin"], bbox["xmax"]) + c(-2, 2))
y_limits <- unname(c(bbox["ymin"], bbox["ymax"]) + c(-2, 2))
frame <- st_sfc(st_polygon(list(rbind(c(x_limits[1], y_limits[1]),
                                    c(x_limits[2], y_limits[1]),
                                    c(x_limits[2], y_limits[2]),
                                    c(x_limits[1], y_limits[2]),
                                    c(x_limits[1], y_limits[1])))))
outside_city <- st_difference(frame, st_union(boundary_km))
map_specs <- data.table(variable = c("TRL", "TRL", "NDVI", "NDVI"),
                        tail = c("S_pos", "S_neg", "S_pos", "S_neg"))
map_panels <- lapply(seq_len(nrow(map_specs)), function(i) {
  variable_i <- map_specs$variable[i]
  tail_i <- map_specs$tail[i]
  map_data <- sdo_maps[variable == variable_i]
  limits_i <- range(c(0, map_data[[tail_i]]), na.rm = TRUE)
  positive <- tail_i == "S_pos"
  palette_i <- if (positive) c("#F8FAFC", "#FFE066", "#FF8A24", "#EF476F", "#A21CAF") else
    c("#312E81", "#2563EB", "#38BDF8", "#BAE6FD", "#F8FAFC")
  ggplot() +
    geom_sf(data = boundary_km, fill = "#F0F2F2", colour = NA) +
    geom_raster(data = map_data, aes(x = x / 1000, y = y / 1000, fill = .data[[tail_i]]),
                interpolate = FALSE) +
    geom_sf(data = outside_city, fill = "white", colour = NA) +
    geom_sf(data = boundary_km, fill = NA, colour = "#A3ADB2", linewidth = .1) +
    coord_sf(xlim = x_limits, ylim = y_limits, expand = FALSE, datum = NA) +
    scale_fill_gradientn(colours = palette_i, limits = limits_i,
                         breaks = limits_i, labels = label_number(accuracy = 1),
                         na.value = MISSING_COLOR,
                         name = if (positive) "Positive z-score sum" else "Negative z-score sum") +
    labs(title = paste0(variable_i, " | ", if (positive) "S+" else "S-")) +
    theme_void(base_family = "sans", base_size = 7) +
    theme(plot.title = element_text(size = 7.5, hjust = 0),
          legend.position = "bottom", legend.title = element_text(size = 6),
          legend.text = element_text(size = 5.8), plot.tag = element_text(size = 9, face = "bold"),
          legend.box.margin = margin(-3, 0, -1, 0), plot.margin = margin(3, 3, 3, 3)) +
    guides(fill = guide_colourbar(barwidth = grid::unit(27, "mm"),
                                 barheight = grid::unit(2.3, "mm"), title.position = "top"))
})

# Explicit a-f labels preserve the manuscript layout, including nested panels.
histogram <- histogram + labs(tag = "(a)")
q_panel <- q_panel + labs(tag = "(b)")
for (i in seq_along(map_panels)) map_panels[[i]] <- map_panels[[i]] + labs(tag = paste0("(", letters[i + 2L], ")"))
top_row <- (histogram | q_panel) + plot_layout(widths = c(1, 1.8))
figure_07 <- top_row / wrap_plots(map_panels, nrow = 1) +
  plot_layout(heights = c(1, .9))
save_fig(figure_07, "Fig07", width = 183, height = 145)
