#-------------------------------------------------------------------------------
# Name:        unit_section_merge.R
# Purpose:     Given a sparse unit shapefile, fill in all the holes and
#              identify all imputed units in the grid
#
#-------------------------------------------------------------------------------
#
# ---------------------------------------------------------------------------
# Description:
#
# This file fills in holes and merges together sections and units to create
# a master shapefile that will be used for our build and all descriptives
#
# The new shapefile will have units in places where the units exist.
# If the units do not exist, it would use sections as long as the sections are nicely shaped.
# If sections do not exist or are not nicely shaped we would need to impute the likely potential unit, following the same grid pattern
# We also include geographic restrictions here on both location and area of units
# We geographically restrict for now to the interior of the convex hull of the original unit shapefile.
# ---------------------------------------------------------------------------
library(rgdal)
library(ggplot2)
library(readstata13)
library(magrittr)
library(dplyr)
library(tidyr)
library(lubridate)
library(RColorBrewer)
library(raster)
library(sp)
library(sf)
library(gstat)
library(foreign)
library(ggthemes)
library(pracma)
library(splines)
library(stargazer)
library(xtable)
library(sandwich)
library(lmtest)
library(gtools)
library(smoothr)
library(rmapshaper)
library(lwgeom)
library(mapview)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while ((basename(root) != "HBP")&(basename(root) != "hbp")) {
  root <- dirname(root)
}
source(file.path(root, "data.R"))
# -----------------------------------------------------------------------------
# set all our path variables
rawOrigPath <- paste(dropbox, "/RawData/orig/Louisiana/DNR", sep="")
rawDataPath <- paste(dropbox, "/RawData/data/Louisiana/DNR", sep="")
# Files which are read in
tophole_prj <- paste(dropbox, "/RawData/orig/Louisiana/DNR/dnr_wells.shp", sep="")
sections_shp <- paste(dropbox, "/RawData/orig/Louisiana/DNR/Sections_1to100_000.shp", sep="")
counties_shp <- paste(dropbox, "/RawData/orig/Louisiana/County/la_counties.shp", sep="")
units <- paste(dropbox, "/RawData/orig/Louisiana/DNR/Haynesville_shale_units.shp", sep="")
# Files which are written out
map_output_path <- paste(dropbox, "/IntermediateData/Louisiana/gif/imputed_units/", sep="")
final_units_shp <- paste(dropbox, "/IntermediateData/Louisiana/Units/imputed_units_shapefile.shp", sep="")

# -----------------------------------------------------------------------------
# read in and clean shapefiles and dataframes we are using
# both the unit and section shapefiles as well as some
# section-level identifiers

# Haynesville unit shapefile: unitID is just the row number
units_sf <- st_read(units) %>%
  st_transform(26915) %>%
  mutate(unit_area = st_area(.)) %>%
  mutate(unitID = rownames(.))
counties_sf_bbox <- st_read(counties_shp) %>%
  st_transform(26915) %>%
  st_bbox(.)

sections_sf <- st_read(sections_shp) %>%
  st_transform(26915) %>%
  mutate(section_area = st_area(.)) %>%
  mutate(section_ID = rownames(.)) %>%
  mutate(TOWNSHIP = as.character(TOWNSHIP)) %>%
  mutate(TOWNSHIP = substr(TOWNSHIP, 2, nchar(TOWNSHIP)))%>%
  mutate(TOWNSHIP = ifelse(substr(TOWNSHIP, 3, 3)=="S", paste("-",substr(TOWNSHIP,1,nchar(TOWNSHIP)-1),sep=""), substr(TOWNSHIP,1,nchar(TOWNSHIP)-1))) %>%
  mutate(RANGE = as.character(RANGE)) %>%
  mutate(RANGE = substr(RANGE, 2, nchar(RANGE))) %>%
  mutate(RANGE = ifelse(substr(RANGE, 3, 3)=="W", paste("-",substr(RANGE,1,nchar(RANGE)-1),sep=""), substr(RANGE,1,nchar(RANGE)-1))) %>%
  mutate(section = SECTN) %>%
  mutate(township = as.numeric(TOWNSHIP)) %>%
  mutate(range = as.numeric(RANGE)) %>%
  filter(range >= -18 & range <= -7 & township >= 6 & township <= 21) %>%
  mutate(section_acres = as.numeric(section_area)/4046.86)

# This is to make the sections shapefile just a little more usable since it is so large
# we just crop to the relevant eight counties we have in the Haynesville
sections_cropped <- sections_sf %>%
  st_crop(counties_sf_bbox)
# -----------------------------------------------------------------------------
# Get a sense of what fraction of sections (especially sections where there is Haynesville drilling) match up well with units
# Then try to match up as many as possible with a section-identifier, we are using a 75% unit area inside of
# a corresponding section area threshold for this
units_x_sections <- st_intersection(units_sf, sections_cropped) %>%
  mutate(intersecting_area = st_area(.)) %>%
  mutate(percent_in_section = as.numeric(intersecting_area)/as.numeric(section_area)) %>%
  mutate(percent_in_unit = as.numeric(intersecting_area)/as.numeric(unit_area)) %>%
  dplyr::group_by(section_ID) %>%
  dplyr::mutate(max_percent = max(percent_in_section)) %>%
  dplyr::filter(percent_in_section==max_percent)%>%
  mutate(in_unit_shapefile = ifelse(percent_in_section>0.75, 1, 0)) %>%
  mutate(in_section_shapefile = ifelse(percent_in_unit > 0.75, 1, 0))

units_x_sections$geometry = NULL

units_with_section_id <- units_x_sections %>%
  filter(in_section_shapefile == 1) %>%
  dplyr::select(section, township, range, unitID)

units_sf <- merge(units_with_section_id, units_sf, all.y = TRUE) %>%
  st_as_sf(.)

sections_not_in_units <- st_disjoint(sections_cropped, st_combine(units_sf), sparse = FALSE)[,1]

sections_cropped$flag_not_in_units = sections_not_in_units

hello <- sections_cropped %>%
  filter(flag_not_in_units==0)

units_coords <- st_coordinates(units_sf)
units_chull <- chull(units_coords)

poi_x <- units_coords[units_chull,1]
poi_y <- units_coords[units_chull,2]
poi_mat <- data.frame(poi_x, poi_y)
hello2 <- as_tibble(poi_mat)

ok <- st_as_sf(hello2, coords = c("poi_x", "poi_y"))

pts <- st_coordinates(ok)
pts <- rbind(poi_mat, poi_mat[1,])

# This gets us a polygon that is the convex hull of our units shapefile
poly_list <- rbind(c(pts[1,1], pts[1,2]), c(pts[2,1], pts[2,2]), c(pts[3,1], pts[3,2]), c(pts[4,1], pts[4,2]), c(pts[5,1], pts[5,2]),
                        c(pts[6,1], pts[6,2]), c(pts[7,1], pts[7,2]), c(pts[8,1], pts[8,2]), c(pts[9,1], pts[9,2]), c(pts[10,1], pts[10,2]),
                        c(pts[11,1], pts[11,2]), c(pts[12,1], pts[12,2]), c(pts[13,1], pts[13,2]), c(pts[14,1], pts[14,2]), c(pts[15,1], pts[15,2]),
                        c(pts[16,1], pts[16,2]), c(pts[17,1], pts[17,2]), c(pts[18,1], pts[18,2]), c(pts[19,1], pts[19,2]), c(pts[20,1], pts[20,2]),
                        c(pts[21,1], pts[21,2]), c(pts[22,1], pts[22,2]), c(pts[23,1], pts[23,2]), c(pts[24,1], pts[24,2]))
convex_hull_poly <- Polygon(poly_list)
# Cast as spatial polygon object with the correct coordinate reference system
convex_hull = SpatialPolygons(list(Polygons(list(convex_hull_poly), ID="a")), proj4string = CRS('+init=epsg:26915'))

convex_hull_sf <-
  st_as_sf(convex_hull) %>%
  st_transform(26915)

index_sections <- st_intersects(convex_hull_sf, sections_sf)

sections_to_merge <- sections_sf[index_sections[[1]],]

units_just_geoms <- units_sf %>%
  dplyr::select(geometry, section, township, range, unitID) %>%
  mutate(poly_area_acres = as.numeric(st_area(.))/4046.86)


units_snapped <- units_just_geoms %>%
  st_snap(x = ., y= ., tolerance = 100) %>%
  mutate(poly_area_acres = as.numeric(st_area(.))/4046.86) %>%
  st_make_valid(.)

# Filtering out awkwardly shaped sections
decent_sections <- sections_to_merge %>%
  filter(section_acres > 600 & section_acres < 700)

sections_snapped <- st_snap(decent_sections, units_snapped, 200) %>%
  st_make_valid(.)
combined_units_snapped <- st_union(units_snapped) %>%
  st_make_valid(.)
sections_to_snap <- st_disjoint(sections_snapped, combined_units_snapped, sparse = FALSE)[,1]

sections_to_plot <- sections_snapped[sections_to_snap,]

# -----------------------------------------------------------------------------
# Inputs: geometry shape and dimensions m x n
# Outputs: return an sf object that is a list of the new polygons plus areas
creategrid <- function(geom_object, m, n, units_just_geoms, nogrid_list, unit_origin, left_shift, right_shift, bottom_shift, top_shift) {
  xmin <- st_bbox(geom_object)$xmin + left_shift
  xmax <- st_bbox(geom_object)$xmax + right_shift
  ymin <- st_bbox(geom_object)$ymin + bottom_shift
  ymax <- st_bbox(geom_object)$ymax + top_shift
  for (i in 1:m) {
    tempx1 <- xmin + (i-1)*(xmax-xmin)/m
    tempx2 <- xmin + i*(xmax-xmin)/m
    for (j in 1:n) {
      state <- c(toString(i),toString(j))
      # This here is just a condition so we skip over all the
      if (!(Position(function(x) identical(x, state), nogrid_list, nomatch = 0) > 0)) {
        tempy1 <- ymin + (j-1)*(ymax-ymin)/n
        tempy2 <- ymin + j*(ymax-ymin)/n
        square <- rbind(c(tempx1, tempy1), c(tempx2, tempy1), c(tempx2, tempy2), c(tempx1, tempy2), c(tempx1, tempy1))
        sp1 <- Polygon(square)
        sp = SpatialPolygons(list(Polygons(list(sp1), ID="a")), proj4string = CRS('+init=epsg:26915'))
        square_sf <-
          st_as_sf(sp) %>%
          st_transform(26915)
        square_fort = fortify(square_sf) %>%
          mutate(poly_area_acres = as.numeric(st_area(.))/4046.86)
        if (exists("gridded_geoms")) {
          gridded_geoms <- rbind(gridded_geoms, square_fort)
        }
        else {
          gridded_geoms <- square_fort
        }
      }
    }
  }
  gridded_geoms <- st_snap(gridded_geoms, units_just_geoms, 200) %>%
    st_difference(st_union(units_just_geoms))
  gridded_geoms <- gridded_geoms%>%
    mutate(poly_area_acres = as.numeric(st_area(.))/4046.86) %>%
    filter(poly_area_acres>100)  %>%
    mutate(unit_origin = unit_origin) %>%
    mutate(section = NA) %>%
    mutate(township = NA) %>%
    mutate(range = NA) %>%
    mutate(unitID = NA)
  return(gridded_geoms)
}

# -----------------------------------------------------------------------------
# Inputs: geometry shape and dimensions m x n
# Outputs: return an sf object that is a list of the new polygons plus areas
creategrid_funky <- function(geom_object, m, n, units_just_geoms, nogrid_list, unit_origin, left_shift, right_shift, bottom_shift, top_shift) {
  xmin <- st_bbox(geom_object)$xmin + left_shift
  xmax <- st_bbox(geom_object)$xmax + right_shift
  ymin <- st_bbox(geom_object)$ymin + bottom_shift
  ymax <- st_bbox(geom_object)$ymax + top_shift
  for (i in 1:m) {
    tempx1 <- xmin + (i-1)*(xmax-xmin)/m
    tempx2 <- xmin + i*(xmax-xmin)/m
    for (j in 1:n) {
      state <- c(toString(i),toString(j))
      # This here is just a condition so we skip over all the
      if (!(Position(function(x) identical(x, state), nogrid_list, nomatch = 0) > 0)) {
        tempy1 <- ymin + (j-1)*(ymax-ymin)/n
        tempy2 <- ymin + j*(ymax-ymin)/n
        square <- rbind(c(tempx1, tempy1), c(tempx2, tempy1), c(tempx2, tempy2), c(tempx1, tempy2), c(tempx1, tempy1))
        sp1 <- Polygon(square)
        sp = SpatialPolygons(list(Polygons(list(sp1), ID="a")), proj4string = CRS('+init=epsg:26915'))
        square_sf <-
          st_as_sf(sp) %>%
          st_transform(26915)
        square_fort = fortify(square_sf) %>%
          mutate(poly_area_acres = as.numeric(st_area(.))/4046.86)
        if (exists("gridded_geoms")) {
          gridded_geoms <- rbind(gridded_geoms, square_fort)
        }
        else {
          gridded_geoms <- square_fort
        }
      }
    }
  }
  gridded_geoms <- gridded_geoms %>%
    st_difference(st_union(units_just_geoms))
  gridded_geoms <- gridded_geoms%>%
    mutate(poly_area_acres = as.numeric(st_area(.))/4046.86) %>%
    filter(poly_area_acres>100)  %>%
    mutate(unit_origin = unit_origin) %>%
    mutate(section = NA) %>%
    mutate(township = NA) %>%
    mutate(range = NA) %>%
    mutate(unitID = NA)
  return(gridded_geoms)
}

get_geoms <- function(convex_hull, units_sf) {
  diff_diff = st_difference(convex_hull, st_union(units_sf))
  diff_polys <- st_cast(diff_diff, "POLYGON") %>%
    mutate(poly_area_acres = as.numeric(st_area(.))/4046.86)
  diff_polys <- filter(diff_polys, poly_area_acres > 100)
  return(diff_polys)
}

explore_box <- function(x1, x2, y1, y2) {
  box <- rbind(c(x1, y1), c(x2, y1), c(x2, y2), c(x1, y2), c(x1, y1))
  box_poly <- Polygon(box)
  # Cast as spatial polygon object witht he correct coordinate reference system
  box_sp = SpatialPolygons(list(Polygons(list(box_poly), ID="a")), proj4string = CRS('+init=epsg:26915'))
  # Read all input files and cast with the right CRS
  box_sf <-
    st_as_sf(box_sp) %>%
    st_transform(26915)
  box_fort = fortify(box_sf)
  return(box_fort)
}

###########
# Explore intersections

sections_x_units <- st_intersection(sections_snapped, st_union(units_snapped)) %>%
  mutate(poly_area = st_area(.)) %>%
  mutate(poly_area_acres = as.numeric(poly_area)/4046.86) %>%
  filter(poly_area_acres < 1) %>%
  dplyr::select(poly_area, geometry, section_ID)

sections_x_units$geometry = NULL
hello1 <- merge(sections_snapped, sections_x_units, by="section_ID", all.x = TRUE) %>%
  filter(!is.na(poly_area)) %>%
  dplyr::select(-poly_area)

sections_to_plot1 <- rbind(sections_to_plot, hello1)

# Only include nicely shaped sections
sections_to_plot1 <- sections_to_plot1 %>%
  mutate(poly_area_acres = as.numeric(st_area(.))/4046.86) %>%
  dplyr::select(poly_area_acres, geometry, section, township, range) %>%
  mutate(unitID = NA) %>%
  mutate(verts = npts(., by_feature = TRUE)) %>%
  filter(verts<=7) %>%
  dplyr::select(-verts)

## Clean up units we are going to want to impute
sections_to_plot1 <- sections_to_plot1 %>%
  mutate(too_small = ifelse(township == 17 & range == -16 & (section == 8 | section == 17 | section == 20 | section == 29), 1, 0)) %>%
  filter(too_small == 0) %>%
  dplyr::select(-too_small)

# Before we add units_snapped to sections_to_plot1, we have to flag things with interior v exterior convex hull
# The first 12 are the exterior convex hull
polys <- get_geoms(convex_hull_sf, units_snapped)
# uncomment to view what we try to fill in when drawing the convex hull
#ggplot() + geom_sf(data = units_snapped, fill = "blue") + geom_sf(data = polys[1:12,], colour = "red")

exterior_hull <- polys[1:12,]
exterior_sections_flag <- st_intersects(sections_to_plot1, exterior_hull, sparse = FALSE)[,1]
sections_to_plot1 <- sections_to_plot1 %>%
  mutate(flag_exterior = exterior_sections_flag) %>%
  mutate(unit_origin = ifelse(flag_exterior == TRUE, 3, 2)) %>%
  dplyr::select(-flag_exterior) %>%
  mutate(unitID = NA)

units_snapped <- units_snapped %>%
  mutate(unit_origin = 1)

units_snapped <- rbind(units_snapped, sections_to_plot1)

#### NEXT STEPS

# Recompute the convex hull and then impute all the interior bits
# Also do the recursive neighbor functions for section, township, range
polys <- get_geoms(convex_hull_sf, units_snapped)

# Shows that at this stage, convex_hull is a single polygon showing the boundaries of the Haynesville
ggplot() + geom_sf(data = convex_hull_sf, fill = "pink", size = 0.1)

# this is a function used for creating some images we used in the process of filling in the map
plot_map <- function(units_snapped, gridded_poly, map_output_path, id) {
  if (id < 10) {
    plotname = paste(map_output_path, "plot_00", as.character(id), ".png", sep="")
  } else if (id < 100) {
    plotname = paste(map_output_path, "plot_0", as.character(id), ".png", sep="")
  } else {
    plotname = paste(map_output_path, "plot_", as.character(id), ".png", sep="")
  }
  plot_to_save <- ggplot() +
    geom_sf(data = units_snapped, fill = "pink", size = 0.1) +
    geom_sf(data = gridded_poly, fill = "transparent", colour = "red")
  ggsave(plotname, plot = plot_to_save, height = 5.89, width = 4.07, device = NULL, path = NULL)
}

interior_one_unit_polys <- c(35, 42, 45, 47, 49, 55, 62, 63, 64,
                             65, 69, 71, 73, 75, 76, 77, 78, 81,
                             82, 83, 85, 86, 88, 89, 90, 91, 92,
                             96, 98, 99, 101, 103, 111)
for (i in 1:length(interior_one_unit_polys)) {
  poly <- polys[interior_one_unit_polys[i],]
  nogrid_list <- list()
  gridded_poly <- creategrid(poly, 1, 1, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
  units_snapped <- rbind(units_snapped, gridded_poly)
}

exterior_one_unit_polys <- c(7, 26, 28, 30, 32, 34, 36, 46, 51,
                              53, 54, 58, 68, 70, 72, 80, 106,
                              107, 114, 116)

for (i in 1:length(exterior_one_unit_polys)) {
  poly <- polys[exterior_one_unit_polys[i],]
  nogrid_list <- list()
  gridded_poly <- creategrid(poly, 1, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
  units_snapped <- rbind(units_snapped, gridded_poly)
}

poly_to_split <- polys[2,]
nogrid_list <- list(c('1','5'), c('1','6'), c('1','7'), c('1','8'), c('1','9'), c('1','10'), c('1','11'),
                    c('2','2'), c('2','7'), c('2','9'), c('2','10'), c('2','11'),
                    c('3','1'), c('3','4'), c('3','11'),
                    c('4','1'), c('4','3'), c('4','4'), c('4','5'), c('4','7'), c('4','11'),
                    c('5','1'), c('5','2'), c('5','3'), c('5','4'), c('5','5'), c('5','6'),
                    c('6','1'), c('6','2'), c('6','3'), c('6','4'), c('6','5'), c('6','6'), c('6','9'), c('6','10'), c('6','11'),
                    c('7','1'), c('7','2'), c('7','3'), c('7','4'), c('7','5'), c('7','9'), c('7','10'), c('7','11'),
                    c('8','1'), c('8','2'), c('8','3'), c('8','4'), c('8','5'), c('8','8'), c('8','9'), c('8','10'), c('8','11'),
                    c('9','1'), c('9','2'), c('9','3'), c('9','4'), c('9','5'), c('9','7'), c('9','8'), c('9','9'), c('9','10'), c('9','11'))
gridded_poly <- creategrid(poly_to_split, 9, 11, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

####

poly_to_split <- polys[3,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, units_snapped, nogrid_list, 5, 0, -600, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

######
poly_to_split <- polys[4,]
nogrid_list <- list(c('1','3'), c('1','4'), c('1','5'),
                    c('2','1'),
                    c('3','1'), c('3','3'), c('3','4'),
                    c('4','1'), c('4','3'), c('4','4'), c('4','5'),
                    c('5','1'), c('5','3'), c('5','4'), c('5','5'),
                    c('6','1'), c('6','3'), c('6','4'), c('6','5'))
gridded_poly <- creategrid(poly_to_split, 6, 5, units_snapped, nogrid_list, 5, 0, 800, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[5,]
nogrid_list <- list(c('1','1'), c('1','4'),
                    c('2','1'), c('2','2'),
                    c('3','1'), c('3','2'),c('3','4'),
                    c('4','4'))
gridded_poly <- creategrid(poly_to_split, 4, 4, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[6,]
nogrid_list <- list(c('1','1'), c('1','2'), c('1','3'), c('1','5'),
                    c('2','5'),
                    c('3','1'), c('3','2'), c('3','3'),
                    c('4','1'), c('4','2'), c('4','3'))
gridded_poly <- creategrid(poly_to_split, 4, 5, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[8,]
nogrid_list <- list(c('1','2'), c('1','3'), c('1','4'),
                    c('2','1'), c('2','4'),
                    c('3','1'), c('3','2'), c('3','4'),
                    c('4','1'), c('4','2'), c('4','3'))
gridded_poly <- creategrid(poly_to_split, 4, 4, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[9,]
nogrid_list <- list(c('2','1'), c('2','3'),
                    c('3','1'), c('3','3'))
gridded_poly <- creategrid(poly_to_split, 3, 3, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[10,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, units_snapped, nogrid_list, 5, 0, 0, -700, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[11,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, -500, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[12,]
nogrid_list <- list(c('1','1'), c('1','2'), c('1','3'),
                    c('2','2'),
                    c('3','1'), c('3','2'),
                    c('4','1'), c('4','2'),
                    c('5','1'), c('5','2'),
                    c('6','1'), c('6','2'), c('6','4'),
                    c('7','1'), c('7','2'), c('7','4'))
gridded_poly <- creategrid(poly_to_split, 7, 4, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[13,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 5, 0, 0, -1000, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[15,]
nogrid_list <- list(c('1','1'), c('1','2'), c('1','3'), c('1','4'), c('1','5'), c('1','9'), c('1','10'), c('1','11'),
                    c('1','12'), c('1','13'), c('1','14'), c('1','15'), c('1','16'), c('1','17'), c('1','18'), c('1','19'), c('1','20'))
gridded_poly <- creategrid(poly_to_split, 1, 21, units_snapped, nogrid_list, 5, 0, -1600, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[15,]
nogrid_list <- list(c('1','1'), c('1','2'), c('1','3'), c('1','4'), c('1','5'), c('1','6'), c('1','7'), c('1','8'), c('1','9'), c('1','10'), c('1','11'),
                    c('1','12'), c('1','13'), c('1','14'), c('1','15'), c('1','16'), c('1','17'), c('1','18'), c('1','19'), c('1','20'))
gridded_poly <- creategrid(poly_to_split, 1, 21, units_snapped, nogrid_list, 5, 2000, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[16,]
nogrid_list <- list(c('1','1'), c('1','6'), c('1','7'))
gridded_poly <- creategrid(poly_to_split, 1, 7, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[17,]
nogrid_list <- list(c('1','2'), c('1','3'), c('1','5'), c('1','6'), c('1','7'), c('1','8'),
                    c('2','1'), c('2','2'), c('2','3'), c('2','5'), c('2','6'), c('2','7'), c('2','8'),
                    c('3','1'),
                    c('4','1'), c('4','4'), c('4','6'), c('4','7'), c('4','8'))
gridded_poly <- creategrid(poly_to_split, 4, 8, units_snapped, nogrid_list, 5, 800, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[18,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 3, units_snapped, nogrid_list, 5, -800, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[19,]
nogrid_list <- list(c('1','1'), c('2','1'), c('3','1'), c('4','1'), c('5','1'), c('6','1'),
                    c('8','2'))
gridded_poly <- creategrid(poly_to_split, 8, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[20,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 800)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[21,]
nogrid_list <- list(c('2','1'))
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[22,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[23,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 600)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[24,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 1200)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[25,]
nogrid_list <- list(c('1','1'), c('1','2'), c('1','3'), c('1','5'),
                    c('2','1'), c('2','5'))
gridded_poly <- creategrid(poly_to_split, 3, 5, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)


########
poly_to_split <- polys[27,]
nogrid_list <- list(c('1','1'), c('1','2'), c('2','1'), c('2','2'), c('4','1'))
gridded_poly <- creategrid(poly_to_split, 4, 3, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)


########
poly_to_split <- polys[29,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)


########
poly_to_split <- polys[31,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)


########
poly_to_split <- polys[33,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 3, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[37,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)


########
poly_to_split <- polys[38,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[39,]
nogrid_list <- list(c('1','1'), c('1','2'), c('1','3'), c('1','4'),
                    c('2','1'), c('2','2'), c('2','6'),
                    c('3','1'), c('3','2'), c('3','5'), c('3','6'),
                    c('4','1'), c('4','5'), c('4','6'),
                    c('5','4'), c('5','5'), c('5','6'))
gridded_poly <- creategrid(poly_to_split, 5, 6, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[40,]
nogrid_list <- list(c('1','1'), c('1','2'),
                    c('2','4'),
                    c('3','2'))
gridded_poly <- creategrid(poly_to_split, 3, 4, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[41,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[43,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[44,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)


########
poly_to_split <- polys[48,]
nogrid_list <- list(c('1','1'))
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[50,]
nogrid_list <- list(c('1','2'))
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[52,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 3, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[56,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[57,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[59,]
nogrid_list <- list(c('1','1'), c('1','2'),
                    c('3','1'), c('3','2'),
                    c('4','1'), c('4','2'),
                    c('5','1'), c('5','2'))
gridded_poly <- creategrid(poly_to_split, 5, 3, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[60,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[61,]
nogrid_list <- list(c('1','2'))
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[66,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 3, units_snapped, nogrid_list, 4, 0, 0, 0, -1600)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[67,]
nogrid_list <- list(c('2','1'), c('2','2'), c('2','4'), c('2','5'), c('2','6'),
                    c('3','1'), c('3','4'), c('3','5'), c('3','6'))
gridded_poly <- creategrid(poly_to_split, 3, 6, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[74,]
nogrid_list <- list(c('2', '1'), c('3','1'))
gridded_poly <- creategrid(poly_to_split, 4, 2, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[79,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 3, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[84,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[87,]
nogrid_list <- list(c('2','2'))
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[93,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[94,]
nogrid_list <- list(c('2','2'))
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[95,]
nogrid_list <- list(c('1','1'), c('1','3'),
                    c('3','2'), c('3','3'))
gridded_poly <- creategrid(poly_to_split, 3, 3, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[97,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[100,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[102,]
nogrid_list <- list(c('1','1'), c('1','2'))
gridded_poly <- creategrid(poly_to_split, 2, 3, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[104,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[105,]
nogrid_list <- list(c('1','1'), c('1','2'),
                    c('3','3'),
                    c('4','3'),
                    c('5','1'), c('5','3'))
gridded_poly <- creategrid(poly_to_split, 5, 3, units_snapped, nogrid_list, 4, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[108,]
nogrid_list <- list(c('1','1'))
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[109,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 4, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[110,]
nogrid_list <- list(c('1','3'), c('1','4'), c('1','5'),
                    c('3','5'),
                    c('4','2'), c('4','3'), c('4','4'), c('4','5'),
                    c('5','2'), c('5','3'), c('5','4'), c('5','5'))
gridded_poly <- creategrid(poly_to_split, 5, 5, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[112,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 2, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[113,]
nogrid_list <- list(c('1','2'), c('1','3'), c('1','4'),
                    c('2','2'), c('2','3'), c('2','4'),
                    c('3','3'), c('3','4'),
                    c('4','1'),
                    c('5','1'), c('5','3'), c('5','4'),
                    c('6','1'), c('6','3'), c('6','4'),
                    c('7','1'), c('7','3'), c('7','4'))
gridded_poly <- creategrid(poly_to_split, 7, 4, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

########
poly_to_split <- polys[115,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 2, 1, units_snapped, nogrid_list, 5, 0, 0, 0, 0)
units_snapped <- rbind(units_snapped, gridded_poly)

#################
# Shreveport area

poly_to_split <- polys[1,]
nogrid_list <- list(c('1','1'))
gridded_poly <- creategrid(poly_to_split, 4, 3, units_snapped, nogrid_list, 5, 0, -35000, 11200, -19200)
units_snapped <- rbind(units_snapped, gridded_poly)

########

units_snapped_for_shreve <- units_snapped %>%
  filter((unitID != 2115 & unitID != 2116 & unitID != 449 & unitID != 265 & unitID != 382 & unitID != 487) | is.na(unitID))

poly_to_split <- polys[1,]
nogrid_list <- list(c('1','6'), c('2','5'), c('3','1'), c('3','2'), c('3','3'), c('3','10'),
                    c('4','5'), c('4','10'), c('5','1'), c('5','2'), c('5','3'), c('5','5'), c('5','7'), c('5','8'), c('5','10'))
gridded_poly <- creategrid(poly_to_split, 5, 10, units_snapped_for_shreve, nogrid_list, 5, 6400, -26800, 1600, -17400)
units_snapped_for_shreve <- rbind(units_snapped_for_shreve, gridded_poly)

poly_to_split <- polys[1,]
nogrid_list <- list(c('1','1'), c('1','2'), c('1','3'), c('1','4'), c('1','5'), c('1','6'), c('1','7'), c('1','8'), c('1','9'), c('1','10'),
                    c('1','11'), c('1','12'), c('1','13'), c('1','15'), c('1','16'), c('1','15'), c('1','17'), c('1','18'), c('1','20'), c('1','21'),
                    c('2','1'), c('2','2'), c('2','3'), c('2','4'), c('2','5'), c('2','9'), c('2','11'), c('2','12'), c('2','15'), c('2','16'),
                    c('2','17'), c('2','18'), c('3','1'), c('3','2'), c('3','3'), c('3','4'), c('3','5'), c('4','1'), c('4','18'),
                    c('5','7'), c('5','17'), c('5','18'), c('5','19'), c('5','20'))
gridded_poly <- creategrid(poly_to_split, 6, 22, units_snapped_for_shreve, nogrid_list, 5, 12800, -18200, 0, 0)
units_snapped_for_shreve <- rbind(units_snapped_for_shreve, gridded_poly)

poly_to_split <- polys[1,]
nogrid_list <- list(c('1','1'), c('1','2'), c('2','1'), c('2','2'), c('2','5'), c('2','7'),
                    c('3','5'), c('3','6'), c('3','7'),
                    c('4','1'), c('4','2'), c('4','3'), c('4','5'), c('4','6'), c('4','7'),
                    c('5','1'), c('5','2'), c('5','5'), c('5','6'), c('5','7'),
                    c('6','1'), c('6','2'), c('6','3'), c('6','5'), c('6','6'), c('6','7'),
                    c('7','1'), c('7','2'), c('7','3'), c('7','5'), c('7','6'), c('7','7'),
                    c('8','1'), c('8','2'), c('8','3'), c('8','5'), c('8','6'), c('8','7'),
                    c('9','1'), c('9','2'), c('9','3'), c('9','5'), c('9','6'), c('9','7'),
                    c('10','1'), c('10','5'), c('10','6'), c('10','7'),
                    c('11','1'), c('11','2'), c('11','5'), c('11','6'), c('11','7'))

gridded_poly <- creategrid(poly_to_split, 11, 7, units_snapped_for_shreve, nogrid_list, 5, 23000, 0, 6400, -17600)
units_snapped_for_shreve <- rbind(units_snapped_for_shreve, gridded_poly)


# Now we walk through these polygons
# MAKING SOME NEW UNITS

######
# The following specifies the "box" for our grid imputations
global_xlim <- c(st_bbox(convex_hull_sf)[1], st_bbox(convex_hull_sf)[3])
global_ylim <- c(st_bbox(convex_hull_sf)[2], st_bbox(convex_hull_sf)[4])
temp_x1 = global_xlim[1]+1*(global_xlim[2]-global_xlim[1])/13
temp_x2 = global_xlim[1]+1*(global_xlim[2]-global_xlim[1])/13+(global_xlim[2]-global_xlim[1])/26
temp_y1 = global_ylim[1]+4*(global_ylim[2]-global_ylim[1])/13
temp_y2 = global_ylim[1]+4*(global_ylim[2]-global_ylim[1])/13+(global_ylim[2]-global_ylim[1])/38

box <- explore_box(temp_x1, temp_x2, temp_y1, temp_y2)

nogrid_list <- list(c('1','2'))
gridded_poly <- creategrid(box, 2, 2, units_snapped_for_shreve, nogrid_list, 5, 0, 0, 0, 0)
units_snapped_for_shreve <- rbind(units_snapped_for_shreve, gridded_poly)

# clean up before plotting
units_snapped_for_shreve <- units_snapped_for_shreve %>%
  st_make_valid(.)
final_units <- units_snapped_for_shreve %>%
  st_snap(., ., tolerance = 300) %>%
  st_make_valid(.) %>%
  mutate(unitID = rownames(.))

final_units <- final_units  %>%
  mutate(section = as.numeric(as.character(section)))

# The following is loading self-written functions from the identify_trs.R file
# The goal of this is to identify the rest of the section/township/range ids
# for all the unknowns in our shapefile
trsfile = file.path(repo, "Code/Build/Louisiana/Spatial/identify_trs.R")
source(trsfile)
final_units <- identify_trs(final_units)

# Write out to shapefile and dta
final_units_nogeom <- final_units
final_units_nogeom$geometry = NULL

ggplot() + geom_sf(data = final_units, fill = "pink", size = 0.1)

final_units_cast <- final_units %>% st_cast('POLYGON')

# want to fill in a few more holes
polys2 <- get_geoms(convex_hull_sf, final_units_cast)

########
poly_to_split <- polys2[4,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, final_units_cast, nogrid_list, 5, 0, 0, 0, 0)
final_units_cast <- rbind(final_units_cast, gridded_poly)

########
poly_to_split <- polys2[5,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, final_units_cast, nogrid_list, 1, 0, 0, 0, 0)
final_units_cast <- rbind(final_units_cast, gridded_poly)

########
poly_to_split <- polys2[6,]
nogrid_list <- list()
gridded_poly <- creategrid_funky(poly_to_split, 1, 1, final_units_cast, nogrid_list, 1, 0, 0, 0, 0)
final_units_cast <- rbind(final_units_cast, gridded_poly)

########
poly_to_split <- polys2[9,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, final_units_cast, nogrid_list, 1, 0, 0, 0, 0)
final_units_cast <- rbind(final_units_cast, gridded_poly)

########
poly_to_split <- polys2[10,]
nogrid_list <- list()
gridded_poly <- creategrid(poly_to_split, 1, 1, final_units_cast, nogrid_list, 1, 0, 0, 0, 0)
final_units_cast <- rbind(final_units_cast, gridded_poly)

########
poly_to_split <- polys2[13,]
nogrid_list <- list(c('2','1'))
gridded_poly <- creategrid_funky(poly_to_split, 2, 1, final_units_cast, nogrid_list, 1, 0, 0, 0, 0)
final_units_cast <- rbind(final_units_cast, gridded_poly)

########
poly_to_split <- polys2[20,]
nogrid_list <- list(c('2','1'))
gridded_poly <- creategrid(poly_to_split, 2, 1, final_units_cast, nogrid_list, 5, 0, 0, 0, 0)
final_units_cast <- rbind(final_units_cast, gridded_poly)


#ggplot() + geom_sf(data = final_units_cast, fill = "pink", size = 0.1) #+ geom_sf(data = gridded_poly, colour = "red", fill = "transparent")

final_units_cast <- final_units_cast %>%
  mutate(unitID = rownames(.))
final_units_cast <- identify_trs(final_units_cast)
final_units_no_geom <- final_units_cast
final_units_no_geom$geometry <- NULL

# uncomment to view what our final dataset is
#ggplot() + geom_sf(data = final_units_cast, fill = "pink", size = 0.1) #+ geom_sf(data = gridded_poly, colour = "red", fill = "transparent")

# saves unitID instead as a numeric variable so that it does not 
# inadvertently become a factor string variable
final_units_cast$unitID <- as.numeric(final_units_cast$unitID)

if (file.exists(final_units_shp))
  #Delete file if it exists
  file.remove(final_units_shp)
st_write(final_units_cast, final_units_shp)
