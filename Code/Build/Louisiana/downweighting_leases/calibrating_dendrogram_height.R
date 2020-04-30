# ---------------------------------------------------------------------------
# Name:        calibrating_dendrogram_height.R
# Description:
#
# This file has the ability to cycle through many different weight
# vectors, calibration dates, and dendrogram height quantiles to produce many
# different 'clustered' datasets at the end of the day. It takes in distance
# matrices that are originally created in cleaning_duplicate_leases_for_stringmatch.R
# and string_dissim.py for various weight vectors and uses those to perform
# agglomerative hierarchical clustering
#
# The main workflow of this file is it takes in a full dataset and has a list of
# dates by which to calibrate by (generally dates that are in heavily leased
# portions of our sample). To calibrate at those dates, we cluster all relevant
# observations in the sample present at a particular date and then we find the
# dendrogram height at each section for which the fraction of area in a section
# leased after downweighting based on that clustering is less than 1. We then
# store the quantiles of these heights (e.g. the 95th percentile heighest
# dendrogram height) and we perform the rest of the clustering using these
# pre-calibrated heights
#
# Finally, we go through the rest of the dataset and for each quarter in our
# data, we cluster all leases on a section-level and cut the dendrogram at
# the height we have found by calibration. We output these quarter-level datasets
# to an output folder specific to all the parameters we have tweaked for
# that dataset. The output for this piece of code is quarter-level clustered
# data.
# ---------------------------------------------------------------------------

# activate the `readstata13` library to read in stata files from stata 13+
library(readstata13)
library(cluster)
library(purrr)
library(dendextend)
library(plyr)
library(dplyr)
library(foreign)
library(magrittr)
library(feather)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while ((basename(root) != "HBP")&(basename(root) != "hbp")) {
  root <- dirname(root)
}
source(file.path(root, "data.R"))
calibration_date <- "2010/01/01"

df_path <- paste(featherdir,"/louisiana_leases_DI_csvs_for_clustering.feather", sep="")
output_path <- paste(dropbox,"/IntermediateData/Louisiana/Leases/Clustering/", sep="")
df <- read_feather(df_path)
threshold_out <- paste(repo,"/Paper/Figures/single_numbers_tex/cluster_threshold_90.tex", sep="")

feather_path <- paste(featherdir, "/Feathered_stringmatched_sectionlevel_dfs/", sep="")
# mutate the dataframe into having a variable titled duplicate_group_id
# this variable will be the group variable that the clustering spits out
full_df <- dplyr::tbl_df(df)
full_df <- full_df %>%
  dplyr::mutate(duplicate_group_id = 0)

# this is originally set in cleaning_duplicate_leases_for_stringmatch.R
local_inf_file <- paste(dropbox,"/IntermediateData/Louisiana/Leases/local_inf.csv", sep="")
local_inf <- read.csv(local_inf_file)[1,1]

cluster_df <- function(df, feather_path) {
  section <- df$section_id[1]
  # get an nxn length dataset that is a pairwise matching
  # between all observations in the section-level dataframe
  section_df <- dplyr::tbl_df(df)
  section_df$k <- 1
  section_joined_df <- section_df %>%
    inner_join(section_df, by='k') %>%
    dplyr::select(-k)
  # extract the distance metric
  df_with_scores <- read_feather(paste(feather_path, "feathered_df_", as.character(section), "_stringmatched.feather", sep=""))
  df_with_scores <- df_with_scores %>% dplyr::select(-startdate.x, -startdate.y, -cluster_exprdate.x, -cluster_exprdate.y)
  # merge them in with the section-level nxn dataframe
  section_joined_df_with_dist <- section_joined_df %>%
    merge(df_with_scores, by.x = c("unique_id.x", "unique_id.y"), by.y = c("unique_id.x", "unique_id.y"), all.x = TRUE) %>%
    transform(dist = ifelse(is.na(dist), local_inf, dist)) %>%
    transform(dist = ifelse(group_trsa.x!=group_trsa.y, local_inf, dist))
  # extract the distance variables
  dist_row <- section_joined_df_with_dist$dist
  # make an nxn distance matrix
  new_dimension <- sqrt(length(dist_row))
  dist_mat <- matrix(dist_row, nrow = new_dimension, byrow = TRUE)
  dissim <- as.dist(dist_mat)
  
  # cluster!
  hclustobj <- hclust(dissim, method = "average")
  hclustobj$labels <- section_df$unique_id
  return(hclustobj)
}

# given a list of clusters and the original dataframe, find the dendrogram height that 
# gets an area leased that is just under the total area of the section leased.
optimal_cutting_height <- function(orig_df, hclust_obj) {
  labels <- hclust_obj[["labels"]]
  # extract_min_k is a function that will ensure we don't cluster beyond the group_trsa definitions
  min_k <- extract_min_k(orig_df, labels)
  if (min_k==0) {
    min_k <-1
  }
  max_k <- length(labels)
  # create dendrogram object
  hclust_obj.dend <- as.dendrogram(hclust_obj)
  optimal_k <- min_k
  # cycle through each possible 'k' clusters and find the fraction of area leased
  # find the 'k' at which the fraction leased is just under 1
  for (k in min_k:max_k) {
    fraction_area_leased <- cutree(tree=hclust_obj, k=k) %>% extract_area(orig_df, k)
    if (fraction_area_leased<=1 & k>optimal_k) {
      optimal_k <- k
    } else if (fraction_area_leased > 1) {
      break
    }
  }
  # using this 'k' found above, we can find the dendrogram height
  # at which the fraction of area leased is just under 1 when we cut at that height
  if (optimal_k==max_k) {
    optimal_h <- 0
  } else {
    optimal_h <- get_branches_heights(hclust_obj.dend)[max_k-optimal_k]
  }
  # this is eventually the return value
  return(optimal_h)
}

# functional to extract the minimum k (the number of subgroups in the data)
extract_min_k <- function(df, list_of_labels) {
  new_df <- subset(df, unique_id %in% list_of_labels)
  min_k <- length(unique(new_df$group_trsa))
  return(min_k)
}

# this returns fraction of area leased, helper function used in optimal_cutting_height
extract_area <- function(groups, df, k) {
  area <- 0
  groupdf <- tibble(groups,names(groups)) %>% dplyr::rename(labels = `names(groups)`)
  groupdf[["labels"]] <- as.numeric(groupdf[["labels"]])
  # indexing to just acquire the first lease and drop all its 'duplicates'
  
  groupdf <- groupdf[!duplicated(groupdf[["groups"]]),]
  label_list <- groupdf %>% pull(labels)
  newdf <- df %>% filter(unique_id %in% label_list)
  areasum <- sum(newdf[["area_revised"]])
  total_area <- newdf[["total_section_area"]][1]
  return(areasum/total_area)
}

# function that takes in a calibration date and spits out
# the dendrogram heights at which to cluster the rest of the dataset
calibrate_df <- function(full_df, feather_path, date_to_calibrate) {
  calibrate_time_slice <- full_df %>%
    filter(startdate <= date_to_calibrate, cluster_exprdate > date_to_calibrate)
  calibrate_time_slice_sections <- split(calibrate_time_slice, calibrate_time_slice$section_id)
  one_lease_sections <- calibrate_time_slice_sections[lapply(calibrate_time_slice_sections, nrow) == 1]
  # we are not including one-lease sections in this so the quantile heights we use are actually
  # a slight overestimate of actual quantile they measure since there are a few one-lease sections that can
  # never be clustered in the first place
  multiple_lease_sections <- calibrate_time_slice_sections[lapply(calibrate_time_slice_sections, nrow) !=1]
  hclust_list <- lapply (multiple_lease_sections, cluster_df, feather_path = feather_path)
  height_list <- c()
  for (i in 1:length(hclust_list)) {
    height <- optimal_cutting_height(calibrate_time_slice, hclust_list[[i]])
    height_list <- c(height_list, height)
  }
  height_quantiles <- quantile(height_list, c(.7, .75, .8, .85, .9, .95))
  height_quantiles_table <- dplyr::tbl_df(height_quantiles)
}

# main workhorse function that calls upon all the previous helper functions
# takes in the dataframe, and the cleaned distance matrices we created in earlier scripts
# (cleaning_duplicate_leases_for_stringmatch.R and string_dissim.py)
cluster_everything <- function(full_df, feather_path, output_path, calibration_date) {
  
  dendrogram_quantiles <- calibrate_df(full_df, feather_path, calibration_date)
  list_of_dates <- seq(as.Date("2005/1/1"), as.Date("2016/1/1"), by = "quarter")
  calibration_path <- output_path

  quantile85 <- dendrogram_quantiles$value[4]
  quantile90 <- dendrogram_quantiles$value[5]
  quantile95 <- dendrogram_quantiles$value[6]

  quantile85_output_path <- paste(calibration_path, "clustered_at_85th_percentile/", sep="")
  quantile90_output_path <- paste(calibration_path, "clustered_at_90th_percentile/", sep="")
  quantile95_output_path <- paste(calibration_path, "clustered_at_95th_percentile/", sep="")

  dir.create(quantile85_output_path, showWarnings = FALSE)
  dir.create(quantile90_output_path, showWarnings = FALSE)
  dir.create(quantile95_output_path, showWarnings = FALSE)

  for (date in list_of_dates) {
    date_output_path85 <- paste(quantile85_output_path, "leased_during_", as.character(date), ".dta", sep="")
    date_output_path90 <- paste(quantile90_output_path, "leased_during_", as.character(date), ".dta", sep="")
    date_output_path95 <- paste(quantile95_output_path, "leased_during_", as.character(date), ".dta", sep="")
    
	# filter only the observations from the date we care about
    quarterly_slice <- full_df %>%
      filter(startdate <= date, cluster_exprdate > date)
    quarterly_slice_sections <- split(quarterly_slice, quarterly_slice$section_id)
    one_lease_sections <- quarterly_slice_sections[lapply(quarterly_slice_sections, nrow)==1]
    quarterly_slice_multiple_leases <- quarterly_slice_sections[lapply(quarterly_slice_sections, nrow) != 1]
    
	hclust_list <- lapply(quarterly_slice_multiple_leases, cluster_df, feather_path = feather_path)

    height_list <- c(quantile85, quantile90, quantile95)
    
    # Write out height for p90 for paper text 
    temp_thres <- file(threshold_out)
    writeLines(sprintf("%.3f", round(quantile90,3)), temp_thres)
    close(temp_thres)

    print(height_list)
    date_output_list <- c(date_output_path85, date_output_path90, date_output_path95)
    
	# the following takes each height and does the clustering for that height
    # we have already found using the calibration dates earlier
    for (height_index in 1:length(height_list)) {
      max_k <- 0
      for (i in 1:length(hclust_list)) {
        hclust_object <- hclust_list[[i]]
        
		hclust_object$height <- round(hclust_object$height, 6)
        groups = cutree(hclust_object, h=height_list[height_index])
        groupdf <- tibble(groups, names(groups)) %>% dplyr::rename(labels = `names(groups)`)
        groupdf[["labels"]] <- as.numeric(groupdf[["labels"]])
        label_list <- groupdf %>% pull(labels)
        
		# keep track of the last observation_id so we can continuously add duplicate_id numbers
        max_k_temp <- max_k + max(groupdf$groups)
        groupdf <- groupdf %>% dplyr::mutate(groups = groups + max_k)
        max_k <- max_k_temp
        
		# merge in the dataframes by the unique_id variable and use the dynamically changing max_k
        # to allocate the duplicate_group_id variable
        quarterly_slice <- quarterly_slice %>% merge(groupdf, by.x = "unique_id", by.y = "labels", all = TRUE) %>%
          dplyr::mutate(groups = if_else(is.na(groups), 0, as.numeric(groups))) %>%
          dplyr::mutate(duplicate_group_id = duplicate_group_id + groups) %>%
          dplyr::select(-groups)
      }
      # add back in the one-lease sections as is
      for (i in 1:length(one_lease_sections)) {
        groupdf <- one_lease_sections[[i]] %>%
          dplyr::mutate(groups = max_k+1) %>%
          dplyr::select(unique_id, groups)
        max_k <- max_k+1
        quarterly_slice <- quarterly_slice %>% merge(groupdf, by.x = "unique_id", by.y = "unique_id", all = TRUE) %>%
          dplyr::mutate(groups = if_else(is.na(groups), 0, groups)) %>%
          dplyr::mutate(duplicate_group_id = duplicate_group_id + groups) %>%
          dplyr::select(-groups)
      }
      # prepare for stata export
      for(colname in names(quarterly_slice)) {
        if(is.character(quarterly_slice[[colname]])) {
          quarterly_slice[[colname]] <- as.factor(quarterly_slice[[colname]])
        }
      }
      # directory check
      print(date_output_list[height_index])
      # write to the folder
      write.dta(quarterly_slice, date_output_list[height_index])
    }
  }
}
# call this piece of code
full_df %>% cluster_everything(feather_path, output_path, calibration_date)
