% resultsOut.m
% Ryan Kellogg
% Created: 31 January, 2020


%{
This script outputs values for key results from the counterfactual simulations 
for use in the paper (output formatted as single-number .tex files)

%}


clear all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set directory paths

% Identify directories for repo and dropbox
S = pwd;
test = strcmp(S(end-2:end),'HBP') + strcmp(S(end-2:end),'hbp');
while test==0
    S = S(1:end-1);
    test = strcmp(S(end-2:end),'HBP') + strcmp(S(end-2:end),'hbp');
end
clear test
cd(S)
globals         % call path names in globals.m
clear S

% Set up directories for code, data, and output
dirs.wdir = strcat(repodir, '/Code/Analysis/Model/');
dirs.outputdir = strcat(dropbox, '/IntermediateData/SimResults/');
dirs.figfinaldir = strcat(repodir,'/Paper/Figures/simulations/');
dirs.singlenumdir = strcat(repodir,'/Paper/Figures/single_numbers_tex/simresults/');
dirs.caltabledir = strcat(repodir,'/Paper/Figures/');
dirs.db = strcat(dropbox,'/');

% Add all code files (including utilities) to matlab search path
addpath(genpath(dirs.wdir))



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Optimal pri term and royalty
optrtfile = [dirs.outputdir,'optroyaltypriterm.csv'];
optrt = csvread(optrtfile);
optr = optrt(1); optT = optrt(2);   % opt royalty and pri term (years)
clear optrtfile optrt
% opt royalty
fid = fopen([dirs.singlenumdir,'/optr.tex'],'w');
fprintf(fid,'%8.0f\\%%', optr*100);
fclose(fid);
% opt pri term
fid = fopen([dirs.singlenumdir,'/optT.tex'],'w');
fprintf(fid,'%8.2f', optT);
fclose(fid);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Output from varying the primary term
varptfile = [dirs.figfinaldir,'varPriTerm.csv'];
varpt = csvread(varptfile,1,0);
clear varptfile
% Owner's value at optimum
fid = fopen([dirs.singlenumdir,'/varpt_ownervalopt.tex'],'w');
fprintf(fid,'$\\$ %8.2f $', varpt(2,8)*10);
fclose(fid);
% Owner's value at royalty only
fid = fopen([dirs.singlenumdir,'/ownervalroyonly.tex'],'w');
fprintf(fid,'$\\$ %8.2f $', varpt(2,7)*10);
fclose(fid);
% Diff in owner's value at optimum vs royalty only, in $1,000
fid = fopen([dirs.singlenumdir,'/varpt_ownervalopt_delta.tex'],'w');
fprintf(fid,'$\\$ %8.0f $', (varpt(2,8)-varpt(2,7))*10000);
fclose(fid);
% Percent increase in owner value at optimum vs royalty only
fid = fopen([dirs.singlenumdir,'/varpt_ownervalopt_pctdelta.tex'],'w');
fprintf(fid,'%8.1f\\%%', (varpt(2,8)/varpt(2,7)-1)*100);
fclose(fid);
% Bonus at optimum
fid = fopen([dirs.singlenumdir,'/varpt_bonusopt.tex'],'w');
fprintf(fid,'$\\$ %8.2f $', varpt(2,10)*10);
fclose(fid);
% Bonus at royalty only
fid = fopen([dirs.singlenumdir,'/bonusroyonly.tex'],'w');
fprintf(fid,'$\\$ %8.2f $', varpt(2,9)*10);
fclose(fid);
% Production | drlg at social opt
fid = fopen([dirs.singlenumdir,'/prodsocialopt.tex'],'w');
fprintf(fid,'%8.2f', varpt(2,11)*10);
fclose(fid);
% Production | drlg at opt pri term
fid = fopen([dirs.singlenumdir,'/varpt_prod.tex'],'w');
fprintf(fid,'%8.2f', varpt(2,13)*10);
fclose(fid);
% Percent decrease in production under opt contract
fid = fopen([dirs.singlenumdir,'/varpt_prod_pctdelta.tex'],'w');
fprintf(fid,'%8.0f\\%%', (varpt(2,11)-varpt(2,13))/varpt(2,11)*100);
fclose(fid);
% Water | drlg at social opt (millions of gal)
fid = fopen([dirs.singlenumdir,'/watersocialopt.tex'],'w');
fprintf(fid,'%8.1f', varpt(2,14)/1E6);
fclose(fid);
% Water | drlg at opt pri term (millions of gal)
fid = fopen([dirs.singlenumdir,'/varpt_water.tex'],'w');
fprintf(fid,'%8.1f', varpt(2,16)/1E6);
fclose(fid);
% Percent decrease in water under opt contract
fid = fopen([dirs.singlenumdir,'/varpt_water_pctdelta.tex'],'w');
fprintf(fid,'%8.0f\\%%', (varpt(2,14)-varpt(2,16))/varpt(2,14)*100);
fclose(fid);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Output from varying the primary term, with multiple wells
varptmfile = [dirs.figfinaldir,'varPriTerm_multwells.csv'];
varptm = csvread(varptmfile,1,0);
clear varptmfile
% Opt pri term
fid = fopen([dirs.singlenumdir,'/mult_optpt.tex'],'w');
fprintf(fid,'%8.2f', varptm(2,3));
fclose(fid);
% Diff in owner's value at optimum vs royalty only, in $1,000
fid = fopen([dirs.singlenumdir,'/mult_varpt_ownervalopt_delta.tex'],'w');
fprintf(fid,'$\\$ %8.0f $', (varptm(2,8)-varptm(2,7))*10000);
fclose(fid);
% Percent increase in owner value at optimum vs royalty only
fid = fopen([dirs.singlenumdir,'/mult_varpt_ownervalopt_pctdelta.tex'],'w');
fprintf(fid,'%8.1f\\%%', (varptm(2,8)/varptm(2,7)-1)*100);
fclose(fid);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Output from varying the drilling subsidy
varlcfile = [dirs.figfinaldir,'varLC.csv'];
varlc = csvread(varlcfile,1,0);
clear varlcfile
% Opt drlg subsidy
fid = fopen([dirs.singlenumdir,'/optLC.tex'],'w');
fprintf(fid,'$\\$ %8.2f $', varlc(2,3)*10);
fclose(fid);
% Diff in owner's value at optimum vs royalty only, in $1,000	
fid = fopen([dirs.singlenumdir,'/varlc_ownervalopt_delta.tex'],'w');	
fprintf(fid,'$\\$ %8.0f $', (varlc(2,8)-varlc(2,7))*10000);	
fclose(fid);	
% Percent increase in owner value at optimum vs royalty only	
fid = fopen([dirs.singlenumdir,'/varlc_ownervalopt_pctdelta.tex'],'w');	
fprintf(fid,'%8.1f\\%%', (varlc(2,8)/varlc(2,7)-1)*100);	
fclose(fid);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Optimal royalty and drilling subsidy combo
optrlcfile = [dirs.outputdir,'optroyaltylessorcost.csv'];
optrlc = csvread(optrlcfile);
optrlc_r = optrlc(1); optrlc_lc = optrlc(2);   % opt royalty and lessor cost
optrlc_EVL = optrlc(3);     % lessor val
clear optrtfile optrt
% opt royalty
fid = fopen([dirs.singlenumdir,'/optrlc_optr.tex'],'w');
fprintf(fid,'%8.0f\\%%', optrlc_r*100);
fclose(fid);
% opt drlg subsidy
fid = fopen([dirs.singlenumdir,'/optrlc_optLC.tex'],'w');
fprintf(fid,'$\\$ %8.2f $', optrlc_lc*10);
fclose(fid);
% Diff in owner's value at optimum vs royalty only, in $1,000	
fid = fopen([dirs.singlenumdir,'/optrlc_ownervalopt_delta.tex'],'w');	
fprintf(fid,'$\\$ %8.0f $', (optrlc_EVL-varlc(2,7))*10000);	
fclose(fid);	



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Sensitivity of opt roy and pri term to different calibrations
sensfile = [dirs.outputdir,'optroyaltypriterm_sensitivity.csv'];
sens = csvread(sensfile,1,0);
% Open file 
fid = fopen([dirs.caltabledir,'/sensitivitytable.tex'],'w');
% Write table  
fprintf(fid,'\\begin{tabular} {c l c c c } \\midrule \\midrule \n');
fprintf(fid,' & & & & Increase in \\\\ \n');
fprintf(fid,' & & Optimal & Optimal &  owner''s value vs. \\\\ \n');
fprintf(fid,'Row & Parameters & royalty & pri term & royalty-only lease \\\\ \n');
fprintf(fid,'\\midrule \n');
fprintf(fid,'1 & Baseline calibration from table \\ref{tab:sum_calibration} & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [optr*100; optT; (varpt(2,8)/varpt(2,7)-1)*100]);
fprintf(fid,'2 & Reduce productivity std dev $\\sigma_\\theta$ by 50\\%%$^1$ & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [sens(1,1)*100; sens(2,1); (sens(3,1)/sens(4,1)-1)*100]);
fprintf(fid,'3 & Reduce productivity std dev $\\sigma_\\theta$ by 75\\%%$^1$ & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [sens(1,2)*100; sens(2,2); (sens(3,2)/sens(4,2)-1)*100]);
fprintf(fid,'4 & Reduce water coefficient $\\beta$ by 50\\%%$^2$ & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [sens(1,3)*100; sens(2,3); (sens(3,3)/sens(4,3)-1)*100]);
fprintf(fid,'5 & Increase expected productivity by 33\\%%$^3$ & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [sens(1,6)*100; sens(2,6); (sens(3,6)/sens(4,6)-1)*100]);
fprintf(fid,'6 & Reduce expected productivity by 33\\%%$^3$ & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [sens(1,7)*100; sens(2,7); (sens(3,7)/sens(4,7)-1)*100]);
fprintf(fid,'7 & Reduce scale $\\sigma_\\nu$ of iid shocks by 50\\%%$^4$ & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [sens(1,4)*100; sens(2,4); (sens(3,4)/sens(4,4)-1)*100]);
fprintf(fid,'8 & Use projection (\\ref{eq:cost_day_rate_relationship}) to estimate $\\alpha_0$$^5$ & %8.0f\\%% & %8.2f years & %8.1f\\%% \\\\ \n' ,...
    [sens(1,5)*100; sens(2,5); (sens(3,5)/sens(4,5)-1)*100]);
fprintf(fid,'\\midrule \n');
fprintf(fid,'\\end{tabular}');
% Close file  
fclose(fid);

% Single number files for royalties with lower sigma_nu
fid = fopen([dirs.singlenumdir,'/optr_halfsig.tex'],'w');
fprintf(fid,'%8.0f\\%%', sens(1,1)*100);
fclose(fid);
fid = fopen([dirs.singlenumdir,'/optr_quartersig.tex'],'w');
fprintf(fid,'%8.0f\\%%', sens(1,2)*100);
fclose(fid);

% Single number files for pri terms with lower sigma_nu
fid = fopen([dirs.singlenumdir,'/optT_halfsig.tex'],'w');
fprintf(fid,'%8.2f', sens(2,1));
fclose(fid);
fid = fopen([dirs.singlenumdir,'/optT_quartersig.tex'],'w');
fprintf(fid,'%8.2f', sens(2,2));
fclose(fid);









