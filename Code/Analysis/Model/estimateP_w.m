% estimateP_w.m
% Ryan Kellogg
% Created: 10 January, 2020


%{
This is the top-level script for estimating the price of water P_w

High-level order of operations is:
1. Define key parameters to input into the model
2. Bring in Haynesville well data from CostProjectionData.csv
3. Instantiate the superclass of the model
4. Match well data to selected units of the superclass
5. For each guess of P_w, loop over wells, creating a hbpmodelwaterest
subclass for each well and calling the Payoffst method to obtain profits at
the optimal and observed water use
6. Choose P_w to minimize the distance between profits at optimal and
observed water use
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
dirs.outputdir = strcat(dropbox, '/Scratch/simresults/');
dirs.figscratchdir = strcat(dirs.outputdir,'figures/');
dirs.figfinaldir = strcat(repodir,'/Paper/Figures/');
dirs.singlenumdir = strcat(repodir,'/Paper/Figures/single_numbers_tex/calibration/');
dirs.db = strcat(dropbox,'/');

% Add all code files (including utilities) to matlab search path
addpath(genpath(dirs.wdir))



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Load productivity, drilling cost, and shock parameters into params struct
% and instantiate hbpmodel superclass

% Water use parameters
betafile = [dirs.db,'IntermediateData/CalibrationCoefs/cobb_douglas.csv'];
Pwfile = [dirs.db,'IntermediateData/CalibrationCoefs/P_w.csv'];
params.beta = csvread(betafile,1);  % exponent on water in prod function
params.P_w = csvread(Pwfile,1);     % initial guess for "price" of water. 

% Drilling cost parameters
costcoefsfile = [dirs.db,'IntermediateData/CalibrationCoefs/CostCoefsProj.csv'];
costcoefs = csvread(costcoefsfile,1);
params.thetaD = costcoefs(2)/1e7;   % initial guess for fixed cost of drilling
params.thetaDR = costcoefs(1)/1e7;  % initial guess of dayrate multiplier parameter

% Set scale choice-specific logit cost shocks (pre-tax values)
params.epsScale_pretax = costcoefs(3)/1e7;

clear betafile Pwfile costcoefs*

% Time to build
params.thetaTTB = 0;      % time-to-build cost at unit start ($10m)
params.thetaTTBt = 2;       % length of time to build period (years)

% Wells per unit (does not affect results of this routine)
params.Wells = 1;    

% Instantiate superclass model
obj = hbpmodel(dirs,params);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Load well completion data and match to the unit data in obj

% Load in well completion data
wellfile = [dirs.db,...
    'IntermediateData/StructuralEstimationData/CostProjectionData.csv'];
welldata0 = csvread(wellfile,1,0);
clear wellfile
nW0 = size(welldata0,1);

% Compute spud quarter, counting from obj.starty and obj.startq
welldata0(:,8) = welldata0(:,4) * 4 + welldata0(:,3) - (obj.starty*4 + obj.startq) + 1;

% Capture price and dayrate at the spud date
t = welldata0(:,8) + obj.starti - 1;    % time in quarters; start of obj.pddata0 is 1
welldata0(:,9) = obj.pddata0(t,4);      % price ($/mmBtu)
welldata0(:,10) = obj.pddata0(t,5);     % dayrate ($/day)


% Loop through rows of welldata0, see if there is a match in the unit data,
% and if spudding occurred in 2010Q1 (starty and startq) or later
% If so create a row in welldata containing necessary well and unit info
welldata = zeros(nW0,10);       % initialize final well data matrix
welldataunits = zeros(nW0,1);   % initialize final list of unit IDs
nW = 0;                         % initialize number of wells
for w = 1:nW0
    unitw = welldata0(w,2);     % unit ID
    ind = find(obj.dataID==unitw);
    if isempty(ind) || welldata0(w,8)<1  % ignore well and move on
    else
        nW = nW + 1;    % row index in welldata
        welldata(nW,1) = w;                     % well ID
        welldata(nW,2) = welldata0(w,8);        % spud date (1 = 2010 Q1)
        welldata(nW,3) = welldata0(w,5) / 1e7;  % well cost ($10m)
        welldata(nW,4) = welldata0(w,6);        % water use (gal)
        welldata(nW,5) = obj.dataX(ind);        % productivity (10^7 mmBtu)
        welldata(nW,6) = obj.dataR(ind);        % royalty (fraction)
        unitstart = obj.dataT0i(ind);           % unit start qtr (start of obj.pddata0 is 1)
        % spud date in unit time (1 = quarter just after unit starts)
        welldata(nW,7) = (welldata(nW,2) + obj.starti - 1) - unitstart;
        % Get leased acreage when first well in unit was spudded
        lshare = obj.obsLshare(ind,:) * obj.obsSpud(ind,:)';
        welldata(nW,8) = lshare;
        welldataunits(nW) = unitw;
        % Get price and dayrate at the spud date
        welldata(nW,9) = welldata0(w,9);    % price ($/mmBtu)
        welldata(nW,10) = welldata0(w,10);  % dayrate ($/day)
    end
end

% Keep only observations where leased acreage > 0
keep = welldata(:,8)>0;
welldata_f = welldata(keep,:);
welldata = welldata_f;
clear welldata_f

% Get number of wells per unit conditional on multiple wells
welldataunits = welldataunits(1:nW);        % drop zeros
ucounts = accumarray(welldataunits,1);      % number of wells per unit
Nmw = sum(ucounts>1);                       % number of multi-well units
drilled = sum(sum(obj.obsSpud),2);          % number of units drilled at least once
AvgWellPerUnit = (nW - drilled + Nmw) / Nmw;   % avg # of wells/unit | >1
AvgWellPerUnit = round(AvgWellPerUnit);     % round

% For all wells, collect cost, water, and dayrate info
AllWell_CostWaterDayrate = [welldata0(:,5)/1e7 welldata0(:,6) welldata0(:,10)];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initialize "dummy" object to feed into PiDiff method
objw = hbpmodelwaterest(dirs,params,0,0,0,0);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Grid search over different water prices
Pwgrid = [0.2:0.01:0.6]';
Ng = length(Pwgrid);
DIST = zeros(Ng,1); B = zeros(Ng,2);
for i = 1:Ng
    [disti, bi, ~] = PiDist(objw,welldata,AllWell_CostWaterDayrate,Pwgrid(i));
    DIST(i) = disti;
    B(i,:) = bi';
end

% Capture value of Pw that gives smallest distance; use this as initial guess
Dmin = min(DIST);
ind = find(DIST==Dmin);
Pwguess = Pwgrid(ind);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Find water price that minimizes distance between opt and obs profits
% Define implict fuction to feed into fminsearch
ifun = @(x) PiDist(objw,welldata,AllWell_CostWaterDayrate,x);
P_w = fminsearch(ifun,Pwguess);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Save output

% Obtain profit distance, drilling cost projection coefs, and mean profit
% at optimal water use
[dist, b, meanpi] = PiDist(objw,welldata,AllWell_CostWaterDayrate,P_w);
thetaD = b(1); thetaDR = b(2);

% Export output
Pwfinalfile = [dirs.db,'IntermediateData/CalibrationCoefs/P_w_final.csv'];
costcoefsfinalfile = [dirs.db,'IntermediateData/CalibrationCoefs/CostCoefsFinal.csv'];
optprofitmeandistfile = [dirs.db,'IntermediateData/CalibrationCoefs/Profits_mean_dist.csv'];
wellsperunitfile = [dirs.db,'IntermediateData/CalibrationCoefs/Wellsperunit.csv'];
dlmwrite(Pwfinalfile, P_w, 'delimiter', ',', 'precision', 14);
dlmwrite(costcoefsfinalfile, [thetaD thetaDR], 'delimiter', ',', 'precision', 14);
dlmwrite(optprofitmeandistfile, [meanpi dist], 'delimiter', ',', 'precision', 14);
dlmwrite(wellsperunitfile, AvgWellPerUnit, 'delimiter', ',', 'precision', 14);

% Export single-number file with number of wells in sample
fid = fopen([dirs.singlenumdir,'/Nwells_Pw_est.tex'],'w');
fprintf(fid,'%8.0f', nW);
fclose(fid);
% average water use per well (export file for latex and one for csv)
AvgWater = mean(welldata(:,4));
fid = fopen([dirs.singlenumdir,'/AvgWater.tex'],'w');
fprintf(fid,'%8.1f', AvgWater/1e6);
fclose(fid);
averagewaterfile = [dirs.db,'IntermediateData/CalibrationCoefs/AverageWater.csv'];
dlmwrite(averagewaterfile,  AvgWater, 'delimiter', ',', 'precision', 14);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% For sensitivity: estimate of P_w at half of actual beta
paramss = params;                   % duplicate original parameters
paramss.beta = params.beta / 2;     % halve beta
objws = hbpmodelwaterest(dirs,paramss,0,0,0,0);     % new dummy object
% Need to scale up production coef to compensate
ProdMult = AvgWater^params.beta / AvgWater^paramss.beta;
welldatas = welldata;
welldatas(:,5) = welldatas(:,5) * ProdMult;     % scale up
% Define implict fuction to feed into fminsearch
ifuns = @(x) PiDist(objws,welldatas,AllWell_CostWaterDayrate,x);
P_ws = fminsearch(ifuns,P_w);
% Export new water price and scale up coefficient
P_w_halfbetafile = [dirs.db,'IntermediateData/CalibrationCoefs/P_w_halfbeta.csv'];
dlmwrite(P_w_halfbetafile, [P_ws ProdMult], 'delimiter', ',', 'precision', 14);

