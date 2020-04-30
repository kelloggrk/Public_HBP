% simsetup.m
% Ryan Kellogg
% Created: 19 January, 2020


%{
This is setup code that is shared across all files running counterfactual
simulations.

High-level order of operations is:
1. Define key parameters to input into the model
2. Instantiate the simulation subclass of the model
3. Simulate outcomes under a socially optimal lease
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
dirs.figscratchdir = strcat(dirs.outputdir,'figures/');
dirs.figfinaldir = strcat(repodir,'/Paper/Figures/simulations/');
dirs.figbeamerdir = strcat(repodir,'/Paper/Beamer_Figures/simulations/');
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
%% Load royalty and pri term for optimal lease (in terms of lessor val)
optrtfile = [dirs.outputdir,'optroyaltypriterm.csv'];
optrt = csvread(optrtfile);
optr = optrt(1); optT = optrt(2);   % opt royalty and pri term (years)
clear optrtfile optrt



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set number of years to simulate drilling probabilities
% This should be at least the longest primary term simulated
REPORTT = 15;       % years



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Simulate outcomes for socially optimal lease
% No contingent payments, primary term, or bonus
% Key outputs from this have variable names starting with SO_ prefix
SO_LEASETERMS = [0 0 0 0];
[~,~,SO_EVTotal,~,~,...
    ~,~,~,~,...
    SO_EDrillHaz,SO_EDrillProb,SO_EProd,SO_EWater]...
    = SimLoop(obj,dirs,params,SO_LEASETERMS,REPORTT);        































        
        
