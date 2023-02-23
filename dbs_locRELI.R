# set working directory (works in RStudio only)
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

# list packages to be used
pkgs <- c("dplyr", "tidyverse", "R.matlab" ) # for data wrangling and reading MatLab files

# load or install each of the packages as needed
for ( i in pkgs ) {
  if ( i %in% rownames( installed.packages() ) == F ) install.packages(i) # install if it ain't installed yet
  if ( i %in% names( sessionInfo()$otherPkgs ) == F ) library( i , character.only = T ) # load if it ain't loaded yet
}

# write down some important parameters
d.dir <- "data/mri" # Where the MRI data is?

# extract IDs of subjects to compare
#id <- list.files( d.dir, recursive = F )
id <- read.csv( "data/tabs/subjects_to_compare.csv" ) %>% t() %>% as.character()


# ---- extract VATs ----

# list paths to VATs for each patient
VAT.path <- lapply( id, function(i)
  
  # first list all paths to all files for each patient
  list.files( paste( d.dir, i, sep = "/" ) , recursive = T ) %>% as.data.frame() %>%
    # keep only paths to VATs in MNI space, niix format, drop the files with gaussian efield
    filter( grepl("stimulations", . ) ) %>%
    t() %>% as.character() # do some housekeeping
  
) %>% `names<-`(id)

# list summary of all VATs that are present
VAT.sum <- data.frame( id = id ) %>%
  # add a dummy variable indicating whether there's VAT for each patient (right/left separately)
  mutate( vat.right = sapply(id, function(i) any( grepl( "right", VAT.path[[i]] ) ) ) %>% as.numeric(),
          vat.left = sapply(id, function(i) any( grepl( "left", VAT.path[[i]] ) ) ) %>% as.numeric() )

# extract all VATs and put them in their own folders
# first prepare a folder for VATs
if( !dir.exists("data/vat") ) dir.create( "data/vat" )

# next add VATs of each patient
for ( i in names(VAT.path) ) {
  
  # prepare patient folder
  if( !dir.exists( paste0( "data/vat/", i ) ) ) dir.create( paste0( "data/vat/", i ) )
  
  # check whether there's any VAT for the patient "i"
  if ( length( VAT.path[[i]] != 0 ) ) {
    
    # loop through spaces (MNI vs native)
    for ( j in c("MNI","native") ) {
      
      # prepare patient space-specific folder
      if( !dir.exists( paste( "data/vat", i, j, sep = "/" ) ) ) dir.create( paste( "data/vat", i, j, sep = "/" ) )
      
      # loop through all files of each patient
      for ( k in 1:length( VAT.path[[i]] ) ) {
        
        # continue only if "k" is in the space "j"
        if ( grepl( j, VAT.path[[i]][[k]] ) )
        
        # copy VAT from the mri to vat folder
        file.copy( from = paste( d.dir, i, VAT.path[[i]][k], sep = "/" ),
                   to = paste( "data/vat", i, j, sub( ".*/", "", VAT.path[[i]][k] ), sep = "/" ) )
        
      }
    }
  }
}


# ---- extract electrode trajectories ----

# prepare a folder for trajectories
if( !dir.exists("data/traj") ) dir.create( "data/traj" )

# loop through patients to copy their raw ea_reconstruction files
for ( i in id ) {
  # prepare a folder for patient "i"
  if( !dir.exists( paste0("data/traj/", i) ) ) dir.create( paste0("data/traj/", i) )
  # copy the ea_reconstruction file
  file.copy( from = paste(d.dir, i, "ea_reconstruction.mat", sep = "/" ),
             to = paste0("data/traj/", i, "/ea_reconstruction.mat") )
}

# next read the MatLab files
d.traj <- lapply( id, function(i) readMat( paste( d.dir, i, "ea_reconstruction.mat", sep = "/") )$reco ) %>% `names<-`(id)

# loop through the files to get them into a nice format
for ( i in names(d.traj) ) {
  
  # level 1
  d.traj[[i]] <- d.traj[[i]][ , , 1] # explicitly name each facet of level 1
  
  # level 2
  # electrode model - re-format to a data.frame and name rows by hemisphere
  d.traj[[i]]$props <- with( d.traj[[i]], rbind.data.frame( props[ , , 1], props[ , , 2] ) ) %>%  `rownames<-`( c("right","left") )
  
  # get rid of the "electrode" sub-list, dunno what it is but I believe it contains info for visualisation
  d.traj[[i]]$electrode <- NULL
  
  # loop through lead coordinates in different space
  for ( j in c("native","scrf","mni") ) {
    
    # if any of these is missing, print a message and march on
    if ( !exists( j, where = d.traj[[i]] ) ) {
      print( paste0( i, ", ", j, " missing!" ) )
      next
    }
    
    # name the sub-lists in each space accordingly
    d.traj[[i]][[j]] <- d.traj[[i]][[j]][ , , 1]
    
    # level 3
    # label contact coordinates and lead trajectories
    for ( k in c("coords.mm","trajectory") ) d.traj[[i]][[j]][[k]] <- list( right = d.traj[[i]][[j]][[k]][[1]][[1]] %>% `colnames<-`( c("x","y","z") ),
                                                                            left = d.traj[[i]][[j]][[k]][[2]][[1]]  %>% `colnames<-`( c("x","y","z") ) )
    
    # next deal with markers
    d.traj[[i]][[j]]$markers <- list( right = do.call( rbind.data.frame , d.traj[[i]][[j]]$markers[ , , 1] ) %>% `colnames<-`( c("x","y","z") ),
                                      left = do.call( rbind.data.frame , d.traj[[i]][[j]]$markers[ , , 2] ) %>% `colnames<-`( c("x","y","z") ) )
    
  }
}


# ---- prepare a data frame with contacts' coordinates ----

# prepare a list to be filled-in with the coordinates
df <- list()

# loop through patients
for ( i in names(d.traj) ) {
  # prepare a temporary sub-list for each patient
  df[[i]] <- list()
  
  # loop through spaces
  for ( j in c("native","scrf","mni") ) {
    
    # if any of these is missing, print a message and march on
    if ( !exists( j, where = d.traj[[i]] ) ) {
      print( paste0( i, ", ", j, " missing!" ) )
      next
    }
    
    # in each space create a data.frame with parameters
    df[[i]][[j]] <- do.call( rbind.data.frame, d.traj[[i]][[j]]$coords.mm ) %>%
      add_column( contact = sub( ".*\\.", "", rownames(.) ), .before = 1 ) %>% # add contact number (smaller = more ventral)
      add_column( hemisphere = sub( "\\..*", "", rownames(.) ), .before = 1 ) %>% # add hemisphere
      add_column( elmodel = NA, .after = "hemisphere" ) %>% # prepare a column for electrode model
      add_column( space = j , .before = 1 ) # add space
  }
  
  # merge all data frames for each patient
  df[[i]] <- do.call( rbind.data.frame, df[[i]] ) %>% add_column( id = i, .before = 1 )
  
}

# collapse to a single long table and tidy the rownames
df <- do.call( rbind.data.frame, df ) %>% `rownames<-`( 1:nrow(.) )

# finishing touches - add the elctrode model
for ( i in 1:nrow(df) ) df$elmodel[i] <- with( df, d.traj[[id[i]]]$props[ hemisphere[i], "elmodel" ] )

# save as csv
write.table( df, file = "data/traj/trajectories.csv", sep = ",", row.names = F )


# ---- zip the files ----

# conduct zipping for all including patients
lapply( id, function(i)
  # zip it
  zip( zipfile = paste0( d.dir, "/", i, ".zip" ), # output zip file
       files = paste( d.dir, i, list.files( paste0(d.dir,"/",i) ), sep = "/" ) ) # input raw files
  )


# ---- session info ----

# write the sessionInfo() into a .txt file
capture.output( sessionInfo(), file = "dbs_locRELI_session_info.txt" )
