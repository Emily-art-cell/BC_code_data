# Data and R code for roadside black carbon analysis in Shanghai

## Purpose

This repository accompanies our study, *Multiscale Environmental Associations and Spatial Prediction of Roadside Black Carbon in Shanghai*. We provide the observations, out-of-fold predictions, analysis results and R scripts used to reproduce Figures 5-10 and Tables 1-2.

The scripts reproduce the figures and tables from the included data. They recalculate descriptive statistics, prediction scores, stratum-level BC ratios, example SDO tail sums and plotting quantities. Optimized OPGD results, bootstrap intervals, gridded SDO features and final spatial predictions are stored as analysis outputs. The reproduction workflow uses these results directly rather than repeating the complete model-fitting and bootstrap analyses.

## Repository contents

| File or directory | Description |
|---|---|
| `data/` | Observed BC and environmental predictors, out-of-fold predictions, figure source data and the Shanghai boundary |
| `figs/` | Figures 5-10 in PDF and PNG format |
| `tables/` | Tables 1-2 in CSV, PDF and PNG format |
| `00_setup.R` | Shared paths, package checks, plotting styles and export functions |
| `02_plot_fig05.R` | Campaign BC distributions and observed spatial autocorrelation |
| `03_plot_fig06.R` | Local environmental associations and ordered-stratum BC contrasts |
| `04_plot_fig07.R` | SDO construction example, multiscale associations and signed-tail maps |
| `05_plot_fig08_09.R` | Out-of-fold prediction scatterplots, model performance and component comparisons |
| `06_plot_fig10.R` | Full-domain and support-restricted BC prediction maps |
| `07_export_tables.R` | Descriptive statistics and spatially validated model performance tables |
| `install_dependencies.R` | Installation of missing R packages |
| `run_all.R` | Complete figure and table reproduction workflow |
| `data_manifest.csv` | Input file descriptions, dimensions, source records, figure/table mapping and MD5 checksums |

All input files required by the scripts are included in `data/`. Source paths recorded in `data_manifest.csv` document the study's analysis workflow; the scripts do not access those paths.

## Software requirements

We tested the workflow with R 4.4.2 and the following packages:

| Package | Tested version |
|---|---|
| data.table | 1.16.4 |
| ggplot2 | 4.0.0 |
| patchwork | 1.3.1 |
| sf | 1.0-19 |
| scales | 1.4.0 |
| ragg | 1.5.0 |

The scripts require `ggplot2 >= 3.5.2` and `patchwork >= 1.3.0`. R's built-in `grid`, `stats` and `grDevices` packages are also used.

On Linux, installing `sf` and `ragg` from source may require GDAL, GEOS, PROJ and font/image development libraries. Figure PDF export uses native Quartz on macOS and Cairo where available on other systems, with a standard PDF-device fallback. Fonts may vary slightly across operating systems.

## Running the code

Open a terminal in the repository directory and run:

```sh
Rscript install_dependencies.R
Rscript run_all.R
```

The first command installs any missing packages. If all dependencies are already available, run only the second command. Internet access is required for package installation, but not for figure and table reproduction.

The workflow also runs from another working directory:

```sh
Rscript "/path/to/Figshare/run_all.R"
```

Keep quotation marks around paths containing spaces. In R or RStudio, use:

```r
source("/path/to/Figshare/run_all.R", encoding = "UTF-8")
```

Individual output scripts can be run separately, for example:

```sh
Rscript 04_plot_fig07.R
Rscript 07_export_tables.R
```

The scripts locate the repository from their own file paths. Re-running a script replaces its corresponding outputs in `figs/` or `tables/`.

## Input data

CSV files use UTF-8 encoding, a header row and decimal-point notation. `NA` denotes an unavailable value. Coordinates `x` and `y` are 500 m grid-cell centres in metres, using UTM zone 51N (EPSG:32651). BC concentrations are expressed in micrograms per cubic metre.

| Input file | Records | Contents and use |
|---|---:|---|
| `observed_bc.csv` | 675 | `GRID_ID`, campaign year, coordinates, observed cell-mean `BC` and all 12 local environmental predictors; used in Figure 5, Figure 6 and Table 1 |
| `observed_moran.csv` | 3 | Campaign-specific observed-response Moran's I and two-sided permutation p values; Figure 5b |
| `local_opgd.csv` | 36 | Optimized q, bootstrap limits, Spearman rho, partition settings and support information for 12 predictors in three campaigns; Figures 6a-b |
| `local_opgd_strata.csv` | 56 | Ordered-stratum identifiers, sample sizes, predictor ranges and means, and mean BC for POPD, DTS, TRL and NDVI; Figure 6c |
| `fig07_donors.csv` | 384 | Donor-cell values and neighbourhood means and sample standard deviations for TRL and NDVI; Figure 7a |
| `fig07_scale_summary.csv` | 60 | Matched median q and eligible-variable counts by campaign, radius and feature family; Figure 7b |
| `fig07_sdo_maps.csv` | 56,030 | Positive and negative SDO tail sums for TRL and NDVI in 2026 at a 4 km radius; Figures 7c-f |
| `oof_predictions.csv` | 33,750 | Observed and held-out predicted BC, model identifiers, repeat and fold identifiers, grid IDs and coordinates for ten model/input combinations; Figures 8-9 and Table 2 |
| `fig09_paired_sdo_gains.csv` | 3 | Within-model XB-to-XBS RMSE changes and paired bootstrap intervals; Figure 9b |
| `fig09_controlled_additions.csv` | 12 | Matched component comparisons, base/target model identifiers, RMSE values and paired bootstrap intervals; Figure 9c |
| `fig10_predictions.csv` | 84,045 | Full-domain predictions, support flags, boundary-overlap areas and geographic/environmental/input-coverage diagnostics; Figure 10 |
| `fig10_colour_scales.csv` | 3 | Campaign-specific lower, middle and upper colour-scale values; Figure 10 |
| `shanghai_boundary.gpkg` | 1 feature | Municipal boundary in EPSG:32651, stored in layer `boundary`; Figures 7 and 10 |

The observation data contain 239 cells from 2016, 225 from 2022 and 211 from 2026. A total of 188 locations were observed in all three campaigns. Each campaign has predictions for the same 28,015 grid cells.

### Environmental predictors

| Abbreviation | Variable |
|---|---|
| TRL | Total road length |
| MLL | Motorway-link road length |
| RRL | Residential road length |
| DTS | Distance to the nearest station |
| ILF | Industrial land-use fraction |
| RLF | Residential land-use fraction |
| BAF | Built-up area fraction |
| NDVI | Normalized Difference Vegetation Index |
| WBF | Water-body fraction |
| NTL | Nighttime light intensity |
| POI | Point-of-interest count |
| POPD | Population density |

Predictor values retain the study's analysis-input scales. Environmental product sources and measurement definitions are described in the article.

### Model identifiers

`X` denotes the 12 local environmental predictors. `B` denotes ordinary neighbourhood information, including means, standard deviations and coverage indicators. `S` denotes signed SDO features. All five cumulative radii, 1-5 km, enter the contextual prediction models.

The stored identifier `SVRK_XBS` corresponds to MCRK in the article. `SVRK_XB` denotes the same SVM-plus-residual-kriging model family without SDO inputs. `SVM_XBS` is the RBF-SVM benchmark. `SVM12_XBS` in the component comparisons denotes the matched 12-setting SVM control. We retain these identifiers to distinguish the fitted procedures and their input sets.

## Figure and table outputs

| Output | Panel organization |
|---|---|
| `figs/Fig05.pdf`, `figs/Fig05.png` | (a) Campaign BC distributions; (b) observed Moran's I |
| `figs/Fig06.pdf`, `figs/Fig06.png` | (a) Optimized OPGD q with intervals; (b) Spearman correlations; (c) ordered-stratum contrasts for POPD, DTS, TRL and NDVI |
| `figs/Fig07.pdf`, `figs/Fig07.png` | (a) TRL and NDVI donor histograms; (b) matched multiscale q; (c-f) TRL S+, TRL S-, NDVI S+ and NDVI S- maps |
| `figs/Fig08.pdf`, `figs/Fig08.png` | (a-c) Observed versus mean out-of-fold predictions for 2016, 2022 and 2026 |
| `figs/Fig09.pdf`, `figs/Fig09.png` | (a) Model performance; (b) incremental SDO gain; (c) matched component comparisons |
| `figs/Fig10.pdf`, `figs/Fig10.png` | (a-c) Full-domain predictions; (d-f) the same predictions restricted to supported areas |
| `tables/Table_01.csv`, `.pdf`, `.png` | Campaign mean, median and between-cell standard deviation of observed BC |
| `tables/Table_02.csv`, `.pdf`, `.png` | Spatially validated R2 and RMSE, relative changes against RF (X+B), and best-score indicators |

PNGs are exported at 600 dpi. PDFs retain vector text and graphical elements where applicable. CSV tables preserve full-precision values; rounding is applied only when rendering tables.

## Calculation notes

### Spatial validation and performance scores

We used five repeats of five-fold spatial cross-validation with 5 km blocks and 1 km exclusion buffers. Scores are calculated over all held-out observations within each complete repeat:

```r
R2 <- 1 - sum((obs - pred)^2) / sum((obs - mean(obs))^2)
RMSE <- sqrt(mean((obs - pred)^2))
```

Table 2 and Figure 9a report the arithmetic mean of the five repeat-level scores. Figure 8 displays predictions averaged across repeats for each observed cell. Its point cloud therefore represents a different aggregation from the reported mean-repeat performance scores.

Relative R2 change is `100 * (target_R2 - reference_R2) / reference_R2`. RMSE reduction is `100 * (reference_RMSE - target_RMSE) / reference_RMSE`. Both use unrounded values. Table 2 uses RF (X+B) as the reference, and its best-score indicators include that reference model.

### Spatial associations and SDO features

Observed Moran's I uses directed, row-standardized eight-nearest-neighbour weights. Stored p values use 999 permutations with seed `20260919 + year`.

The OPGD intervals in Figure 6 use 199 resamples of 5 km spatial blocks, with partition optimization repeated within each resample and seed `20260929 + year`. Candidate partitions use equal, quantile or natural breaks with three, four or five strata and a minimum stratum size of ten. In Figure 6c, each stratum's mean BC is divided by the median BC across all observed cells in the same campaign.

Figure 7a uses 192 donors per variable within a strict `0 < distance < 4 km` neighbourhood around demonstration cell 16112 in 2026. The script recalculates:

```r
z <- (value - local_mean) / local_sd
S_pos <- sum(z[z > 2])
S_neg <- sum(z[z < -2])
```

Tail sums retain their signs. A valid neighbourhood with an empty tail has a sum of zero; unavailable context remains `NA`. Figure 7b compares the same eligible base variables across neighbourhood means, standard deviations and both signed tails at each campaign and radius. `n_valid = 0` is displayed as not estimable (NE).

### Prediction diagnostics and maps

Figure 8 colours show the number of points within radius 0.35 in observed/SD versus mean-prediction/SD space, including the point itself.

Figure 9 uses stored paired 95% spatial-block percentile intervals from 999 bootstrap draws, conditional on the fitted out-of-fold predictions. Panel b compares XB with XBS within the same spatial model family. Panel c retains the specified base and target models for each component comparison.

Figure 10 applies the stored support mask to the same predictions shown in the full-domain maps. Each campaign has its own colour scale, shared between its upper and lower maps. Grey cells in the support-restricted maps indicate failed support criteria. Maps preserve the 500 m grid and are clipped to the municipal boundary without interpolation or image smoothing.

## Reproduction checks

We tested the complete workflow from a separate directory containing spaces, with no existing outputs, while using a different working directory. All six figures and both tables were generated successfully. We checked table values against the article, confirmed that all PDFs contain one page and all PNGs record 600 dpi, and verified observation alignment, the 36 Spearman correlations, displayed-stratum sample counts and supported-area percentages against the included data.
