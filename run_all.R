#!/usr/bin/env Rscript
# One command recreates manuscript Figures 5-10 and Tables 1-2.
arg <- grep('^--file=',commandArgs(FALSE),value=TRUE)
script <- if (length(arg)) sub('^--file=','',arg[1]) else tryCatch(sys.frame(1)$ofile,error=function(e)NULL)
if (is.null(script)) stop('Run Rscript /path/to/Figshare/run_all.R, or source this file.')
# Rscript may encode spaces in --file as ~+~; restore only if needed.
if (!file.exists(script)) script <- gsub('~+~',' ',script,fixed=TRUE)
source(file.path(dirname(normalizePath(script)), '00_setup.R'))
scripts <- c('02_plot_fig05.R','03_plot_fig06.R','04_plot_fig07.R',
             '05_plot_fig08_09.R','06_plot_fig10.R','07_export_tables.R')
for (f in scripts) source(file.path(ROOT,f), encoding='UTF-8')
message('Completed: Figures 5-10 and Tables 1-2. Outputs: figs/ and tables/.')
