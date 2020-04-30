# productivity_estimation.R
# Estimate productivity using a partially linear model
# Use leave-own-unit out for cross-validation, keep own unit in for estimation

library(rgdal)
library(raster)
library(readstata13)
library(lfe)
library(magrittr)
library(dplyr)
library(tidyr)
library(lubridate)
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

# Source helper functions
source(file.path(root, "data.R"))
source(paste(repo,"/Code/Analysis/Louisiana/Productivity/productivity_helpers.R",sep=""))

# input files:
units_in      <- paste0(dropbox, "/IntermediateData/Louisiana/DescriptiveUnits/master_unit_shapefile_urbanity.shp")
sections_in   <- paste0(dropbox, "/IntermediateData/Louisiana/SubsampledUnits/unit_data_sample_flags.dta")
wells_in       <- paste0(dropbox,"/IntermediateData/Louisiana/Wells/hay_wells_with_prod.dta")
well_x_unit_check <- paste0(dropbox,"/IntermediateData/Louisiana/DescriptiveUnits/haynesville_wells_x_units.dta")
price_in      <- paste0(dropbox,"/IntermediateData/PriceDayrate/PricesAndDayrates_Quarterly.dta")

# output files:
units_sf_out   <- paste0(dropbox, "/IntermediateData/Louisiana/temp/units_sf.rds")
units_out      <- paste0(dropbox, "/IntermediateData/Louisiana/ImputedProductivity/imputed_unit_centroid_productivity.dta")
p_w_out        <- paste0(dropbox, "/IntermediateData/CalibrationCoefs/P_w.csv")
wells_out       <- paste0(dropbox, "/IntermediateData/Louisiana/ImputedProductivity/imputed_well_productivity.dta")
cobbdouglas_out <- paste0(dropbox, "/IntermediateData/CalibrationCoefs/cobb_douglas.csv")

## Note: all distances are measured in the "midpoint" projection (+init=epsg:26915), which is meters
## Take care if using different x/y coordinates or shapefiles!
# Caliper: after how many bandwidths is the weight zero?
calip <- 4

#############################################################
# Prepare production data for kernel smoothing and plots
#############################################################
# Read in useful stata files
well_df     <- read.dta13(wells_in, convert.factors=FALSE)

# We only want data where the well is in the haynesville, we have location data on the weighted
# midpoint of the well, and there is expected lifetime productivity
well_df <- well_df %>%
  filter(is.na(disc_prod_1)==FALSE,
         disc_prod_1 > 0,
         is.na(weighted_lon)==FALSE)

# Scale water to 1485m
well_df <- well_df %>%
  mutate(water_scaled_1 = water_volume_1 * 1485 / max_lateral_length) %>%
  mutate(ln_water_1 = log(water_scaled_1))

# Logged production values
well_df <- well_df %>%
          mutate(ln_disc_prod = log(disc_prod_1))

# weighted_lon and weighted_lat are from the spatial_haynesville_bottom_lateral matching
well_df <- mutate(well_df, well_midpoint_lon = weighted_lon) %>%
          mutate(well_midpoint_lat = weighted_lat)


#############################################################
# Prep spatial components
#############################################################
coordinates(well_df) <- ~ well_midpoint_lon + well_midpoint_lat
proj4string(well_df) <- CRS("+init=epsg:26915")

# create unit centroids and cast as data.frame
# Eliminate overlaps (should be done upstream)
units_sf <- st_read(units_in) %>%
              st_transform(26915)

print(units_sf,n=3)
ggplot() + geom_sf(data=units_sf, fill="pink", size=0.1)

well_sf <- st_as_sf(well_df) %>%
  st_transform(26915)

# Check well-to-unit mapping:
units_x_wells_sf <- units_sf %>% 
                          st_intersection(well_sf) %>%
                          filter(!is.na(Well_Serial_Num))

mapping_check <- read.dta13(well_x_unit_check) %>% 
                  select(Well_Serial_Num,sectionFID_mid) %>%
                  right_join(units_x_wells_sf %>% as.data.frame() 
                             %>% select(Well_Serial_Num,unitID), by="Well_Serial_Num")

check <- identical(mapping_check$unitID,mapping_check$sectionFID_mid)
if (!check) stop("mapping is not the same as upstream")
rm(list = c("check","mapping_check"))


well_coords <- unlist(st_geometry(units_x_wells_sf)) %>%
                         matrix(ncol=2,byrow=TRUE) %>%
               as_tibble() %>%
               setNames(c("well_lon","well_lat"))
units_x_wells_sf <- bind_cols(units_x_wells_sf,well_coords)
units_centroids_sf <- units_sf %>%
                        st_centroid(.)
units_coords <- data.frame(unlist(st_geometry(units_centroids_sf)) %>%
                  matrix(ncol=2,byrow=TRUE), units_centroids_sf$unitID) %>%
                  as_tibble() %>%
                  setNames(c("unit_centroid_lon","unit_centroid_lat","unitID"))

units_sf <- units_sf %>% left_join(units_coords,by="unitID")
units_centroids_df <- data.frame(units_sf) %>% as_tibble

prod.df <- as.data.frame(units_x_wells_sf) %>% as_tibble()

#################### BEGIN ROBINSON ESTIMATOR #################################
## Robinson double-residual estimator #########################################
# Step 1: Get optimal bandwith
# Step 2: Kernel smooth productivity as function of location at each well -> m_1, e_1
# Step 3: Kernel smooth time trend and water at each well -> m_2, e_2
# Step 4: Regress e_1 on e_2 to get the betas
# Step 5: Calculate m_1 - m_2*beta to get "data" for spatial np regression

# Set date = 0 at Jan 1, 2010
prod.df <- prod.df %>% mutate(trend_jan10 = as.numeric(date(Original_Completion_Date)-date("2010-01-01")))

# Choose specification
prodVar  <- "ln_disc_prod"
covars   <- c("ln_water_1")

# Filter out missing values
keepMask  <- apply(prod.df[c(prodVar,covars)], 1, function(x) all(!is.na(x)) & all(!is.infinite(x)))
prod.df <- prod.df %>% filter(keepMask)
print(paste(sum(!keepMask),' observations dropped due to missing data',sep=""))

# Bandwidth selection: leave own unit out cross validation
# In practice, just use "Inf" for the own-unit distances
dist_dat <- cbind(prod.df$well_lon, prod.df$well_lat, prod.df$unitID)
dist_pts <- cbind(prod.df$well_lon, prod.df$well_lat, prod.df$unitID)

distmat_leaveunit <- apply(dist_dat, 1, distcalc_leaveunit,
                            points = dist_pts,
                            unitIDs = prod.df$unitID)

# Production
h <- NULL
temp <- optimize(crossval, c(1,25000),
                   fun_handle = gauss_kernel,
                   x = prod.df[prodVar],
                   dist = distmat_leaveunit, 
                   tol = 1e-5)
h$prod <- temp$minimum

# Covariates
h$covar <- rep(0,length(covars))
for (i in 1:length(covars)) { 
  temp <- optimize(crossval,  c(1,25000),
                      fun_handle = gauss_kernel,
                      x = prod.df[covars[i]],
                      dist = distmat_leaveunit, 
                      tol = 1e-5)
  h$covar[i] <- temp$minimum
}

# Compute distances between wells
dist_dat <- cbind(prod.df$well_lon, prod.df$well_lat, prod.df$unitID)
dist_pts <- cbind(prod.df$well_lon, prod.df$well_lat, prod.df$unitID)
dist_wells <- apply(dist_dat, 1, distcalc,
                    points = dist_pts)

prod.est <- robinson_diff(prod.df,prodVar,covars,dist_wells,h,calip)

ols <- prod.est$linear
phi.wells <- prod.est$nparam

# Non-parametric regression of production at unit centroids
# Find optimal bandwidth, leave out wells in own unit
temp <- optimize(crossval, c(1,25000),
                 fun_handle = gauss_kernel,
                 x = phi.wells,
                 dist = distmat_leaveunit,
                 tol = 1e-5)

h$npreg <- temp$minimum

print(h)

# Get unit to well distances
dist_dat <- cbind(prod.df$well_lon, prod.df$well_lat, prod.df$unitID)
dist_pts <- cbind(units_centroids_df$unit_centroid_lon, units_centroids_df$unit_centroid_lat)
dist_unit <- apply(dist_dat, 1, 
                    distcalc,
                    points = dist_pts)

phi.unit          <- matrix(0,nrow=nrow(units_centroids_df),ncol=1)
phi.unit[,1]      <- gauss_kernel(dist = dist_unit,
                                  x = phi.wells,
                                  h = h$npreg,
                                  calip = calip)

# Add in mean covariates
mean.covars <- prod.df %>% summarize_at(vars(covars),~mean(.)) %>% as.matrix()
phi.unit.mean <- phi.unit[,1] + mean.covars %*% t(ols$coefficients[-1,1])
phi.wells.mean <- phi.wells[,1] + mean.covars %*% (ols$coefficients[-1,1])

# Compute number of wells within 2, 5, 10 miles and within the caliper (about 3 miles)
wells2mi <- rowSums(dist_unit < 2*1609.344)
wells5mi <- rowSums(dist_unit < 5*1609.344)
wells7mi <- rowSums(dist_unit < 7*1609.344)
wells10mi <- rowSums(dist_unit < 10*1609.344)
wells_in_calip <- rowSums(dist_unit < calip * h$npreg)

# Add to dataframe
units_centroids_df <- units_centroids_df %>%
                        mutate(unit_phi = phi.unit[,1],
                            unit_phi_mean = phi.unit.mean,
                            wells_2mi = wells2mi,
                            wells_5mi = wells5mi,
                            wells_7mi = wells7mi,
                            wells_10mi = wells10mi,
                            wells_in_caliper = wells_in_calip)

# Attach to unit spatial dataframe for mapping
units_sf <- units_sf %>%
              mutate(phi_i = phi.unit[,1],
                     phi_i_mean = phi.unit.mean,
                     wells_2mi = wells2mi,
                     wells_5mi = wells5mi,
                     wells_7mi = wells7mi,
                     wells_10mi = wells10mi,
                     wells_in_caliper = wells_in_calip)
  

##### Compute implied water price ############################################
##### Assumes water use is optimal ###########################################

# Need to fix
# Import additional data for FOC
temp_roy <- read.dta13(sections_in,
                       select.cols=c("section","township","range","av_royalty_firstExpire"),
                       convert.factors=FALSE)

temp_price <- read.dta13(price_in,
                         select.cols=c("year","quarter","NGprice1"),
                         convert.factors=FALSE) # Use the 12-month futures price

opCost <- 0.6
sevTax <- 0.04

# Royalty rates
temp_roy <- temp_roy %>%
  rename(Section=section) %>%
  mutate(Range = ifelse(range < 0, paste(as.character(-range),"W",sep=""),
                        paste(as.character(range),"E",sep=""))) %>%
  mutate(Township = ifelse(township < 0, paste(as.character(-township),"S",sep=""),
                           paste(as.character(township),"N",sep="")))

water.df <- left_join(prod.df,temp_roy,by=c("Section","Township","Range"))

# Replace missing royalty rates with median value
roy_med <- median(water.df$av_royalty_firstExpire,na.rm=TRUE)
water.df <- water.df %>% replace_na(list(av_royalty_firstExpire=roy_med))

# Output price
water.df <- water.df %>%
  mutate(quarter = quarter(Original_Completion_Date)) %>%
  mutate(year  = year(Original_Completion_Date))
water.df <- left_join(water.df,temp_price,by=c("quarter","year"))

# Compute implied price of water
beta_w   <- ols$coefficients[2,1]
W        <- exp(prod.df[covars[1]])
Q 		   <- exp(phi.wells) * (W ^ beta_w)
denom_pw <- W
numer_pw <- Q * beta_w * (( 1 - water.df$av_royalty_firstExpire) * (1 - sevTax) * (water.df$NGprice1) - opCost)
p_w      <- as.matrix(numer_pw / denom_pw)

# Regress water price
p_w.fit    <- felm(p_w ~ 1, data=prod.df)

###################################
# Outputs
###################################
# Output unit centroid values
units_df <- units_centroids_df %>% 
                  select(unitID,
                         unit_phi,
                         unit_phi_mean,
                         wells_2mi,
                         wells_5mi,
                         wells_7mi,
                         wells_10mi,
                         wells_in_caliper,
                         unit_centroid_lat,
                         unit_centroid_lon)
save.dta13(units_df,units_out)

# Well productivity estimates
wells_prod <- data.frame(Well_Serial_Num = prod.df$Well_Serial_Num,
                         phi_wells = phi.wells)
save.dta13(wells_prod,wells_out)

# Water price, water coefficient
write.table(t(p_w.fit$coefficients[,1]),
            p_w_out,row.names=FALSE,
            col.names=colnames(p_w.fit$coefficients),
            sep=",")
write.table(t(ols$coefficients[-1,1]),
            cobbdouglas_out,
            row.names=FALSE,
            col.names=rownames(ols$coefficients)[-1],
            sep=",")

# Unit-level info for mapping
unit_level_production <- prod.df %>%
                          group_by(unitID) %>%
                          summarize(unit_mean_prod = mean(.data[[prodVar]], na.rm=TRUE)) %>%
                          mutate(in_sample = 1)

print(unit_level_production,n=3)



units_sf <- units_sf %>% 
                left_join(unit_level_production,
                  by="unitID", 
                  all.y=TRUE) %>%
                  mutate(in_sample_color = ifelse(is.na(in_sample), 
                                            "white", "black")) %>%
                st_as_sf()
#ggplot() + geom_sf(data = units_sf, fill = "pink", size = 0.1)

saveRDS(units_sf,file=units_sf_out)



