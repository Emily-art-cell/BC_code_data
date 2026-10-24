# Figure 10: full-domain and supported-area maps of the SAME MCRK predictions.
if (!exists('ROOT', inherits=TRUE)) {
  arg <- grep('^--file=',commandArgs(FALSE),value=TRUE)
  script <- if(length(arg)) sub('^--file=','',arg[1]) else sys.frame(1)$ofile
  if (!file.exists(script)) script <- gsub('~+~',' ',script,fixed=TRUE)
  source(file.path(dirname(normalizePath(script)), '00_setup.R'))
}
m <- fread(file.path(DATA,'fig10_predictions.csv'))
scales_year <- fread(file.path(DATA,'fig10_colour_scales.csv'))
stopifnot(!anyDuplicated(m[,.(year,GRID_ID)]),all(is.finite(m$pred)),
          all(m[, .N,by=year]$N==28015L), !anyNA(m$supported))

# Original grid centres are projected metres (EPSG:32651). The display uses km.
# Keep the archived 500 m cells intact: no interpolation or image smoothing.
boundary <- st_read(file.path(DATA,'shanghai_boundary.gpkg'),layer='boundary',quiet=TRUE)
boundary <- st_transform(boundary,32651)
boundary_km <- boundary
st_geometry(boundary_km) <- st_geometry(boundary_km)/1000
st_crs(boundary_km) <- NA
bb <- st_bbox(boundary_km)
xlim <- unname(c(bb['xmin'],bb['xmax'])+c(-2,2))
ylim <- unname(c(bb['ymin'],bb['ymax'])+c(-2,2))
frame <- st_as_sfc(st_bbox(c(xmin=xlim[1],xmax=xlim[2],ymin=ylim[1],ymax=ylim[2]),crs=NA))
outside <- st_difference(frame,st_union(boundary_km))

map_panel <- function(yr,supported_only=FALSE,tag) {
  z <- copy(m[year==yr])
  # NA is used only to mask unsupported cells; it never replaces a prediction by 0.
  z[,display:=if(supported_only) fifelse(supported,pred,NA_real_) else pred]
  sc <- scales_year[year==yr]
  ggplot() +
    geom_sf(data=boundary_km,fill=MISSING_COLOR,colour=NA) +
    geom_raster(data=z,aes(x=x/1000,y=y/1000,fill=display),interpolate=FALSE) +
    geom_sf(data=outside,fill='white',colour=NA) +
    geom_sf(data=boundary_km,fill=NA,colour='#A3ADB2',linewidth=.12) +
    coord_sf(xlim=xlim,ylim=ylim,expand=FALSE,datum=NA) +
    # Independent campaign scales, shared within each upper/lower map pair.
    scale_fill_gradientn(colours=BC_PALETTE,limits=c(sc$lower,sc$upper),
      breaks=c(sc$lower,sc$middle,sc$upper),labels=label_number(accuracy=.1),
      name='BC (µg/m³)',na.value=MISSING_COLOR,oob=scales::squish) +
    labs(title=if(!supported_only)as.character(yr) else NULL,tag=tag) +
    guides(fill=guide_colourbar(barheight=unit(2.5,'mm'),barwidth=unit(35,'mm'),title.position='top')) +
    theme_void(base_family=FONT) +
    theme(plot.title=element_text(size=10,face='bold',hjust=.5),
      plot.tag=element_text(size=9,face='bold'),plot.tag.position=c(.02,.95),
      legend.position=if(supported_only)'bottom' else 'none',
      legend.title=element_text(size=8,hjust=.5),legend.text=element_text(size=7),
      plot.margin=margin(1,2,1,1))
}
maps_top <- lapply(seq_along(YEARS),function(i)map_panel(YEARS[i],FALSE,paste0('(',letters[i],')')))
maps_bottom <- lapply(seq_along(YEARS),function(i)map_panel(YEARS[i],TRUE,paste0('(',letters[i+3],')')))
row_label <- function(label) wrap_elements(full=grid::textGrob(label,rot=90,gp=gpar(fontfamily=FONT,fontsize=9)))
top <- row_label('Full-domain prediction') + wrap_plots(maps_top,nrow=1) + plot_layout(widths=c(.055,1))
bottom <- row_label('Supported-area prediction') + wrap_plots(maps_bottom,nrow=1) + plot_layout(widths=c(.055,1))
p <- top/bottom + plot_layout(heights=c(1,1.12))
save_fig(p,'Fig10',height=170)
