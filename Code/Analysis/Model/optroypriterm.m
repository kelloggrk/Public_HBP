% optroypriterm.m
% Ryan Kellogg
% Created: 8 November, 2019


%{
This is the top-level for finding the optimal royalty and primary term
combination for maximizing the lessor's value.
Assumes only 1 well per unit

High-level order of operations is:
1. Define key parameters to input into the model
2. Instantiate the simulation subclass of the model
3. Vary lease terms (royalty, primary term) and for each lease term,
simulate lessor value
4. Save all results and the optimal royalty + primary term
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
dirs.figfinaldir = strcat(repodir,'/Paper/Figures/');
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
%% Find optimal royalty and primary term; save output
% Define inline function that returns -EVlessor for best primary term, given royalty
ifun = @(x) -LessorValOptPriTerm(obj,dirs,params,x);
options = optimset('Display','iter','TolX',1e-3');
roystar = fminbnd(ifun,0,0.99,options);    % optimal royalty

% Recover optimal primary term at the optimal royalty
[EVLstar,Tstar,EVL_T0] = LessorValOptPriTerm(obj,dirs,params,roystar);

% Save opt royalty and pri term, expected value at opt and at inf pri term
optrt = [roystar Tstar EVLstar EVL_T0];
optrtfile = [dirs.outputdir,'optroyaltypriterm.csv'];
dlmwrite(optrtfile, optrt, 'delimiter', ',', 'precision', 14);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Sensitivities to different calibrations
% Half sigmaLogX
paramss = params;                   % duplicate original parameters
paramss.sigmaLogXmult = 0.5;        % multiplier on sigmaLogX
% Adjust mean productivity to compensate for change in sigmaLogX
paramss.ProdMult = exp(obj.sigmaLogX^2/2 - obj.sigmaLogX^2*paramss.sigmaLogXmult^2/2);
objs = hbpmodelsim(dirs,paramss);   % new model object
ifuns = @(x) -LessorValOptPriTerm(objs,dirs,paramss,x);
roystars = fminbnd(ifuns,0,0.99,options);   % optimal royalty
[EVLstars,Tstars,EVL_T0s] = LessorValOptPriTerm(objs,dirs,paramss,roystars);
R_halfsigmaLogX = [roystars; Tstars; EVLstars; EVL_T0s];

% One-fourth sigmaLogX
paramss = params;                   % duplicate original parameters
paramss.sigmaLogXmult = 0.25;       % multiplier on sigmaLogX
% Adjust mean productivity to compensate for change in sigmaLogX
paramss.ProdMult = exp(obj.sigmaLogX^2/2 - obj.sigmaLogX^2*paramss.sigmaLogXmult^2/2);
objs = hbpmodelsim(dirs,paramss);   % new model object
ifuns = @(x) -LessorValOptPriTerm(objs,dirs,paramss,x);
roystars = fminbnd(ifuns,0,0.99,options);   % optimal royalty
[EVLstars,Tstars,EVL_T0s] = LessorValOptPriTerm(objs,dirs,paramss,roystars);
R_quartersigmaLogX = [roystars; Tstars; EVLstars; EVL_T0s];

% Half beta_W
paramss = params;                   % duplicate original parameters
paramss.beta = params.beta / 2;     % halve beta
% Load P_w and production scale up that correspond to half beta
P_w_halfbetafile = [dirs.db,'IntermediateData/CalibrationCoefs/P_w_halfbeta.csv'];
[P_ws_ProdMult] = csvread(P_w_halfbetafile,0);
paramss.P_w = P_ws_ProdMult(1);
paramss.ProdMult = P_ws_ProdMult(2);
objs = hbpmodelsim(dirs,paramss);   % new model object
ifuns = @(x) -LessorValOptPriTerm(objs,dirs,paramss,x);
roystars = fminbnd(ifuns,0,0.99,options);   % optimal royalty
[EVLstars,Tstars,EVL_T0s] = LessorValOptPriTerm(objs,dirs,paramss,roystars);
R_halfbeta = [roystars; Tstars; EVLstars; EVL_T0s];
        
% Half epsScale
paramss = params;                   % duplicate original parameters
paramss.epsScale_pretax = params.epsScale_pretax / 2;     % halve epsScale
% Obtain thetaDA corresponding to half epsScale
thetaDA_halfepsscalefile = [dirs.db,'IntermediateData/CalibrationCoefs/thetaDA_halfeps.csv'];
paramss.thetaDA = csvread(thetaDA_halfepsscalefile,0);
objs = hbpmodelsim(dirs,paramss);   % new model object
ifuns = @(x) -LessorValOptPriTerm(objs,dirs,paramss,x);
roystars = fminbnd(ifuns,0,0.99,options);   % optimal royalty
[EVLstars,Tstars,EVL_T0s] = LessorValOptPriTerm(objs,dirs,paramss,roystars);
R_halfepsScale = [roystars; Tstars; EVLstars; EVL_T0s];        

% Zero thetaDA
paramss = params;                   % duplicate original parameters
paramss.thetaDA = 0;                % zero thetaDA
% Obtain epsScale associated with thetaDA = 0
epsScale_zerothetaDAfile = [dirs.db,'IntermediateData/CalibrationCoefs/epsScale_zerothetaDA.csv'];
paramss.epsScale_pretax = csvread(epsScale_zerothetaDAfile,0);
objs = hbpmodelsim(dirs,paramss);   % new model object
ifuns = @(x) -LessorValOptPriTerm(objs,dirs,paramss,x);
roystars = fminbnd(ifuns,0,0.99,options);   % optimal royalty
[EVLstars,Tstars,EVL_T0s] = LessorValOptPriTerm(objs,dirs,paramss,roystars);
R_zerothetaDA = [roystars; Tstars; EVLstars; EVL_T0s];  

% 33% greater productivity
paramss = params;                   % duplicate original parameters
paramss.ProdMult = 4/3;             % productivity multiplier
objs = hbpmodelsim(dirs,paramss);   % new model object
ifuns = @(x) -LessorValOptPriTerm(objs,dirs,paramss,x);
roystars = fminbnd(ifuns,0,0.99,options);   % optimal royalty
[EVLstars,Tstars,EVL_T0s] = LessorValOptPriTerm(objs,dirs,paramss,roystars);
R_ProdUp33 = [roystars; Tstars; EVLstars; EVL_T0s];  

% 33% lower productivity
paramss = params;                   % duplicate original parameters
paramss.ProdMult = 2/3;             % productivity multiplier
objs = hbpmodelsim(dirs,paramss);   % new model object
ifuns = @(x) -LessorValOptPriTerm(objs,dirs,paramss,x);
roystars = fminbnd(ifuns,0,0.99,options);   % optimal royalty
[EVLstars,Tstars,EVL_T0s] = LessorValOptPriTerm(objs,dirs,paramss,roystars);
R_ProdDown33 = [roystars; Tstars; EVLstars; EVL_T0s]; 

% Write matrix of sensitivity results
strvarnames = strcat('Half sigmaLogX,','One-fourth sigmaLogX,',...
    'Half beta_w,','Half epsScale,','Zero thetaDA,',...
    '33 higher prod,','33 lower prod \n');
csvout = [R_halfsigmaLogX'; R_quartersigmaLogX'; R_halfbeta';...
    R_halfepsScale'; R_zerothetaDA'; R_ProdUp33'; R_ProdDown33'];
filenameo = strcat(dirs.outputdir,'optroyaltypriterm_sensitivity.csv');
fileid = fopen(char(filenameo),'w');
fprintf(fileid,strvarnames);
fprintf(fileid,'%4.4f, %4.4f, %4.4f, %4.4f, %4.4f, %4.4f, %4.4f \n', csvout);
fclose('all');



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Optimal royalty and lessor cost
paramslc = params;      % replicate params struct
paramslc.T = 0;         % inf pri term
% Initial guess
LCguess = 0.3;
xguess = [roystar LCguess]; 

% Initialize dummy object and utility function
objlc = hbpmodelsim(dirs,paramslc);
ifunlc = @(x) -LessorVal_RoyLC(objlc,dirs,paramslc,x);
xstar = fminsearch(ifunlc,xguess,options);    % optimal royalty and LC

% Save opt royalty, lessor cost, and lessor value
EVLoptroylc = LessorVal_RoyLC(objlc,dirs,paramslc,xstar);
optroylc = [xstar EVLoptroylc];
optroylcfile = [dirs.outputdir,'optroyaltylessorcost.csv'];
dlmwrite(optroylcfile, optroylc, 'delimiter', ',', 'precision', 14);


