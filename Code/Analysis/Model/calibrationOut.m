% calibrationOut.m
% Ryan Kellogg
% Created: 22 January, 2020


%{
This script outputs parameter values from the calibrated model, for use in
the paper
Begins with building and outputing the main calibration table, calibration_summary.tex
Then outputs single-number files for inserting in-line into the paper

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
dirs.caltabledir = strcat(repodir,'/Paper/Figures/');
dirs.singlenumdir = strcat(repodir,'/Paper/Figures/single_numbers_tex/calibration/');
dirs.db = strcat(dropbox,'/');

% Add all code files (including utilities) to matlab search path
addpath(genpath(dirs.wdir))



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Load productivity, drilling cost, and shock parameters into params struct


% Water use parameters
betafile = [dirs.db,'IntermediateData/CalibrationCoefs/cobb_douglas.csv'];
Pwfile = [dirs.db,'IntermediateData/CalibrationCoefs/P_w_final.csv'];
params.beta = csvread(betafile,1);  % exponent on water in prod function
params.P_w = csvread(Pwfile,0);     % "price" of water. 

% Drilling cost parameters
costcoefsfile = [dirs.db,'IntermediateData/CalibrationCoefs/CostCoefsFinal.csv'];
costcoefs = csvread(costcoefsfile,0);
params.thetaD = costcoefs(1);   % fixed cost of drilling ($10m)
params.thetaDR = costcoefs(2);  % dayrate multiplier parameter ($10m per dayrate in $)
thetaDAfile = [dirs.db,'IntermediateData/CalibrationCoefs/thetaDA_final.csv'];
params.thetaDA = csvread(thetaDAfile,0);    % additional drilling cost ($10m)

% Set scale choice-specific logit cost shocks (pre-tax values)
epsScalefile = [dirs.db,'IntermediateData/CalibrationCoefs/epsScale_final.csv'];
params.epsScale_pretax = csvread(epsScalefile,0);

clear betafile Pwfile costcoefs* thetaDAfile epsScalefile

% Time to build
params.thetaTTB = 0;      % time-to-build cost at unit start ($10m)
params.thetaTTBt = 2;     % length of time to build period (years)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set initial lease terms at social optimum and instantiate hbpmodelsim object
params.roy = 0;         % royalty
params.LC = 0;          % drilling subsidy ($10m)
params.rent = 0;        % rent per period ($10m/period)
params.T = 0;           % primary term in years (0 = inf)
params.Lshare = 1;      % share of unit acreage that is leased

% Wells per unit
params.Wells = 1;       

% Instantiate object
obj = hbpmodelsim(dirs,params);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Calibration summary table for paper
% Open file 
fid = fopen([dirs.caltabledir,'/calibration_summary.tex'],'w');
% Write table  
fprintf(fid,'\\begin{tabular} {l c c l } \\midrule \\midrule \n');
fprintf(fid,'\\multicolumn{1}{c}{\\textbf{Parameter}} & \\textbf{Notation} & \\textbf{Value} & \\multicolumn{1}{c}{\\textbf{Source}} \\\\ \n');
fprintf(fid,'\\midrule \n');
fprintf(fid,'\\textbf{State transitions} & $\\{P_t, D_t\\}$ & & Henry Hub prices and rig dayrates \\\\ \n');
fprintf(fid,'\\hspace{4pt} Price drift constant & $\\kappa^P_0$ & %8.2g &  \\\\ \n' ,obj.PDcoefs(3));
fprintf(fid,'\\hspace{4pt} Price drift linear term & $\\kappa^P_1$ & %8.2g &  \\\\ \n' ,obj.PDcoefs(4));
fprintf(fid,'\\hspace{4pt} Price volatility & $\\sigma^P$ & %8.3g &  \\\\ \n' ,obj.PDcoefs(8));
fprintf(fid,'\\hspace{4pt} Dayrate drift constant & $\\kappa^D_0$ & %8.2g &  \\\\ \n' ,obj.PDcoefs(5));
fprintf(fid,'\\hspace{4pt} Dayrate drift linear term & $\\kappa^D_1$ & $%.2f \\times 10^{%1.0f}$  &  \\\\ \n' ,[obj.PDcoefs(6) ./ (10.^floor(log10(abs(obj.PDcoefs(6))))),floor(log10(abs(obj.PDcoefs(6))))]);
fprintf(fid,'\\hspace{4pt} Dayrate volatility & $\\sigma^D$ & %8.2g &  \\\\ \n' ,obj.PDcoefs(9));
fprintf(fid,'\\hspace{4pt} Price - dayrate correlation & $\\rho$ & %8.3g &  \\\\ \n' ,obj.PDcoefs(12)); 
fprintf(fid,'\\midrule \n');
fprintf(fid, '\\textbf{Taxes and operating / gathering costs} &  & & \\citet{bib:gulen} \\\\ \n');
fprintf(fid,'\\hspace{4pt} Severance taxes & $s$ & %.0f\\%% of revenues & \\\\ \n' , obj.sevrate*100);
fprintf(fid,'\\hspace{4pt} Federal and state income taxes & $\\tau$ & %8.3g\\%% of income & \\\\ \n' , obj.itax_rate*100);
fprintf(fid,'\\hspace{4pt} Effective income tax on capital expenditure & $\\tau_c$ & %8.3g\\%% of income & \\\\ \n' , obj.itax_ratecap*100);
fprintf(fid,'\\hspace{4pt} Operating and gathering costs & $c$ & $\\$ %8.2f $ / mmBtu & \\\\ \n' , obj.opcost);
fprintf(fid,'\\midrule \\midrule \n');
fprintf(fid,'\\textbf{Well productivity} & $\\theta \\sim F(\\theta)$ & mmBtu & Analysis of production and water use data  \\\\ \n');
fprintf(fid,'\\hspace{4pt} Coefficient on water input & $\\beta$ & %8.2g & \\\\ \n' , obj.beta);
fprintf(fid,'\\hspace{4pt} Mean of $\\ln(\\theta)$ & $\\mu_{\\theta}$ & %8.2f & \\\\ \n' , obj.muLogX+log(1e7));
fprintf(fid,'\\hspace{4pt} SD of $\\ln(\\theta)$ & $\\sigma_{\\theta}$ & %8.2g & \\\\ \n' , obj.sigmaLogX);
fprintf(fid,'\\midrule \n');
fprintf(fid,'\\textbf{Drilling and completion costs} &  & &  \\\\ \n');
fprintf(fid,'\\hspace{4pt} Water price & $P_w$ & $\\$ %8.2f $ / gallon & Fit profits at optimal vs actual water use \\\\ \n' , obj.P_w);
fprintf(fid,'\\hspace{4pt} Dayrate coefficient & $\\alpha_1$ &  %8.0f  days & Project reported well cost data onto dayrates \\\\ \n' ,obj.thetaDR*1e7);
fprintf(fid,'\\hspace{4pt} Intercept & $\\alpha_0$ & $\\$ %8.1f $ million & Maximum likelihood fit to drilling data \\\\ \n' ,obj.thetaD*10+obj.thetaDA*10);
fprintf(fid,'\\hspace{4pt} Cost shock scale parameter & $\\sigma_{\\nu}$ & $\\$ %8.1f $ million & Maximum likelihood fit to drilling data \\\\ \n' ,params.epsScale_pretax*10);
fprintf(fid,'\\midrule \n');
fprintf(fid,'\\end{tabular}');
% Close file  
fclose(fid);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Single number tex files

% Severance tax rate
fid = fopen([dirs.singlenumdir,'/sevtax.tex'],'w');
fprintf(fid,'%8.0f\\%%', obj.sevrate*100);
fclose(fid);
% Corp tax rate
fid = fopen([dirs.singlenumdir,'/corptax.tex'],'w');
fprintf(fid,'%8.1f\\%%', obj.itax_rate*100);
fclose(fid);
% Corp tax rate on capex
fid = fopen([dirs.singlenumdir,'/corptax_capex.tex'],'w');
fprintf(fid,'%8.1f\\%%', obj.itax_ratecap*100);
fclose(fid);
% Opex
fid = fopen([dirs.singlenumdir,'/opcost.tex'],'w');
fprintf(fid,'$\\$ %8.2f $/mmBtu', obj.opcost);
fclose(fid);

% Drilling cost intercept from projection
fid = fopen([dirs.singlenumdir,'/dcost_alpha0.tex'],'w');
fprintf(fid,'$\\$ %8.1f $', obj.thetaD*10);
fclose(fid);
% Drilling cost coef on dayrate
fid = fopen([dirs.singlenumdir,'/dcost_alpha1.tex'],'w');
fprintf(fid,'%8.0f', obj.thetaDR*1e7);
fclose(fid);
% Avg dayrate in 2010
ind = obj.pddata0(:,1)==2010;
DR2010 = mean(obj.pddata0(ind,5));
fid = fopen([dirs.singlenumdir,'/dayrate2010.tex'],'w');
fprintf(fid,'$\\$ %8.0f $', DR2010);
fclose(fid);
% Avg drilling cost in 2010
fid = fopen([dirs.singlenumdir,'/dcost_2010.tex'],'w');
fprintf(fid,'$\\$ %8.1f $', obj.thetaD*10+obj.thetaDR*10*DR2010);
fclose(fid);

% Water coef
fid = fopen([dirs.singlenumdir,'/betaw.tex'],'w');
fprintf(fid,'%8.2f', obj.beta);
fclose(fid);
% Water price
fid = fopen([dirs.singlenumdir,'/P_w.tex'],'w');
fprintf(fid,'$\\$ %8.2f $/gallon', obj.P_w);
fclose(fid);

% Total drilling cost intercept
fid = fopen([dirs.singlenumdir,'/dcosttotal_alpha0.tex'],'w');
fprintf(fid,'$\\$ %8.1f $', obj.thetaD*10+obj.thetaDA*10);
fclose(fid);
% Scale parameter on shocks
fid = fopen([dirs.singlenumdir,'/epsScale.tex'],'w');
fprintf(fid,'$\\$ %8.1f $', params.epsScale_pretax*10);
fclose(fid);

% Sample selection unit counts
unitestsamplefile = [dirs.db,'IntermediateData/CalibrationCoefs/unitestsampleinfo.csv'];
unitestsampleinfo = csvread(unitestsamplefile,1,0);
% Initial N
fid = fopen([dirs.singlenumdir,'/N0.tex'],'w');
fprintf(fid,'%8.0f', unitestsampleinfo(2));
fclose(fid);
% Final N
fid = fopen([dirs.singlenumdir,'/Nfinal.tex'],'w');
fprintf(fid,'%8.0f', unitestsampleinfo(8));
fclose(fid);
% Drops due to well caliper
fid = fopen([dirs.singlenumdir,'/Ndropwells.tex'],'w');
fprintf(fid,'%8.0f', unitestsampleinfo(3));
fclose(fid);
% Drops due to no royalty
fid = fopen([dirs.singlenumdir,'/Ndroproy.tex'],'w');
fprintf(fid,'%8.0f', unitestsampleinfo(4));
fclose(fid);
% Drops due to increasing acres
fid = fopen([dirs.singlenumdir,'/Ndropinc.tex'],'w');
fprintf(fid,'%8.0f', unitestsampleinfo(5));
fclose(fid);
% Drops due to <160 acres
fid = fopen([dirs.singlenumdir,'/Ndrop160.tex'],'w');
fprintf(fid,'%8.0f', unitestsampleinfo(6));
fclose(fid);
% Drops due to drilling with zero acres
fid = fopen([dirs.singlenumdir,'/Ndropzeroacres.tex'],'w');
fprintf(fid,'%8.0f', unitestsampleinfo(7));
fclose(fid);

% Number of units drilled
Ndrilled = sum(sum(obj.obsSpud),2);
fid = fopen([dirs.singlenumdir,'/Nunitsdrilled.tex'],'w');
fprintf(fid,'%8.0f', Ndrilled);
fclose(fid);

% Wells per unit
wellsperunitfile = [dirs.db,'IntermediateData/CalibrationCoefs/Wellsperunit.csv'];
wellsperunit = csvread(wellsperunitfile,0);     % wells per unit
fid = fopen([dirs.singlenumdir,'/WellsPerUnit.tex'],'w');
fprintf(fid,'%8.0f', round(wellsperunit));
fclose(fid);

% muLogTheta and sigmaLogTheta
fid = fopen([dirs.singlenumdir,'/muLogTheta.tex'],'w');
fprintf(fid,'%8.2f', obj.muLogX+log(1e7));
fclose(fid);
fid = fopen([dirs.singlenumdir,'/sigmaLogTheta.tex'],'w');
fprintf(fid,'%8.2f', obj.sigmaLogX);
fclose(fid);
fid = fopen([dirs.singlenumdir,'/sigmaLogTheta_1.96.tex'],'w');
fprintf(fid,'%8.2f', obj.sigmaLogX*1.96);
fclose(fid);
% mmBtu at muLogTheta
averagewaterfile = [dirs.db,'IntermediateData/CalibrationCoefs/AverageWater.csv'];
AvgWater = csvread(averagewaterfile,0);
MedianmmBtu = exp(obj.muLogX+log(1e7)) * AvgWater^obj.beta;
fid = fopen([dirs.singlenumdir,'/medianmmBtu.tex'],'w');
fprintf(fid,'%8.1f', MedianmmBtu/1e6);
fclose(fid);

% Average drilling hazard in the sample
T = size(obj.obsSpud,2);        % total number of quarters
Ti = obj.dataSpudy*4 + obj.dataSpudq + 1 - obj.starty*4 - obj.startq;   % time to drill
Ti(Ti<0) = T;                   % units never drilled
avghaz = Ndrilled / sum(Ti);    % avg hazard
fid = fopen([dirs.singlenumdir,'/avghaz.tex'],'w');
fprintf(fid,'%8.1f\\%%', avghaz*100);
fclose(fid);
% Drilling intercept conditional on drilling, given average hazard
Euler = 0.5772;     % Euler's constant
shift = gevinv(1-avghaz,0,params.epsScale_pretax,-Euler);  % avg shock for well on margin
fid = fopen([dirs.singlenumdir,'/dcosttotalcond_alpha0.tex'],'w');
fprintf(fid,'$\\$ %8.1f $', obj.thetaD*10+obj.thetaDA*10-shift*10);
fclose(fid);

% Gas price in 1Q 2010
P2010_1 = obj.pddata0(obj.pddata0(:,1)==2010&obj.pddata0(:,2)==1,4);
fid = fopen([dirs.singlenumdir,'/P2010_1.tex'],'w');
fprintf(fid,'$\\$ %8.2f $', P2010_1);
fclose(fid);
% Dayrate in 1Q 2010
DR2010_1 = obj.pddata0(obj.pddata0(:,1)==2010&obj.pddata0(:,2)==1,5);
fid = fopen([dirs.singlenumdir,'/DR2010_1.tex'],'w');
fprintf(fid,'$\\$ %8.0f $', DR2010_1);
fclose(fid);

