# set working directory (works in RStudio only)
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

# list packages to be used
pkgs <- c("dplyr", # for object manipulations
          "tidyverse", # for more object manipulations
          "R.utils" # open .gz files
)

# load or install each of the packages as needed
for ( i in pkgs ) {
  if ( i %in% rownames( installed.packages() ) == F ) install.packages(i) # install if it ain't installed yet
  if ( i %in% names( sessionInfo()$otherPkgs ) == F ) library( i , character.only = T ) # load if it ain't loaded yet
}

# extract all t1w files' names
fls <- list.files( "data", recursive = T ) %>% as.data.frame() %>% slice( which( grepl("anat_t1",.) ) )

# (manual step) keep only images with no defacing yet
fls <- fls[ which(grepl("SUBJECT_078",fls$.)):nrow(fls), ]
fls <- fls[ -which( grepl("SUBJECT_080",fls) ) ] # SUBJECT_080 is already defaced

# rename the original file
for ( i in fls ) file.rename( from = paste0("data/",i), to = paste0( "data/",gsub(".nii","_orig.nii",i) ) )
  
# write a .command script for fsl_deface
writeLines(
  paste(
    paste( "fsl_deface", # call fsl_deface function
           paste0( "~/Desktop/mercenaries/dbs_113climabi/data/", gsub(".nii","_orig.nii",fls) ), # original
           paste0( "~/Desktop/mercenaries/dbs_113climabi/data/", fls ), # defaced
           sep = " " ),
    collapse = "\n"
  ), con = "conduct_fsl_deface.command"
)

# give the script permission
system( "chmod u+x ~/Desktop/mercenaries/dbs_113climabi/conduct_fsl_deface.command" )

# now launch the "conduct_fsl_deface.command" file by double-clicking on it
# the code will add a new defacedd "anat_t1.nii.gz" file to each subject's directory

# unzip the defaced images
for ( i in fls ) {
  gunzip( paste0( getwd(), "/data/", i, ".gz") ) # unzipping
  # remove the originaů
  # make sure you have a reserve
  file.remove( paste0( "~/Desktop/mercenaries/dbs_113climabi/data/", gsub(".nii","_orig.nii",fls) ) )
}


# next check that the defacing worked well and continue to Lead-DBS