# Make map showing sections, wellheads, and horizontal legs

library(rgdal)
library(raster)
library(readstata13)
library(magrittr)
library(dplyr)
library(sp)
library(sf)
library(ggplot2)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while (basename(root) != "HBP") {
  root <- dirname(root)
}
source(file.path(root, "data.R"))

# Specify all input filenames
raster_path <- paste(dropbox, "/RawData/orig/Louisiana/County/la_counties.shp", sep="")
bottom_hole_lines <- paste(dropbox, "/RawData/orig/Louisiana/DNR/BOTTOM_HOLE_LINE.shp", sep="")
units <- paste(dropbox, "/RawData/orig/Louisiana/DNR/Haynesville_shale_units.shp", sep="")
well_heads <- paste(dropbox, "/RawData/orig/Louisiana/DNR/dnr_wells.shp", sep="")

# Specify all output filenames
outfile_firm_level_hbp <-paste(repo, "/Paper/Figures/haynesville_hlegs_operator_map.pdf", sep="")

# Create the county raster file
county_raster <- readOGR(dsn = raster_path)
new_county_raster <- spTransform(county_raster, CRS('+init=epsg:4267 +proj=longlat +ellps=clrk66 +datum=NAD27'))

# The following specifies the "box" that our zoomed in wellheads map will be of
# Since R Spatial is slightly slower at plotting, we want to intersect this box before
# plotting anything else. We create the box by taking a fraction of the x- and y= boundaries
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

# Cast as spatial polygon object with the correct coordinate reference system
sp = SpatialPolygons(list(Polygons(list(sp1), ID="a")), proj4string = CRS('+init=epsg:4267 +proj=longlat +ellps=clrk66 +datum=NAD27'))

# Read all input files and cast with the right CRS
sp_sf <-
  st_as_sf(sp) %>%
  st_transform(4267)

bhl_sf <-
  st_read(bottom_hole_lines) %>%
  st_transform(4267)

units_sf <-
  st_read(units) %>%
  st_transform(4267)

wells_sf <-
  st_read(well_heads) %>%
  # The following tends to filter out most of the conventionally drilled wells
  subset(SPUD_DATE > "2004-01-01") %>%
  # Further filter out the wells only drilled in the Haynesville play
  subset((SANDS == "HA" | SANDS == "HAYNESVILLE") & SCOUT_WELL==10) %>%
  st_transform(4267)

units_sf$num_operator = as.numeric(units_sf$OPERATOR_N)

# Create some smaller datasets for the zoomed in map
# by intersecting with the spatial polygon object
new_bhl <-
  st_intersection(bhl_sf, sp_sf)

new_units <-
  st_intersection(units_sf, sp_sf)

new_wells <-
  st_intersection(wells_sf, sp_sf)

# Fortify everything so we can use sf (simple features)
new_bhl_fort <- fortify(new_bhl)
new_units_fort <- fortify(new_units)
well_fort <- fortify(new_wells)

# play around with firm colors to show unit operators
new_units_fort$firm_color[new_units_fort$num_operator==4] <- "lightsteelblue2"
new_units_fort$firm_color[new_units_fort$num_operator==54] <- "slategray2"
new_units_fort$firm_color[new_units_fort$num_operator==24] <- "slategray3"
new_units_fort$firm_color[new_units_fort$num_operator==11] <- "snow"
new_units_fort$firm_color[new_units_fort$num_operator==10] <- "slategray1"
new_units_fort$firm_color[new_units_fort$num_operator==10] <- "lightskyblue3"
new_units_fort$firm_color[new_units_fort$num_operator==44] <- "lightskyblue1"
new_units_fort$firm_color[new_units_fort$num_operator==43] <- "lightsteelblue"
new_units_fort$firm_color[new_units_fort$num_operator==36] <- "azure2"
new_units_fort$firm_color[new_units_fort$num_operator==20] <- "paleturquoise1"
new_units_fort$firm_color[new_units_fort$num_operator==49] <- "lightblue1"
new_units_fort$firm_color[new_units_fort$num_operator==47] <- "lightcyan1"
new_units_fort$firm_color[new_units_fort$num_operator==51] <- "aliceblue"
new_units_fort$firm_color[new_units_fort$num_operator==57] <- "lightskyblue2"

# Drop the weird little well legs
new_bhl_fort <- new_bhl_fort %>% filter(SHAPE_LEN >= 350)

# Plot everything using ggplot()

pdf(outfile_firm_level_hbp)
ggplot() +
  geom_sf(data = new_units_fort, size = 0.1, aes(colour = "grey", fill = firm_color)) +
  scale_fill_identity() +
  geom_point(data = well_fort, colour="white", size=3.5, aes(x=SURFACE_LO, y=SURFACE_L1)) +
  geom_point(data = well_fort, shape=1, colour ="black", size = 3.5, aes(x=SURFACE_LO, y=SURFACE_L1)) +
  scale_color_identity() +
  geom_sf(data = new_bhl_fort, colour = "black", size = 0.5) +
  theme(axis.line=element_blank(),
        axis.text.x=element_blank(),
        axis.text.y=element_blank(),
        axis.ticks=element_blank(),
        axis.title.x=element_blank(),
        axis.title.y=element_blank(),
        legend.position="none",
        panel.background=element_blank(),
        panel.border=element_blank(),
        panel.grid.major = element_line(color="white"),
        panel.grid.minor=element_blank(),
        plot.background=element_blank())

dev.off()
