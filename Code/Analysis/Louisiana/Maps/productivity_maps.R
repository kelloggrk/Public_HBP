# Plot maps of productivity estimates and data

library(magrittr)
library(dplyr)
library(tidyr)
library(sf)
library(ggplot2)
library(viridis)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while (basename(root) != "HBP") {
  root <- dirname(root)
}

# Source helper functions
source(file.path(root, "data.R"))

figPath       <- paste0(repo, "/Paper/Figures")
beamerFigPath <- paste0(repo, "/Paper/Beamer_Figures")                     
units_sf_in   <- paste0(dropbox, "/IntermediateData/Louisiana/temp/units_sf.rds")

pname1 <- paste(figPath, '/', 'unit_productivity.pdf',sep='')
pname2 <- paste(figPath, '/', 'unit_mean_production.pdf',sep='')
pname1b <- paste(beamerFigPath, '/', 'unit_productivity.pdf',sep='')
pname2b <- paste(beamerFigPath, '/', 'unit_mean_production.pdf',sep='')

#############################################################
# Plot maps
#############################################################
units_sf <- readRDS(units_sf_in)

# Create bins for color scale
bptsN <- c(min(min(units_sf$phi_i_mean, na.rm=T), min(units_sf$unit_mean_prod, na.rm=T)),
           seq(13.75,15.25, by=0.25),
           max(max(units_sf$phi_i_mean, na.rm=T), max(units_sf$unit_mean_prod, na.rm=T)))

units_sf <- units_sf  %>%
  mutate(phi_i_mean = factor(cut(phi_i_mean, breaks = bptsN)),
         unit_mean_prod = factor(cut(unit_mean_prod, breaks = bptsN)))

nbptsN <- max(length(unique(units_sf$phi_i_mean)[!is.na(unique(units_sf$phi_i_mean))]),
              length(unique(units_sf$unit_mean_prod)[!is.na(unique(units_sf$unit_mean_prod))]))
colorsN <- viridis(nbptsN)
colorsN <- rev(colorsN)

# Imputed unit production at mean water input
p1 <- ggplot() +
  geom_sf(data = units_sf, size = 0.5, colour="black", aes(fill = phi_i_mean)) +
  scale_fill_manual(values=colorsN, name = "Predicted \nln(Production)") + labs(fill = "Predicted \nln(Production)") +
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
ggsave(filename=pname1, plot=p1, width = 7, height = 7)

# Actual observed average production by unit
p2 <- ggplot() +
  geom_sf(data = units_sf, size = 0.5, colour="black", aes(fill = unit_mean_prod)) +
  scale_fill_manual(values=colorsN, name = "Actual \nln(Production)") + labs(fill = "Actual \nln(Production)") +
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
ggsave(filename=pname2, plot=p2, width = 7, height = 7)

# Now plot for sans serif beamer slides
p1 <- p1 + theme(text = element_text(family = "sans"))
ggsave(filename=pname1b, plot=p1, width = 7, height = 7)

p2 <- p2 + theme(text = element_text(family = "sans"))
ggsave(filename=pname2b, plot=p2, width = 7, height = 7)

