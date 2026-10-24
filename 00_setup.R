# Shared setup for the figure/table reproduction archive.
# 统一路径与样式：无论从哪个工作目录运行，均读取本文件夹内的数据。
setup_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
if (is.null(setup_file)) {
  arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  if (length(arg)) setup_file <- sub('^--file=', '', arg[1])
}
if (!is.null(setup_file) && !file.exists(setup_file)) setup_file <- gsub('~+~',' ',setup_file,fixed=TRUE)
ROOT <- if (!is.null(setup_file)) dirname(normalizePath(setup_file, mustWork = TRUE)) else normalizePath('.')
DATA <- file.path(ROOT, 'data')
TABLES <- file.path(ROOT, 'tables')
FIGS <- file.path(ROOT, 'figs')
required <- c('data.table', 'ggplot2', 'patchwork', 'sf', 'scales', 'ragg')
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop('Missing R packages: ', paste(missing, collapse = ', '),
                         '. Run Rscript install_dependencies.R first.', call. = FALSE)
if (packageVersion('ggplot2') < '3.5.2' || packageVersion('patchwork') < '1.3.0')
  stop('Use ggplot2 >= 3.5.2 and patchwork >= 1.3.0. Run install_dependencies.R.', call. = FALSE)
suppressPackageStartupMessages({
  library(data.table); library(ggplot2); library(patchwork)
  library(sf); library(scales); library(grid)
})
dir.create(FIGS, showWarnings = FALSE)
dir.create(TABLES, showWarnings = FALSE)
YEARS <- c(2016L, 2022L, 2026L)
SEED <- 20260929L
set.seed(SEED)
FONT <- 'sans'  # Portable system sans-serif font; no proprietary font is required.
YEAR_COLORS <- c('2016'='#2563EB', '2022'='#F97316', '2026'='#C026D3')
YEAR_SHAPES <- c('2016'=16L, '2022'=17L, '2026'=15L)
FIGCOL <- c(ink='#172554', grey='#64748B', light='#F1F5F9', blue='#2563EB',
            teal='#0D9488', orange='#F97316', purple='#9333EA')
BC_PALETTE <- c('#FFF2A8','#FFD04B','#FF9438','#F34B45','#C51D69','#741B7C')
Q_PALETTE <- c('#EFF6FF','#BFDBFE','#60A5FA','#2563EB','#312E81')
MISSING_COLOR <- '#D1D5DB'
theme_set(theme_classic(base_size=8, base_family=FONT) + theme(
  axis.line=element_line(linewidth=.3, colour=FIGCOL['ink']),
  axis.ticks=element_line(linewidth=.25, colour=FIGCOL['ink']),
  axis.text=element_text(size=7, colour=FIGCOL['ink']),
  axis.title=element_text(size=8, colour=FIGCOL['ink']),
  legend.title=element_text(size=7), legend.text=element_text(size=6.5),
  legend.key.height=unit(3,'mm'), legend.key.width=unit(4,'mm'),
  strip.text=element_text(size=8, face='bold'), strip.background=element_blank(),
  plot.title=element_text(size=9, hjust=0),
  plot.subtitle=element_text(size=7, colour=FIGCOL['grey']),
  plot.tag=element_text(size=9, face='bold'),
  plot.margin=margin(5,6,5,5), panel.grid=element_blank()))

# Choose white/dark label text from the actual heatmap colour.
contrast_text <- function(value, palette, limits) {
  colours <- scales::col_numeric(palette, domain=limits, na.color=MISSING_COLOR)(value)
  rgb <- grDevices::col2rgb(colours)/255
  linear <- ifelse(rgb<=.04045, rgb/12.92, ((rgb+.055)/1.055)^2.4)
  ifelse(colSums(linear*c(.2126,.7152,.0722)) < .22, '#FFFFFF', '#172554')
}
year_scale <- function() list(
  scale_colour_manual(values=YEAR_COLORS, name='Campaign'),
  scale_shape_manual(values=YEAR_SHAPES, name='Campaign'))
panel_tags <- function() plot_annotation(tag_levels='a', tag_prefix='(', tag_suffix=')')

# All figures use the same dimensions in PDF and PNG. The native PDF device
# preserves text/lines; maps contain the actual 500 m raster. PNG is 600 dpi.
save_fig <- function(p, id, width=183, height=150) {
  base <- file.path(FIGS, id)
  if (Sys.info()[['sysname']]=='Darwin') {
    # Quartz avoids an optional XQuartz/X11 dependency on macOS.
    grDevices::quartz(type='pdf',file=paste0(base,'.pdf'),width=width/25.4,
                     height=height/25.4,family='Helvetica',bg='white')
  } else if (capabilities('cairo')) {
    grDevices::cairo_pdf(paste0(base,'.pdf'), width=width/25.4, height=height/25.4,
                        family=FONT, bg='white', onefile=TRUE)
  } else {
    grDevices::pdf(paste0(base,'.pdf'), width=width/25.4, height=height/25.4,
                   family='Helvetica', bg='white', useDingbats=FALSE)
  }
  tryCatch(print(p), finally=dev.off())
  ragg::agg_png(paste0(base,'.png'), width=width, height=height, units='mm',
                res=600, background='white')
  tryCatch(print(p), finally=dev.off())
  message('Exported ', id, ': PDF + PNG (600 dpi)')
  invisible(p)
}

# Metrics are calculated within each full spatial-CV repeat, then averaged.
# Averaging predictions first gives a different estimator (used only in Fig. 8).
read_oof <- function() {
  o <- fread(file.path(DATA,'oof_predictions.csv'))
  stopifnot(!anyDuplicated(o[,.(year,GRID_ID,repeat_id,model)]),
            all(is.finite(o$obs)), all(is.finite(o$pred)))
  o
}
repeat_metrics <- function(o) {
  o[,.(R2=1-sum((obs-pred)^2)/sum((obs-mean(obs))^2),
       RMSE=sqrt(mean((obs-pred)^2))), by=.(year,model,repeat_id)]
}
