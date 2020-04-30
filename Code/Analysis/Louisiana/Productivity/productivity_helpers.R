# This file is a set of helper functions for cross-validation and estimation
# of the partially linear production function (Robinson estimator)

library(dplyr)
library(tidyr)
library(magrittr)
library(lfe)

######################################################
# write_obj: write object to text file
######################################################

write_obj <- function(file_name,x) {
  fid <- file(file_name)
  writeLines(x, fid)
  close(fid)
}


#####################################################
# distcalc: Regular Euclidean distances
#####################################################
distcalc <- function(x,points) {
  dist <- sqrt((x[1]-points[,1])^2 + (x[2]-points[,2])^2)
  return(dist)
}

#####################################################
# distcalc_leaveunit: Leave own unit out distances
#####################################################
# x is dataset
# points is the lat/lon variables (vectors)
# unitIDs is the vector of unit IDs
# dist_override is a very large number to make the distance between
# points within unit very large such that thy are not affecting the distance-weighted imputation
distcalc_leaveunit <- function(x, points, unitIDs) {
  dist <- sqrt((x[1]-points[,1])^2 + (x[2]-points[,2])^2)
  bool_mask <- (x[3]==unitIDs)
  bool_mask <- unlist(bool_mask)
  dist[bool_mask] = Inf
  return(dist)
}

#####################################################
# gauss_kernel: Gaussian kernel function 
#####################################################
# dist is a distance matrix
# x is the variable of interest
# h is the bandwidth of the Gaussian kernel (SD)
# calip is a caliper distance, in terms of h.  if zero, no caliper

gauss_kernel <- function(dist, x, h, calip=0) {
  x <- as.matrix(x)
  distw <- dnorm(dist/h) / h
  if (calip > 0){
    distw[dist > calip*h] <- 0
  }
  if (is.matrix(distw)) {
    x_pred <- (distw %*% x) / rowSums(distw)
  } else if (is.vector(distw)) {
    x_pred <- (distw %*% x) / sum(distw)
  }
}

#####################################################
# crossval: Cross-validation function
#####################################################
# fun_handle is kernel function
# x is variable of interest as a Nx1 vector
# dist is distance matrix as an NxN vector
# h is bandwidth (scalar)
crossval <- function(h,fun_handle,x,dist) {
    x_pred <- apply(dist,1,fun_handle,x=x,h=h)
    mse    <- sum((x_pred-x)**2)
  }


#####################################################
# robinson_diff: Implements the robinson estimator 
#####################################################
# df is a data frame with the regression data
# y is the name of the outcome variable
# covar is the names of the covariates
# dist_mat is a matrix of distances between points
# h should be a structure with 1 entry for h$prod and K entries for h$covar
# calip is a caliper in terms of h, if = 0 no caliper

robinson_diff <- function(df,y,covar,dist_mat,h,calip) {
  
  regDta      <- df
  prodVar     <- y
  covar.names <- covar
  covar.n     <- length(covar.names)
  dist        <- dist_mat
  
  # Check for missing values 
  if (length(covar.names) > 0) {
    keepMask  <- apply(df[covar.names], 1, function(x) all(!is.na(x)) & all(!is.infinite(x)))
    regDta <- regDta %>% filter(keepMask)
    dist <- dist[keepMask,keepMask]
  }  
  
  # Bring the covariates together in data frame
  X.names <- covar.names
  X.mat   <- as.matrix(regDta[,X.names])
  X.n     <- ncol(X.mat)
  
  # Set up matrices
  weighted_prod <- matrix(0,nrow=nrow(regDta),ncol=1)
  resid_prod    <- matrix(0,nrow=nrow(regDta),ncol=1)
  weighted_X    <- matrix(0,nrow=nrow(regDta),ncol=X.n)
  resid_X       <- matrix(0,nrow=nrow(regDta),ncol=X.n)
  
  # Production smoothing
  log_gas_prod <- as.matrix(regDta[,prodVar])
  weighted_prod[,1] <- gauss_kernel(dist_mat, log_gas_prod, h=h$prod, calip=calip)
  # Compute residuals
  resid_prod[,1] <- weighted_prod[,1] - log_gas_prod
  
  # Covariate smoothing: need to adapt for different bandwidths
  for (i in 1:length(covars)) {
    weighted_X[,i] <- gauss_kernel(dist_mat, regDta[,covars[i]], h=h$covar[i], calip=calip)
  }
  # Compute residuals
  resid_X        <- weighted_X - X.mat
  resid_X        <- data.frame(resid_X)
  names(resid_X) <- covar.names
  
  # Double-residual regression to get covariate coefficients
  df.robinson     <- data.frame(resid_prod,resid_X)
  robinson.model  <- as.formula(paste("resid_prod ~ ", paste(covar.names, collapse= "+"),"|0|0|0"))
  robinson.fit    <- felm(robinson.model, data=df.robinson)

  # Subtract smoothed covariates from smoothed production to get consistent spatial estimates
  # Omit the constant so it ends up in the non-parametric part
  fit_X  <- weighted_X %*% robinson.fit$coefficients[-1,]
  phi_i  <- weighted_prod[,1] - fit_X
  
  output <- list(linear=summary(robinson.fit,robust=TRUE),nparam=phi_i,keepMask=keepMask)
  return(output)
  
}
