# Reproduce manuscript Figures 8 and 9 from genuine saved out-of-fold predictions.
if (!exists('ROOT', inherits=TRUE)) {
  arg <- grep('^--file=',commandArgs(FALSE),value=TRUE)
  script <- if(length(arg)) sub('^--file=','',arg[1]) else sys.frame(1)$ofile
  if (!file.exists(script)) script <- gsub('~+~',' ',script,fixed=TRUE)
  source(file.path(dirname(normalizePath(script)), '00_setup.R'))
}
o <- read_oof()
mm <- repeat_metrics(o)
scores <- mm[,.(R2=mean(R2), RMSE=mean(RMSE)), by=.(year,model)]

# Figure 8: one point per observed cell, averaging its five OOF predictions.
# 点云仅用于展示；表2和图9的指标先在每次完整重复内计算，再取平均。
oo <- o[model=='SVRK_XBS',.(obs=obs[1],pred=mean(pred),n_repeats=.N),by=.(year,GRID_ID)]
stopifnot(all(oo$n_repeats==5L), nrow(oo)==675L)
for (yr in YEARS) {
  ii <- which(oo$year==yr)
  s <- sd(oo$obs[ii])
  # Counts are within radius 0.35 in (observed/SD, predicted/SD) space,
  # including the point itself; no spatial smoothing or jitter is applied.
  dist2 <- as.matrix(dist(cbind(oo$obs[ii]/s,oo$pred[ii]/s)))
  oo[ii,local_point_count:=rowSums(dist2<=.35+1e-12)]
}
density_limits <- c(1,max(oo$local_point_count))
scatters <- lapply(YEARS,function(yr) {
  z <- oo[year==yr][order(local_point_count)]
  lim <- range(c(z$obs,z$pred))
  ggplot(z,aes(obs,pred)) +
    geom_abline(slope=1,intercept=0,colour='#202020',linewidth=.4) +
    geom_point(aes(colour=local_point_count),shape=16,size=1.15) +
    scale_colour_viridis_c(option='D',limits=density_limits,name='# of data') +
    coord_fixed(xlim=lim,ylim=lim) +
    labs(x='Observed BC (µg/m³)',y='Mean OOF prediction (µg/m³)',title=paste(yr,'| MCRK')) +
    guides(colour=guide_colourbar(reverse=TRUE,barheight=unit(36,'mm'),barwidth=unit(2.5,'mm')))
})
p8 <- wrap_plots(scatters,nrow=1,guides='collect') + panel_tags()
save_fig(p8,'Fig08',height=70)

# Figure 9a: benchmark scores use exactly the same repeat-level estimator as Table 2.
families <- c('RF','Cubist','XGB','SVM','GBM','KNN','ENR','SVRK')
model_labels <- c(RF='RF',Cubist='Cubist',XGB='XGBoost',SVM='RBF-SVM',
                  GBM='GBM',KNN='KNN',ENR='Elastic net',SVRK='MCRK')
d <- copy(scores[model%in%paste0(families,'_XBS')])
d[,family:=factor(sub('_XBS$','',model),levels=rev(families))]
obs_sd <- unique(o[model=='RF_XB',.(year,GRID_ID,obs)])[,.(bc_sd=sd(obs)),by=year]
d <- merge(d,obs_sd,by='year')
d[,nRMSE:=RMSE/bc_sd]
pal <- c('#F0FDFA','#67E8F9','#2563EB','#312E81')
limits <- range(d$nRMSE)
pa <- ggplot(d,aes(factor(year),family,fill=nRMSE)) +
  geom_tile(colour='white',linewidth=.55) +
  geom_text(aes(label=sprintf('%.2f (%.2f)',RMSE,R2),
                colour=contrast_text(nRMSE,pal,limits)),size=2.3) +
  scale_colour_identity() + scale_fill_gradientn(colours=pal,limits=limits,name='RMSE / observed SD') +
  scale_y_discrete(labels=model_labels) +
  labs(x=NULL,y=NULL,title='MCRK versus benchmark models',tag='(a)') +
  theme(axis.line=element_blank(),axis.ticks=element_blank(),legend.position='right',
        plot.title=element_text(size=8),plot.title.position='plot') +
  guides(fill=guide_colourbar(barheight=unit(32,'mm'),barwidth=unit(2,'mm'),
    title.position='right',theme=theme(legend.title=element_text(angle=270,size=6.5))))

# Figure 9b: paired 95% intervals are the archived spatial-block bootstrap
# results conditional on the fitted OOF predictions. Verify their point values
# against the primary OOF data before plotting them; negative gains are retained.
gains <- fread(file.path(DATA,'fig09_paired_sdo_gains.csv'))
for (yr in YEARS) {
  a <- scores[year==yr & model=='SVRK_XB',RMSE]
  b <- scores[year==yr & model=='SVRK_XBS',RMSE]
  stopifnot(abs(gains[year==yr,gain_pct]-100*(a-b)/a)<1e-9)
}
pb <- ggplot(gains,aes(gain_pct,factor(year),colour=factor(year),shape=factor(year))) +
  geom_vline(xintercept=0,linetype='dashed',colour='#AAB8BE',linewidth=.35) +
  geom_errorbar(aes(xmin=gain_lower,xmax=gain_upper),orientation='y',width=.12,linewidth=.4) +
  geom_point(size=1.7) + year_scale() +
  labs(x='RMSE reduction (%)',y='Campaign',title='Incremental predictive value of SDO',tag='(b)') +
  theme(legend.position='none',plot.title=element_text(size=8),plot.title.position='plot')

# Figure 9c: four prespecified component contrasts on matched validation folds.
# These saved comparisons retain their original base/target models, full-precision
# RMSEs and conditional bootstrap intervals; labels only adopt manuscript names.
z <- fread(file.path(DATA,'fig09_controlled_additions.csv'))
stopifnot(max(abs(z$gain_pct-100*(z$base_RMSE-z$target_RMSE)/z$base_RMSE))<1e-9)
contrast_labels <- c(B_with_space='Ordinary neighbourhood: X → XB',
  ILF_positive='Industrial SDO+: XB → XB+I+',
  TRL_positive='Road SDO+: XB → XB+R+',
  Residual_XBS='Residual kriging: SVM → MCRK')
z[,label:=factor(contrast,levels=rev(names(contrast_labels)),labels=rev(unname(contrast_labels)))]
pc <- ggplot(z,aes(gain_pct,label,colour=factor(year),shape=factor(year))) +
  geom_vline(xintercept=0,linetype='dashed',colour='#94A3B8',linewidth=.35) +
  geom_errorbar(aes(xmin=gain_lower,xmax=gain_upper),orientation='y',width=.17,linewidth=.4) +
  geom_point(size=1.6) + facet_wrap(~year,nrow=1) + year_scale() +
  labs(x='RMSE reduction (%) relative to the labelled comparator',y=NULL,
       title='Matched component comparisons',tag='(c)') +
  theme(legend.position='none',axis.text.y=element_text(size=6.2),plot.title.position='plot')
# Independent upper panels keep their axes from inheriting the long row labels
# of panel c, preserving enough room for both upper titles and legends.
top9 <- (wrap_elements(full=pa)|wrap_elements(full=pb)) + plot_layout(widths=c(1.15,1))
p9 <- top9/pc + plot_layout(heights=c(1.1,.85))
save_fig(p9,'Fig09',height=128)
