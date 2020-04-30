# map_sample_units.R
# Create map of structural estimation sample units

library(tidyverse)
library(magrittr)
library(sf)
library(sp)
library(viridis)

# clear the workspace
rm(list=ls())
root <- getwd()

# recursively get up to the base of the repo where the filepaths are located
while ((basename(root) != "HBP")&(basename(root) != "hbp")) {
  root <- dirname(root)
}

# Source helper functions
source(file.path(root, "data.R"))

figPath        <- paste0(repo, "/Paper/Figures")
beamerFigPath  <- paste0(repo, "/Paper/Beamer_Figures")                     
unitID_file    <- paste0(dropbox, "/IntermediateData/CalibrationCoefs/unitestsampleIDs.csv")
units_shp      <- paste0(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp")
out_file       <- paste0(figPath, "/final_estimation_sample_unit_map.pdf")

#############################################################
# Plot map
#############################################################
units_sf <- st_read(units_shp) %>%
            st_transform(26915)

sample_ids <- read_csv(unitID_file,
                       col_names = c("unitID"),
                       col_types = cols(
                                    unitID = col_integer())) %>% 
                      mutate(sample = as.integer(1))

units_sample_sf <- merge(units_sf,sample_ids,by="unitID",all.x=TRUE) %>%
                    mutate(sample = if_else(is.na(sample),0,1),
                           sample = factor(sample))

levels(units_sample_sf$sample) <- c("Not in final calibration sample", "In final calibration sample")

g1 <- ggplot() +
  geom_sf(data = units_sample_sf, size = 0.25, color="black", aes(fill = sample)) +
  scale_fill_manual(name=NULL,values=c("gray85", "gray20")) +
  theme(axis.line=element_blank(),
        text = element_text(family = "serif"),
        axis.text.x=element_blank(),
        axis.text.y=element_blank(),
        axis.ticks=element_blank(),
        axis.title.x=element_blank(),
        axis.title.y=element_blank(),
        panel.background=element_blank(),
        panel.border=element_blank(),
        panel.grid.major = element_line(color="white"),
        panel.grid.minor=element_blank(),
        plot.background=element_blank())
ggsave(filename=out_file, plot=g1, width = 7, height = 7)

