# In the latest run (2023-01-21) I ran in R version 4.2.0 (2022-04-22), on aarch64-apple-darwin20 (64-bit)
# platform under macOS 13.1. the following versions of packages employed: dplyr_1.0.9 and tidyverse_1.3.1,

# set working directory (works in RStudio only)
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

# list packages to be used
pkgs <- c("dplyr", "tidyverse" ) # for data wrangling

# load or install each of the packages as needed
for ( i in pkgs ) {
  if ( i %in% rownames( installed.packages() ) == F ) install.packages(i) # install if it ain't installed yet
  if ( i %in% names( sessionInfo()$otherPkgs ) == F ) library( i , character.only = T ) # load if it ain't loaded yet
}

# write down some important parameters
d.dir <- "data/mri" # Where the MRI data is?

# extract IDs
id <- list.files( d.dir, recursive = F )
