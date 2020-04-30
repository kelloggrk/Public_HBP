#-------------------------------------------------------------------------------
# Name:        cleaning_duplicate_leases_for_stringmatch.R
# Purpose:     Takes in the preliminary downweighted data from stata (area_downweight.do)
# and creates section-level feathered distance matrices to spit into python for final cleaning
#-------------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# This script takes in louisiana_leases_csvs_preliminary_downweight.dta and creates
# section-specific distance matrices. It creates the scores to use for each
# variable we are constructing the distance matrix with and provides a weight
# vector for how to weight each possible observation. The final scores are
# cleaned and added in using python (string_dissim.py)
# ---------------------------------------------------------------------------

library(readstata13)
library(dplyr)
library(haven)
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

# Create directories for feather files
dir.create(featherdir, showWarnings = FALSE)
feather_path_folder <- paste(featherdir, "/Feathered_sectionlevel_dfs", sep="")
dir.create(feather_path_folder, showWarnings = FALSE)
feather_path_stringmatched_folder <- paste(featherdir, "/Feathered_stringmatched_sectionlevel_dfs", sep="")
dir.create(feather_path_stringmatched_folder, showWarnings = FALSE)

# load in the data set we want to use by first specifying path and then reading
df_path <- paste(dropbox,"/IntermediateData/Louisiana/Leases/louisiana_leases_csvs_preliminary_downweight.dta", sep="")
full_df <- read_dta(df_path)
full_df <- as_tibble(full_df)
full_df <- full_df %>%
  dplyr::select(grantor, grantor_orig, alsgrantee, insttype, royalty, recordno, startdate, cluster_exprdate, group_trsa, group_final, count_final, area, area_revised, vol, page, unique_id, section_id, latitude, longitude, section, township, range, total_section_area) %>%
  mutate(startdate_numeric = as.numeric(startdate)) %>%
  mutate(startdate_numeric = scale(startdate_numeric, center = TRUE, scale = TRUE)) %>%
  mutate(cluster_exprdate_numeric = as.numeric(cluster_exprdate)) %>%
  mutate(cluster_exprdate_numeric = scale(cluster_exprdate_numeric, center = TRUE, scale = TRUE))
write_feather(full_df, paste(featherdir, "/louisiana_leases_DI_csvs_for_clustering.feather", sep=""))

feather_path_out <- paste(feather_path_folder,"/feathered_df_", sep="")
local_inf_file <- paste(dropbox,"/IntermediateData/Louisiana/Leases/local_inf.csv", sep="")

clean_leases_with_weights <- function(feather_path) {
  grantor_weight <- 1
  grantee_weight <- 1
  insttype_weight <- 1
  royalty_weight <- 1
  volpage_weight <- 1
  recordno_weight <- 1
  startdate_weight <- 1
  cluster_exprdate_weight <- 1
  # input a score vector of the form
  # [ local_inf, na_score, both_na_score, no_match_score ]
  score_vec <- c(100,0.7,0.4,1)

  # Make sure to carry the local infinity value over to python
  local_inf <- score_vec[1]
  na_score <- score_vec[2]
  both_na_score <- score_vec[3]
  no_match_score <- score_vec[4]
  
  write.csv(local_inf, file = local_inf_file, row.names=FALSE)
  
  newdf <- split(full_df, full_df$section_id)
  
  # the following function takes in a section-level dataset and calculates all pairwise distances
  append_stringdiffs <- function(df) {
    section_df <- dplyr::tbl_df(df)
    section_label <- df$section_id[1]

    joined_section_df <- section_df %>%
      inner_join(section_df, by='group_trsa')
    
	joined_section_df <- joined_section_df %>% mutate(volpage_dist = if_else(is.na(vol.x) & is.na(vol.y) & is.na(page.x) & is.na(page.y), volpage_weight*both_na_score,
                                                                         if_else(is.na(vol.x) | is.na(vol.y) | is.na(page.x) | is.na(page.y), volpage_weight*na_score,
                                                                                 if_else(vol.x == vol.y & page.x == page.y, 0, volpage_weight*no_match_score)))) %>%
      mutate(recordno_dist = if_else(is.na(recordno.x) & is.na(recordno.y), recordno_weight*both_na_score,
                                     if_else(is.na(recordno.x) | is.na(recordno.y), recordno_weight*na_score,
                                             if_else(recordno.x == recordno.y, 0, recordno_weight*no_match_score)))) %>%
      mutate(royalty_dist = if_else(is.na(royalty.x) & is.na(royalty.y), royalty_weight*both_na_score,
                                    if_else(is.na(royalty.x) | is.na(royalty.y), royalty_weight*na_score,
                                            if_else(royalty.x == royalty.y, 0, royalty_weight*no_match_score)))) %>%
      mutate(insttype_dist = if_else(is.na(insttype.x) & is.na(insttype.y), insttype_weight*both_na_score,
                                     if_else(is.na(insttype.x) | is.na(insttype.y), insttype_weight*na_score,
                                             if_else(insttype.x == insttype.y, 0, insttype_weight*no_match_score)))) %>%
      mutate(startdate_dist = if_else(is.na(startdate.x) & is.na(startdate.y), startdate_weight*both_na_score,
                                      if_else(is.na(startdate.x) | is.na(startdate.y), startdate_weight*na_score,
                                              startdate_weight*abs(as.numeric(startdate_numeric.x-startdate_numeric.y, units = "days"))))) %>%
      mutate(cluster_exprdate_dist = if_else(is.na(cluster_exprdate.x) & is.na(cluster_exprdate.y), cluster_exprdate_weight*both_na_score,
                                     if_else(is.na(cluster_exprdate.x) | is.na(cluster_exprdate.y), cluster_exprdate_weight*na_score,
                                             cluster_exprdate_weight*abs(as.numeric(cluster_exprdate_numeric.x-cluster_exprdate_numeric.y, units = "days"))))) %>%
      mutate(grantor_weight = grantor_weight) %>%
      mutate(grantee_weight = grantee_weight)
    
	write_feather(joined_section_df, paste(feather_path, as.character(section_label), ".feather", sep=""))
  }
  section_joined_df_list <- lapply(newdf, append_stringdiffs)

}

clean_leases_with_weights(feather_path_out)
