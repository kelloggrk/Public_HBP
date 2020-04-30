# unit_subsampling.R
# Map units in descriptive sample, number of Haynesville wells

library(rgdal)
library(readstata13)
library(magrittr)
library(dplyr)
library(tidyr)
library(RColorBrewer)
library(raster)
library(sp)
library(sf)
library(ggplot2)
library(ggthemes)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while (basename(root) != "HBP") {
  root <- dirname(root)
}
source(file.path(root, "data.R"))

# input:
figPath        <- paste0(repo, "/Paper/Figures")
beamerFigPath  <- paste0(repo,"/Paper/Beamer_Figures")
wells_in       <- paste0(dropbox,"/IntermediateData/Louisiana/Wells/hay_wells_with_prod.dta")
units_in       <- paste0(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp")
sections_in    <- paste0(dropbox, "/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta")
counties_shp   <- paste0(dropbox, "/RawData/orig/Louisiana/County/la_counties.shp")

# output:
sample_units_pdf <- paste0(figPath, '/haynesville_units_in_sample.pdf')
well_count_pdf <- paste0(figPath, '/well_count_in_haynesville_units.pdf')
well_count_pdf_beamer <- paste0(beamerFigPath, '/well_count_in_haynesville_units.pdf')
unit_count_tex <- paste0(figPath, '/single_numbers_tex/unit_count_in_sample.tex')

# Read in unit data
sections_df    <- read.dta13(sections_in)
units_subsample_df <- sections_df # e.g., do not impose the sample restriction for these graphs

# Read in unit shapefile and merge with data frame
units_sf <- st_read(units_in) %>%
  st_transform(26915) %>%
  merge(sections_df,by="unitID")

# Get bounding box
counties_sf_bbox <- st_read(counties_shp) %>%
  st_transform(26915) %>%
  st_bbox(.)

county_raster <- readOGR(dsn = counties_shp)
new_county_raster <- spTransform(county_raster, CRS('+init=epsg:4267 +proj=longlat +ellps=clrk66 +datum=NAD27'))

# The following specifies the "box" that our zoomed in wellheads map will be of
# Since R Spatial is slightly slower at plotting, we want to intersect this box before
# plotting anythig else. We create the box by taking a fraction of the x- and y= boundaries
# of the county raster file.
global_xlim <- c(new_county_raster@bbox[1], new_county_raster@bbox[3])
global_ylim <- c(new_county_raster@bbox[2], new_county_raster@bbox[4])
temp_x1 = global_xlim[1]+1*(global_xlim[2]-global_xlim[1])/3
temp_x2 = global_xlim[1]+1*(global_xlim[2]-global_xlim[1])/3+(global_xlim[2]-global_xlim[1])/5
temp_y1 = global_ylim[1]+6*(global_ylim[2]-global_ylim[1])/13
temp_y2 = global_ylim[1]+6*(global_ylim[2]-global_ylim[1])/13+(global_ylim[2]-global_ylim[1])/12

local_xlim <- c(temp_x1, temp_x2)
local_ylim <- c(temp_y1, temp_y2)

# Create the polygon square that we will use as a boundary for the
# zoomed in portion of the mat
square <- rbind(c(temp_x1, temp_y1), c(temp_x2, temp_y1), c(temp_x2, temp_y2), c(temp_x1, temp_y2))
sp1 <- Polygon(square)
# Cast as spatial polygon object witht he correct coordinate reference system
sp = SpatialPolygons(list(Polygons(list(sp1), ID="a")), proj4string = CRS('+init=epsg:4267 +proj=longlat +ellps=clrk66 +datum=NAD27'))

# Read all input files and cast with the right CRS
sp_sf <-
  st_as_sf(sp) %>%
  st_transform(4267)

square_fort <- fortify(sp_sf)

#############################################################
# Prepare production data for plots
#############################################################
units_sf_plot <- units_sf %>%
                  mutate(in_sample = ifelse(is.na(flag_sample_descript),0,flag_sample_descript),
                         in_sample_color = ifelse(flag_sample_descript == 1, "#4D4D4D", "#E6E6E6"),
                         HayWellCount3 = ifelse(is.na(HayWellCount),0, 
                                                ifelse(HayWellCount > 3, 3, HayWellCount)),
                         HayWellCount3 = factor(HayWellCount3,levels=c(0,1,2,3)))

p1 <- ggplot() +
  geom_sf(data = units_sf_plot, size = 0.5, colour="black", aes(fill = in_sample_color)) +
  scale_fill_manual(values=c("#4D4D4D", "#E6E6E6"), labels = c("In sample", "Not in sample"))  + labs(fill = "") +
  geom_sf(data = square_fort, colour = "red", size = 0.7, fill = "transparent") +
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
ggsave(filename=sample_units_pdf, plot=p1, height=7, width=7)

# Outputs total units in section == count
  in_sample_table <- table(units_sf_plot$in_sample)
  write.table(format(in_sample_table[2],big.mark=",",
                     scientific=FALSE), 
              file = unit_count_tex, 
              row.names=FALSE, 
              col.names=FALSE, 
              na="", eol="", 
              quote=FALSE)

  p2 <- ggplot() +
    geom_sf(data = units_sf_plot, size = 0.5, colour="black", aes(fill = HayWellCount3)) +
    scale_fill_manual(values=c("#EBF3FB", "#98C6DF", "#3787C0", "#083E80"),
                      labels = c("0 wells", "1 well", "2 wells", "3+ wells"))  +
    labs(fill = "") +
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
  ggsave(filename=well_count_pdf, plot=p2, height=7, width=7)
  
  p2a <- ggplot() +
    geom_sf(data = units_sf_plot, size = 0.5, colour="black", aes(fill = HayWellCount3)) +
    scale_fill_manual(values=c("#EBF3FB", "#98C6DF", "#3787C0", "#083E80"),
                      labels = c("0 wells", "1 well", "2 wells", "3+ wells"))  +
    geom_sf(data = square_fort, colour = "red", size = 0.7, fill = "transparent") +
    labs(fill = "") +
    theme(axis.line=element_blank(),
          text = element_text(family = "sans"),
          axis.text.x=element_blank(),
          axis.text.y=element_blank(),
          axis.ticks=element_blank(),
          axis.title.x=element_blank(),
          axis.title.y=element_blank(),
          panel.background=element_blank(),
          panel.border=element_blank(),
          panel.grid.major = element_line(color="white"),
          panel.grid.minor=element_blank(),
          plot.background=element_blank(),
          legend.position = "left")
  ggsave(filename=well_count_pdf_beamer, plot=p2a, height=7, width=7)
