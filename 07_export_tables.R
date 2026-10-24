#!/usr/bin/env Rscript
# Tables 1 and 2 in the supplied manuscript. Run with Rscript 07_export_tables.R.
# Only the observations and genuine held-out predictions are required.
if (!exists("ROOT", inherits = FALSE)) {
  script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[1]) else tryCatch(sys.frame(1)$ofile,error=function(e)NULL)
  if (is.null(script_path)) stop("Run this file with Rscript, or source 00_setup.R first.")
  if (!file.exists(script_path)) script_path <- gsub("~+~", " ", script_path, fixed=TRUE)
  script_dir <- dirname(normalizePath(script_path))
  source(file.path(script_dir, "00_setup.R"))
}
suppressPackageStartupMessages(library(grid))

export_tables <- function() {
  dir.create(TABLES, recursive = TRUE, showWarnings = FALSE)

  # Table 1 uses the observed 500 m cell means, not repeated OOF records.
  # stats::sd calculates the sample between-cell standard deviation (n - 1).
  observed <- read.csv(file.path(DATA, "observed_bc.csv"), check.names = FALSE)
  stopifnot(all(c("year", "BC") %in% names(observed)), all(is.finite(observed$BC)))
  if ("GRID_ID" %in% names(observed)) stopifnot(!anyDuplicated(observed[c("year", "GRID_ID")]))
  years <- c(2016L, 2022L, 2026L)
  table1 <- do.call(rbind, lapply(years, function(yr) {
    bc <- observed$BC[observed$year == yr]
    stopifnot(length(bc) == c(239L, 225L, 211L)[match(yr, years)])
    data.frame(Year = yr, Mean = mean(bc), Median = median(bc), Between_cell_SD = sd(bc))
  }))
  write.csv(table1, file.path(TABLES, "Table_01.csv"), row.names = FALSE)

  # Table 2 averages scores calculated from all held-out observations within
  # each repeat. It does not score the cloud of repeat-averaged predictions.
  models <- c("RF_XB", "RF_XBS", "Cubist_XBS", "XGB_XBS", "SVM_XBS",
              "GBM_XBS", "KNN_XBS", "ENR_XBS", "SVRK_XBS")
  labels <- c("RF (X + B)", "RF", "Cubist", "XGBoost", "RBF-SVM",
              "GBM", "KNN", "Elastic net", "MCRK")
  oof <- read.csv(file.path(DATA, "oof_predictions.csv"), check.names = FALSE)
  stopifnot(all(c("year", "GRID_ID", "model", "repeat_id", "obs", "pred") %in% names(oof)),
            all(is.finite(oof$obs)), all(is.finite(oof$pred)),
            !anyDuplicated(oof[c("year", "GRID_ID", "model", "repeat_id")]))
  oof <- oof[oof$model %in% models, ]
  groups <- split(oof, interaction(oof$year, oof$model, oof$repeat_id, drop = TRUE))
  repeats <- do.call(rbind, lapply(groups, function(z) {
    stopifnot(nrow(z) == c(239L, 225L, 211L)[match(z$year[1], years)])
    sse <- sum((z$pred - z$obs)^2)
    sst <- sum((z$obs - mean(z$obs))^2)
    stopifnot(sst > 0)
    data.frame(year = z$year[1], model = z$model[1], repeat_id = z$repeat_id[1],
               R2 = 1 - sse / sst, RMSE = sqrt(sse / nrow(z)))
  }))
  stopifnot(all(c("year", "model", "repeat_id", "R2", "RMSE") %in% names(repeats)),
            nrow(repeats) == 135L, all(is.finite(repeats$R2)),
            all(is.finite(repeats$RMSE)), !anyDuplicated(repeats[c("year", "model", "repeat_id")]))
  table2 <- do.call(rbind, lapply(years, function(yr) {
    ans <- do.call(rbind, lapply(seq_along(models), function(j) {
      z <- repeats[repeats$year == yr & repeats$model == models[j], ]
      stopifnot(nrow(z) == 5L, setequal(z$repeat_id, 1:5))
      data.frame(Year = yr, Model = labels[j], R2 = mean(z$R2), RMSE = mean(z$RMSE))
    }))
    base_r2 <- ans$R2[1]
    base_rmse <- ans$RMSE[1]
    stopifnot(base_r2 > 0, base_rmse > 0)
    # Calculate percentages from unrounded scores; round only for display.
    ans$R2_relative_change_pct <- 100 * (ans$R2 - base_r2) / base_r2
    ans$RMSE_reduction_pct <- 100 * (base_rmse - ans$RMSE) / base_rmse
    ans$R2_relative_change_pct[1] <- NA_real_
    ans$RMSE_reduction_pct[1] <- NA_real_
    # Include the reference model in the best-score comparison (2022 RF XB).
    ans$Best_R2 <- ans$R2 == max(ans$R2)
    ans$Best_RMSE <- ans$RMSE == min(ans$RMSE)
    ans
  }))
  write.csv(table2, file.path(TABLES, "Table_02.csv"), row.names = FALSE, na = "")

  # Use native grid text and rules so PDF tables remain editable vector text.
  # Raster export uses 600 dpi, the same physical size as the PDF export.
  export_table <- function(draw, id, width, height) {
    pdf_file <- file.path(TABLES, paste0(id, ".pdf"))
    png_file <- file.path(TABLES, paste0(id, ".png"))
    grDevices::pdf(pdf_file, width = width / 25.4, height = height / 25.4,
                   family = "sans", onefile = TRUE, useDingbats = FALSE)
    tryCatch(draw(), finally = grDevices::dev.off())
    ragg::agg_png(png_file, width = width, height = height, units = "mm", res = 600,
                  background = "white")
    tryCatch(draw(), finally = grDevices::dev.off())
  }
  table_canvas <- function(width, height) {
    grid.newpage()
    pushViewport(viewport(xscale = c(0, width), yscale = c(height, 0)))
  }
  tx <- function(label, x, y, size = 8, bold = FALSE, just = "centre") {
    grid.text(label, x = unit(x, "native"), y = unit(y, "native"), just = just,
              gp = gpar(fontfamily = "sans", fontsize = size,
                        fontface = if (bold) "bold" else "plain", col = "#202020"))
  }
  rule <- function(y, from, to, width = 0.6) {
    grid.lines(x = unit(c(from, to), "native"), y = unit(c(y, y), "native"),
               gp = gpar(col = "#202020", lwd = width))
  }
  draw1 <- function() {
    table_canvas(160, 44)
    tx(expression(paste("Table 1. Statistical summary of roadside BC (", mu, "g ", m^{-3}, ").")),
       4, 5, 8.8, just = "left")
    rule(10, 4, 156, 0.8)
    xs <- c(18, 54, 92, 134)
    headers <- c("Year", "Mean", "Median", "Between-cell SD")
    for (j in seq_along(xs)) tx(headers[j], xs[j], 15, 8, TRUE)
    rule(19, 4, 156, 0.4)
    for (i in seq_len(nrow(table1))) {
      vals <- c(as.character(table1$Year[i]), sprintf("%.2f", unlist(table1[i, -1])))
      for (j in seq_along(xs)) tx(vals[j], xs[j], 23 + (i - 1) * 6)
    }
    rule(39, 4, 156, 0.8)
    popViewport()
  }
  draw2 <- function() {
    table_canvas(220, 112)
    tx("Table 2. Spatially validated predictive performance of MCRK and benchmark regressors.",
       4, 5, 9, just = "left")
    tx("RF (X + B) is the reference; all other models use X + B + S.",
       4, 11, 7.5, just = "left")
    rule(16, 4, 216, 0.8)
    tx("Model", 4, 23, 8, TRUE, "left")
    starts <- c(34, 95, 156)
    for (k in seq_along(years)) {
      tx(as.character(years[k]), starts[k] + 29, 21, 8.5, TRUE)
      rule(25, starts[k], starts[k] + 59, 0.4)
      tx(expression(R^2), starts[k] + 14, 29, 8)
      tx("RMSE", starts[k] + 45, 29, 8)
    }
    rule(33, 4, 216, 0.5)
    for (i in seq_along(models)) {
      y <- 38 + (i - 1) * 5.7
      tx(labels[i], 4, y, 7.9, just = "left")
      for (k in seq_along(years)) {
        z <- table2[table2$Year == years[k] & table2$Model == labels[i], ]
        val_r2 <- sprintf("%.3f", z$R2)
        val_rmse <- sprintf("%.3f", z$RMSE)
        if (i > 1) {
          val_r2 <- sprintf("%s (%+.1f%%)", val_r2, z$R2_relative_change_pct)
          val_rmse <- sprintf("%s (%+.1f%%)", val_rmse, z$RMSE_reduction_pct)
        }
        tx(val_r2, starts[k] + 14, y, 7.3, z$Best_R2)
        tx(val_rmse, starts[k] + 45, y, 7.3, z$Best_RMSE)
      }
      if (i %in% c(1, 8)) rule(y + 2.85, 4, 216, 0.4)
    }
    rule(87, 4, 216, 0.8)
    tx("Parentheses: relative R2 change and RMSE reduction versus RF (X + B); negative values indicate deterioration.",
       4, 93, 7.2, just = "left")
    tx("Scores are means of five repeat-level spatial cross-validation metrics. Percentages use unrounded scores.",
       4, 99, 7.2, just = "left")
    tx(expression(paste("Bold: highest ", R^2, " or lowest RMSE in each campaign, including the reference. RMSE: ", mu, "g ", m^{-3}, ".")),
       4, 105, 7.2, just = "left")
    popViewport()
  }
  export_table(draw1, "Table_01", 160, 44)
  export_table(draw2, "Table_02", 220, 112)
  invisible(list(Table_01 = table1, Table_02 = table2))
}

export_tables()
