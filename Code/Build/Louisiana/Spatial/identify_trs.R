#-------------------------------------------------------------------------------
# Name:        identify_trs.R
# Purpose:     Given a sparsely identified section or unit shapefile, this
#              will impute the identifiers for all the rest of the unidentified
#              sections.
#
#-------------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Description: 
#
# This file is the host of all functions that recursively identify what
# section/township/range each unknown section in a dataset is
# Please note: these methods will not work on a sparsely identified 
# geometry. There must be at least one township/range/section identified in each
# column and row. From there these methods can impute the rest of the 
# identifiers based on the Louisiana Public Land Survey System (PLSS)
# 
# Note that these functions will just return NAs and not overwrite
# the dataset when they are non-imputable. One must identify by hand
# enough of the shapefile before these functions will work
# ---------------------------------------------------------------------------


# Helper functions for identifying the most likely left, right, top, and bottom
# neighbors. These functions use an approximately 800 m^2 buffer around the 
# appropriate edges to estimate the most likely neighbors on all 4 sides
get_left_neighbor <- function(unit) {
  xmin <- st_bbox(unit)[1]-801
  xmax <- st_bbox(unit)[1]-1
  ymin <- st_bbox(unit)[2]+1
  ymax <- st_bbox(unit)[4]-1
  box <- explore_box(xmin, xmax, ymin, ymax)
  left_neighb <- st_intersection(box, final_units) %>%
    mutate(areas = as.numeric(st_area(.))/4046.86) %>%
    filter(areas == max(areas)) %>%
    filter(areas >= (ymax-ymin)*100/4046.86) %>%
    dplyr::select(-areas)
  if(dim(left_neighb)[1]==0) {
    return(left_neighb)
  }
  lid <- left_neighb$unitID
  left_neighb <- final_units %>% filter(unitID==lid)
  return(left_neighb)
}

get_right_neighbor <- function(unit) {
  xmin <- st_bbox(unit)[3]+1
  xmax <- st_bbox(unit)[3]+801
  ymin <- st_bbox(unit)[2]+1
  ymax <- st_bbox(unit)[4]-1
  box <- explore_box(xmin, xmax, ymin, ymax)
  right_neighb <- st_intersection(box, final_units) %>%
    mutate(areas = as.numeric(st_area(.))/4046.86) %>%
    filter(areas == max(areas)) %>%
    filter(areas >= (ymax-ymin)*100/4046.86) %>%
    dplyr::select(-areas)
  if(dim(right_neighb)[1]==0) {
    return(right_neighb)
  }
  rid <- right_neighb$unitID
  right_neighb <- final_units %>% filter(unitID==rid)
  return(right_neighb)
}

get_top_neighbor <- function(unit) {
  xmin <- st_bbox(unit)[1]+1
  xmax <- st_bbox(unit)[3]-1
  ymin <- st_bbox(unit)[4]+801
  ymax <- st_bbox(unit)[4]+1
  box <- explore_box(xmin, xmax, ymin, ymax)
  top_neighb <- st_intersection(box, final_units) %>%
    mutate(areas = as.numeric(st_area(.))/4046.86) %>%
    filter(areas == max(areas))%>%
    filter(areas >= (ymax-ymin)*100/4046.86) %>%
    dplyr::select(-areas)
  if(dim(top_neighb)[1]==0) {
    return(top_neighb)
  }
  tid <- top_neighb$unitID
  top_neighb <- final_units %>% filter(unitID==tid)
  return(top_neighb)
}

get_bottom_neighbor <- function(unit) {
  xmin <- st_bbox(unit)[1]+1
  xmax <- st_bbox(unit)[3]-1
  ymin <- st_bbox(unit)[2]-801
  ymax <- st_bbox(unit)[2]-1
  box <- explore_box(xmin, xmax, ymin, ymax)
  bottom_neighb <- st_intersection(box, final_units) %>%
    mutate(areas = as.numeric(st_area(.))/4046.86) %>%
    filter(areas == max(areas))%>%
    filter(areas >= (ymax-ymin)*100/4046.86) %>%
    dplyr::select(-areas)
  if(dim(bottom_neighb)[1]==0) {
    return(bottom_neighb)
  }
  bid <- bottom_neighb$unitID
  bottom_neighb <- final_units %>% filter(unitID==bid)
  return(bottom_neighb)
}

# Recursively identify what township each unit is in by recursively identifying
# the township of the left neighbor and then if that doesn't work, the township of
# the right neighbor.
get_township <- function(unit) {
  if(!is.na(unit$township)) {
    return(unit$township)
  }
  else {
    #plot_recursion_township(final_units, unit$unitID, "yellow")
    leftie <- get_left_neighbor(unit)
    rightie <- get_right_neighbor(unit)
    if(dim(leftie)[1]==1) {
      left_township <- get_left_township(leftie)
      if(!is.na(left_township)) {
        final_units <<- final_units %>%
          mutate(township = ifelse(unitID == unit$unitID, left_township, township)) 
        return(left_township)
      } 
    }
    if(dim(rightie)[1]==1) {
      right_township <- get_right_township(rightie)
      if(!is.na(right_township)) {
        final_units <<- final_units %>%
          mutate(township = ifelse(unitID == unit$unitID, right_township, township)) 
        return(right_township)
      }
      
    }
    return(NA)
  }
}

get_right_township <- function(unit) {
  if(!is.na(unit$township)) {
    return(unit$township)
  }
  else {
    #plot_recursion_township(final_units, unit$unitID, "yellow")
    rightie <- get_right_neighbor(unit)
    if(dim(rightie)[1]==1) {
      right_township <- get_right_township(rightie)
      if(!is.na(right_township)) {
        final_units <<- final_units %>%
          mutate(township = ifelse(unitID == unit$unitID, right_township, township)) 
        return(right_township)
      }
    }
  }
  return(NA)
}
get_left_township <- function(unit) {
  if(!is.na(unit$township)) {
    return(unit$township)
  }
  else {
    #plot_recursion_township(final_units, unit$unitID, "yellow")
    leftie <- get_left_neighbor(unit)
    if(dim(leftie)[1]==1) {
      left_township <- get_left_township(leftie)
      if(!is.na(left_township)) {
        final_units <<- final_units %>%
          mutate(township = ifelse(unitID == unit$unitID, left_township, township)) 
        return(left_township)
      }
    }
  }
  return(NA)
}

# Recursively identify what range each unit is in by recursively identifying
# the range of the top neighbor and then if that doesn't work, the range of
# the bottom neighbor.
get_top_range <- function(unit) {
  if(!is.na(unit$range)) {
    return(unit$range)
  }
  else {
    top <- get_top_neighbor(unit)
    if(dim(top)[1]==1) {
      top_range <- get_top_range(top)
      if(!is.na(top_range)) {
        final_units <<- final_units %>%
          mutate(range = ifelse(unitID == unit$unitID, top_range, range))
        return(top_range)
      }
    }
  }
  return(NA)
}
get_bottom_range <- function(unit) {
  if(!is.na(unit$range)) {
    return(unit$range)
  }
  else {
    bottom <- get_bottom_range(unit)
    if(dim(bottom)[1]==1) {
      bottom_range <- get_bottom_range(bottom)
      if(!is.na(bottom_range)) {
        final_units <<- final_units %>%
          mutate(range = ifelse(unitID == unit$unitID, bottom_range, range))
        return(bottom_range)
      }
    }
  }
  return(NA)
}

get_range <- function(unit) {
  if(!is.na(unit$range)) {
    return(unit$range)
  }
  else {
    top <- get_top_neighbor(unit)
    bottom <- get_bottom_neighbor(unit)
    if(dim(top)[1]==1) {
      top_range <- get_top_range(top)
      if(!is.na(top_range)) {
        final_units <<- final_units %>%
          mutate(range = ifelse(unitID == unit$unitID, top_range, range))
        return(top_range)
      }
    } 
    if (dim(bottom)[1]==1) {
      bottom_range <- get_bottom_range(bottom)
      if(!is.na(bottom_range)) {
        final_units <<- final_units %>%
          mutate(range = ifelse(unitID == unit$unitID, bottom_range, range))
        return(bottom_range)
      }
    }
    return(NA)
  }
}

# Recursively identify what section each unit is in by recursively identifying
# the section of the left neighbor and then if that doesn't work, the section of
# the right neighbor.
get_left_section <- function(unit) {
  if(!is.na(unit$section)) {
    return(unit$section)
  }
  else {
    leftie <- get_left_neighbor(unit)
    if(dim(leftie)[1]==1) {
      left_section <- get_left_section(leftie)
      if(!is.na(left_section) & left_section <= 36) {
        if (left_section %in% c(7,8,9,10,11,19,20,21,22,23,31,32,33,34,35)) {
          final_section <- left_section + 1
        } else if (left_section %in% c(2,3,4,5,6,14,15,16,17,18,26,27,28,29,30)) {
          final_section <- left_section -1
        } else if (left_section %in% c(1,13,25)) {
          final_section <- left_section + 5
        } else if (left_section%in% c(12,24,36)) {
          final_section <- left_section - 5
        }
        final_units <<- final_units %>%
          mutate(section = ifelse(unitID == unit$unitID, final_section, section))
        return(final_section)
      }
    }
  }
  return(NA)
}

get_right_section <- function(unit) {
  if(!is.na(unit$section)) {
    return(unit$section)
  }
  else {
    rightie <- get_right_neighbor(unit)
    if(dim(rightie)[1]==1) {
      right_section <- get_right_section(rightie)
      if(!is.na(right_section) & right_section <= 36) {
        if (right_section %in% c(1,2,3,4,5,13,14,15,16,17,25,26,27,28,29)) {
          final_section <- right_section + 1
        } else if (right_section %in% c(8,9,10,11,12,20,21,22,23,24,32,33,34,35,36)) {
          final_section <- right_section - 1
        } else if (right_section %in% c(6,18,30)) {
          final_section <- right_section - 5
        } else if (right_section %in% c(7,19,31)) {
          final_section <- right_section + 5
        }
        final_units <<- final_units %>%
          mutate(section = ifelse(unitID == unit$unitID, final_section, section))
        return(final_section)
      }
    }
  }
  return(NA)
}

get_section <- function(unit) {
  if(!is.na(unit$section)) {
    return(unit$section)
  }
  else {
    left <- get_left_neighbor(unit)
    right <- get_right_neighbor(unit)
    top <- get_top_neighbor(unit)
    bottom <- get_bottom_neighbor(unit)
    if (dim(left)[1]==1){
      left_section <- get_left_section(left)
      if(!is.na(left_section) & left_section <= 36) {
        if (left_section %in% c(7,8,9,10,11,19,20,21,22,23,31,32,33,34,35)) {
          final_section <- left_section + 1
        } else if (left_section %in% c(2,3,4,5,6,14,15,16,17,18,26,27,28,29,30)) {
          final_section <- left_section -1
        } else if (left_section %in% c(1,13,25)) {
          final_section <- left_section + 5
        } else if (left_section %in% c(12,24,36)) {
          final_section <- left_section - 5
        }
        final_units <<- final_units %>%
          mutate(section = ifelse(unitID == unit$unitID, final_section, section))
        return(final_section)
      }
    } 
    if (dim(right)[1]==1) {
      right_section <- get_right_section(right)
      if(!is.na(right_section) & right_section <= 36) {
        if (right_section %in% c(1,2,3,4,5,13,14,15,16,17,25,26,27,28,29)) {
          final_section <- right_section + 1
        } else if (right_section %in% c(8,9,10,11,12,20,21,22,23,24,32,33,34,35,36)) {
          final_section <- right_section - 1
        } else if (right_section %in% c(6,18,30)) {
          final_section <- right_section - 5
        } else if (right_section %in% c(7,19,31)) {
          final_section <- right_section + 5
        }
        final_units <<- final_units %>%
          mutate(section = ifelse(unitID == unit$unitID, final_section, section))
        return(final_section)
      } 
    } 
  }
  return(NA)
}

# this function was created just to visualize the recursion
plot_recursion_township <- function(final_units, uid, color) {
  unit_of_interest <- final_units %>% filter(unitID == uid)
  if (count1 < 10) {
    plotname = paste(recursion_output_path_township, "plot_00", as.character(count1), ".png", sep="")
  } else if (count1 < 100) {
    plotname = paste(recursion_output_path_township, "plot_0", as.character(count1), ".png", sep="")
  } else {
    plotname = paste(recursion_output_path_township, "plot_", as.character(count1), ".png", sep="")
  }
  plot_to_save <- ggplot() +
    geom_sf(data = final_units, aes(fill = is.na(township))) +
    geom_sf(data = unit_of_interest, fill = color) +
    theme(legend.position='none')
  ggsave(plotname, plot = plot_to_save, height = 5.89, width = 4.07, device = NULL, path = NULL)
  count1 <<- count1 + 1
}

identify_trs <- function(units) {
  final_units <<- units
  for (unit_index in 1:length(final_units[,1][[1]])) {
    unit_of_interest <- final_units %>% filter(unitID == unit_index) 
    if (is.na(unit_of_interest$township)) {
      get_township(unit_of_interest)
    }
    if (is.na(unit_of_interest$range)) {
      get_range(unit_of_interest)
    }
    if (is.na(unit_of_interest$section)) {
      get_section(unit_of_interest)
    }
  }
  return(final_units)
}
