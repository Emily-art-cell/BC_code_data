# Run once before run_all.R; only the six packages needed by this archive.
packages <- c('data.table','ggplot2','patchwork','sf','scales','ragg')
needed <- packages[!vapply(packages, requireNamespace, logical(1), quietly=TRUE)]
if (requireNamespace('ggplot2',quietly=TRUE) && packageVersion('ggplot2') < '3.5.2') needed <- c(needed,'ggplot2')
if (requireNamespace('patchwork',quietly=TRUE) && packageVersion('patchwork') < '1.3.0') needed <- c(needed,'patchwork')
if (length(needed)) install.packages(unique(needed), repos='https://cloud.r-project.org')
message('Required packages are available. Run Rscript run_all.R.')
