#-------------------------------------------------------------------------------
# Name:        string_dissim.py
# Purpose:     Scores string differences and performs final scoring on the distance matrix
#
# Author:      Nadia
#
# Created:     18/05/2018
#-------------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Description: This python file takes in the feathered datasets and performs
# the string dissimilarity measure using fuzzy wuzzy. We then scale these
# distance scores by .01 (since the raw scores are out of 100) and add them in
# to the distance measure we had already computed from all the other observations
# in cleaning_duplicate_leases_for_stringmatch.R. These feather folders are specified
# in the code depending on what weight vector we want to use and are all located
# in a local folder titled ClusteringData in the repo that is .gitignored.
#
# Finally, this code goes through and uses masks in order to classify distances
# as infinity or 0. For example, all those already downweighted via group_C
# need to not be downweighted any further. And we can only downweight within
# leases that have the same original reported area. Then we do one final mask
# to set distances between the same observation as 0
# ---------------------------------------------------------------------------
import getpass
if str(getpass.getuser())=="ericlewis":
    dbPath=r"/Users/ericlewis/Dropbox/HBP"
    featherPath = r"/Users/ericlewis/Documents/EconResearch2/HBP"
elif str(getpass.getuser())=="Ryan Kellogg":
    dbPath=r"C:/Users/Ryan Kellogg/Dropbox/HBP"
    featherPath = r"C:/Work/HBP"

import sys
import os
sys.path.insert(0,  r"{}/Utils/Python_Utils".format(dbPath))


#Set directory paths
outputPath = r"{}/ClusteringData".format(featherPath)
clusterPath = outputPath
featherFolder = r"{}/Feathered_sectionlevel_dfs/".format(clusterPath)
featherFolderOut = r"{}/Feathered_stringmatched_sectionlevel_dfs/".format(clusterPath)
if not os.path.exists(featherFolderOut):
	os.makedirs(featherFolderOut)

import numpy as np
import pandas
# import pandas as pd
import math
from fuzzywuzzy import fuzz
from fuzzywuzzy import process
import feather
global local_inf

# Read in local_inf: originally set in ./cleaning_duplicate_leases_for_stringmatch.R
local_inf_file = r"{}/IntermediateData/Louisiana/Leases/local_inf.csv".format(dbPath)
local_inf_in = pandas.read_csv(local_inf_file)
local_inf = local_inf_in['x'].iloc[0]

def calculate_string_diffs(df):
	new_data = df
	# varnames is a list of tuples of all pairs of variables we want to compare via fuzzy string matching
	# match_varnames is the string names of all the matches we want to have in our dataset

    # the lambda function works by indexing into each row and performing row-wise operations on the columns we are interested in
	new_data["grantor_score_dist"] = new_data.apply(lambda x: x["grantor_weight"]*(1.0-(fuzz.partial_ratio(x["grantor.x"],x["grantor.y"])/100.0)), axis=1)
	new_data["grantee_score_dist"] = new_data.apply(lambda x: x["grantee_weight"]*(1.0-(fuzz.partial_ratio(x["alsgrantee.x"],x["alsgrantee.y"])/100.0)), axis=1)
	new_data["dist_raw"] = new_data["volpage_dist"]+new_data["recordno_dist"]+new_data["insttype_dist"]+new_data["royalty_dist"]+new_data["startdate_dist"]+new_data["cluster_exprdate_dist"]+new_data["grantor_score_dist"]+new_data["grantee_score_dist"]
	new_data["dist"] = new_data.apply(lambda x: math.sqrt(x["dist_raw"]), axis = 1)
    
	# This masking avoids further downweighting anything captured in group_C
	new_data["group_final_C.x"] = new_data.apply(lambda x: x["group_final.x"].strip(), axis=1)
	new_data["group_final_C.x"] = new_data.apply(lambda x: x["group_final_C.x"].rstrip('0123456789'), axis=1)
	new_data["group_final_C.y"] = new_data.apply(lambda x: x["group_final.y"].strip(), axis=1)
	new_data["group_final_C.y"] = new_data.apply(lambda x: x["group_final_C.y"].rstrip('0123456789'), axis = 1)

	group_C_x_mask = new_data["group_final_C.x"]=="C"
	new_data.loc[group_C_x_mask, "dist"] = local_inf
	group_C_y_mask = new_data["group_final_C.y"]=="C"
	new_data.loc[group_C_y_mask, "dist"] = local_inf

	zero_dist_mask = new_data["unique_id.x"] == new_data["unique_id.y"]
	new_data.loc[zero_dist_mask, "dist"] = 0
	return new_data

for filename in os.listdir(featherFolder):
	if filename!=".DS_Store":
		dfPath = featherFolder+filename
		filename_split = filename.split('.')
		dfOutPath = featherFolderOut+filename_split[0]+"_stringmatched.feather"
		df = feather.read_dataframe(dfPath)
		newdf = calculate_string_diffs(df)
		feather.write_dataframe(newdf, dfOutPath)
