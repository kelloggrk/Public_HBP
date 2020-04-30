# Create time series plot of prices, leasing, and drilling for the paper

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
library(cowplot)

# clear the workspace
rm(list=ls())
root <- getwd()
# recursively get up to the base of the repo where the filepaths are located
while (basename(root) != "HBP") {
  root <- dirname(root)
}
source(file.path(root, "data.R"))

plot_data_file <- paste(dropbox, "/IntermediateData/Louisiana/Wells/haynesville_rig_data_for_graphing.dta", sep="")

fdir <- paste(repo, "/Paper/Figures", sep="")
plot_data <- read.dta13(plot_data_file)

plot_data <- plot_data %>%
  mutate(datestring = paste(Year, "-", Month, "-", "01", sep="")) %>%
  mutate(date = as.Date(datestring, origin= "1970-01-01"))

fig_henry_hub_long <-
  plot_data %>%
  filter(Year>2005 & date < as.Date("2015-06-01")) %>%
  ggplot(aes(x = date, y = NGprice1)) +
  geom_line() +
  scale_size_manual(values = c(1.5)) +
  scale_y_continuous(limits = c(0, 15)) +
  scale_color_manual(values = c("black")) +
  theme_bw() +
  labs(x = "", y = "HH futures price (2014 $)") +
  theme(text = element_text(family = "serif", size = 14),
        legend.title = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.x=element_blank(),
        legend.position = c(0.2, 0.75),
        legend.text = element_text(size = 30),
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        legend.key = element_rect(size = 5))

fig_lease_count <-
  plot_data %>%
  filter(Year>2005 & date < as.Date("2015-06-01")) %>%
  ggplot(aes(x = date, y = Hay_Lease_Count)) +
  geom_line() +
  scale_size_manual(values = c(1.5)) +
  scale_color_manual(values = c("black")) +
  theme_bw() +
  labs(x = "", y = "Leases signed per month") +
  theme(text = element_text(family = "serif", size = 14),
        legend.title = element_blank(),
        legend.position = c(0.2, 0.75),
        axis.text.x = element_blank(),
        axis.ticks.x=element_blank(),
        legend.text = element_text(size = 30),
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        legend.key = element_rect(size = 5))


fig_hgas_from_spuddate <-
  plot_data %>%
  filter( Year>2005 & date < as.Date("2015-06-01")) %>%
  ggplot(aes(x = date, y = Hay_Well_Count)) +
  geom_line() +
  scale_x_date(breaks = as.Date(c("2006-01-01", "2007-01-01", "2008-01-01", "2009-01-01",
                                  "2010-01-01", "2011-01-01", "2012-01-01", "2013-01-01", "2014-01-01",
                                  "2015-01-01")),
               labels = c("Jan 2006", "Jan 2007", "Jan 2008", "Jan 2009", "Jan 2010", "Jan 2011", "Jan 2012", "Jan 2013", "Jan 2014", "Jan 2015")) +
  scale_y_continuous(limits = c(0,50)) +
  scale_size_manual(values = c(1.5)) +
  scale_color_manual(values = c("black")) +
  theme_bw() +
  labs(x = "Date", y = "Wells spudded per month") +
  theme(text = element_text(family = "serif", size = 14),
        legend.title = element_blank(),
        legend.position = c(0.2, 0.75),
        legend.text = element_text(size = 30),
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        panel.grid.minor.x = element_blank(),
        legend.key = element_rect(size = 5))

fig_monthly_prod <-
  plot_data %>%
  filter( Year>2005 & date < as.Date("2015-06-01")) %>%
  ggplot(aes(x = date, y = monthly_production)) +
  geom_line() +
  scale_x_date(breaks = as.Date(c("2006-01-01", "2007-01-01", "2008-01-01", "2009-01-01",
                                  "2010-01-01", "2011-01-01", "2012-01-01", "2013-01-01", "2014-01-01",
                                  "2015-01-01")),
               labels = c("Jan 2006", "Jan 2007", "Jan 2008", "Jan 2009", "Jan 2010", "Jan 2011", "Jan 2012", "Jan 2013", "Jan 2014", "Jan 2015")) +
  scale_size_manual(values = c(1.5)) +
  scale_color_manual(values = c("black")) +
  theme_bw() +
  labs(x = "Date", y = "Production (million mmBtu)") +
  theme(text = element_text(family = "serif", size = 14),
        legend.title = element_blank(),
        legend.position = c(0.2, 0.75),
        legend.text = element_text(size = 30),
        panel.grid.major.y = element_blank(),
        panel.grid.minor.y = element_blank(),
        panel.grid.minor.x = element_blank(),
        legend.key = element_rect(size = 5))


haynesville_production_graph <-
  plot_grid(fig_henry_hub_long, fig_lease_count, fig_hgas_from_spuddate, ncol=1, align="v", label_size = 1)

plot_production <-
  plot_grid(haynesville_production_graph, ncol = 1, align = "v", label_size = 1)

save_plot(file.path(fdir, "/haynesville_time_series_plot.pdf"),
          plot_production,
          base_height = 10, base_width = 9)

