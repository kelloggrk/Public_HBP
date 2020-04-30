% runML.m
% Ryan Kellogg
% Created: 1 December, 2019


%{
This is the top-level script for calling the log likelihood method from
hbpmodel.m and maximizing it

High-level order of operations is:
1. Define key parameters to input into the model
2. Bring in data from Haynesville units
3. Instantiate the superclass of the model
4. Calculate likelihoods, searching / looping over values to maximize it
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
dirs.figfinalbeamerdir = strcat(repodir,'/Paper/Beamer_Figures/');
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
params.thetaD = costcoefs(1);   % fixed cost of drilling
params.thetaDR = costcoefs(2);  % dayrate multiplier parameter

% Set scale choice-specific logit cost shocks (pre-tax values)
shockfile = [dirs.db,'IntermediateData/CalibrationCoefs/CostCoefsProj.csv'];
shocks = csvread(shockfile,1);
params.epsScale_pretax = shocks(3)/1e7;

clear betafile Pwfile costcoefs* shock*

% Time to build
params.thetaTTB = 0;        % time-to-build cost at unit start ($10m)
params.thetaTTBt = 2;       % length of time to build period (years)

% Wells per unit
wellsperunitfile = [dirs.db,'IntermediateData/CalibrationCoefs/Wellsperunit.csv'];
params.Wells = csvread(wellsperunitfile,0);     % wells per unit
clear wellsperunitfile



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Loop over values of thetaDA and epsScale_pretax and see how LL changes

% Create vectors of parameter values
f = [2.5:0.25:4.5]';      % multiplication factors for epsscale
d = [1.5:0.5:3.5]';       % additional drilling costs
fd = repmat(f,length(d),1);
fd(:,2) = kron(d,ones(length(f),1));

eps0 = params.epsScale_pretax;      % initial calibration
epsvec = fd(:,1) * eps0;
Nfd = length(fd);

% Initialize output
LLfd = zeros(Nfd,1); SumSimfd = zeros(Nfd,1);
SumActfd = zeros(Nfd,1); dropfd = zeros(Nfd,1);

% Loop over values and get LL at each value
for i = 1:Nfd
    i           % show progress
    params.epsScale_pretax = epsvec(i);
    params.thetaDA = fd(i,2);
    obj = hbpmodel(dirs,params);        % instantiate model
    % Get log likelihood
    [LLfd(i), SumSimfd(i), SumActfd(i), dropfd(i)] = RunLogLike(obj);
end

% Capture best value from grid search
maxLL0 = max(LLfd);
ind = find(LLfd==maxLL0);
epsguess = epsvec(ind); thetaDAguess = fd(ind,2);
xguess = [epsguess thetaDAguess];       % initial guess for maximization below



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Maximize the LL
% Define implict fuction to feed into fminsearch
ifun = @(x) -LoopLogLike(obj,dirs,params,x);

% Max LL
options = optimset('Display','iter','TolX',1e-5);
X = fminsearch(ifun,xguess,options);        % simplex method
params.epsScale_pretax = X(1); params.thetaDA = X(2);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Constrained maximization (for sensitivity analysis)
% First, use half of the epsScale_pretax found above, and solve for thetaDA
ifuncon = @(x) -LoopLogLike(obj,dirs,params,[params.epsScale_pretax/2,x]);
thetaDA_halfeps = fminsearch(ifuncon,params.thetaDA/2,options);	% search for thetaDA
% Next, set thetaDA=0 and solve for epsScale_pretax
ifuncon = @(x) -LoopLogLike(obj,dirs,params,[x,0]);
epsScale_zerothetaDA = fminsearch(ifuncon,params.epsScale_pretax/4,options);	% search for epsScale



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Save output

% Save epsScale and thetaDA parameters
epsScalefile = [dirs.db,'IntermediateData/CalibrationCoefs/epsScale_final.csv'];
thetaDAfinalfile = [dirs.db,'IntermediateData/CalibrationCoefs/thetaDA_final.csv'];
dlmwrite(epsScalefile, params.epsScale_pretax, 'delimiter', ',', 'precision', 14);
dlmwrite(thetaDAfinalfile, params.thetaDA, 'delimiter', ',', 'precision', 14);

% Save LL and observed vs sim drilling
obj = hbpmodel(dirs,params);
[LL, SumSim, SumAct, drop, ProbMat0, SpudMat0] = RunLogLike(obj);
runMLoutputfile = [dirs.db,'IntermediateData/CalibrationCoefs/runMLout.csv'];
fileid = fopen(char(runMLoutputfile),'w');
fprintf(fileid,'LL,ActWellsDrilled,SimWellsDrilled \n');
fprintf(fileid,'%3.6f,%3.0f,%3.6f',[LL SumAct SumSim]);
fclose('all');

% Save constrained max parameters
thetaDA_halfeps_file = [dirs.db,'IntermediateData/CalibrationCoefs/thetaDA_halfeps.csv'];
dlmwrite(thetaDA_halfeps_file, thetaDA_halfeps, 'delimiter', ',', 'precision', 14);
epsScale_zerothetaDA_file = [dirs.db,'IntermediateData/CalibrationCoefs/epsScale_zerothetaDA.csv'];
dlmwrite(epsScale_zerothetaDA_file, epsScale_zerothetaDA, 'delimiter', ',', 'precision', 14);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plots showing fit between simulated vs acutal drilling

% First drop units where likelihood was zero
ProbSpudMat = SpudMat0 .* ProbMat0;
UnitLike0 = sum(ProbSpudMat')';      % likelihood of outcome for each unit
ind = UnitLike0>0;       % units with strictly positive likelihood
clear ProbSpudMat UnitLike0
ProbMat = ProbMat0(ind,:); SpudMat = SpudMat0(ind,:);

% Plot simulated and actual drilling vs time
T = size(ProbMat0,2)-1;         % number of periods of drilling
TT = 16;                        % number of periods to plot
simT = sum(ProbMat(:,1:TT))';    % total sim drilling over time
actT = sum(SpudMat(:,1:TT))';    % total act drilling over time
tvec = [1:TT]';
tvec = obj.starty + obj.startq/4 - 1/8 + (tvec - 1)/4;  % time in years (centered within quarters)
clf
str1 = [' Simulated drilling'];
str2 = [' Actual drilling'];
plot(tvec,simT,'-k','LineWidth',2,'DisplayName',str1); hold on        % sim drlg
plot(tvec,actT,'ok','MarkerSize',10,'DisplayName',str2);                % act drlg
grid; 
xlabel('Date');
ylabel('Wells drilled per quarter');
legend('Location','northeast');
lgd = legend;
lgd.FontSize = 30; 
hold off
h = gcf;
set(gca,'FontSize',30);
set(h,'PaperUnits','inches','PaperType','usletter')
set(h,'PaperOrientation','landscape','PaperPosition', [-0.3 0 11.7 9.1]);
outfile = strcat(dirs.figfinalbeamerdir, 'estimation/SimActDrillingVsTime.pdf');
print(h,outfile,'-dpdf');

% Plot formatted for paper
set(gca,'FontName','Times New Roman');
outfile = strcat(dirs.figfinaldir, 'estimation/SimActDrillingVsTime.pdf');
print(h,outfile,'-dpdf');
clear h

% Now set up unit-level plot of whether drilling happened or not (sim and
% actual) vs productivity
UnitProd = obj.dataX(ind);          % productivity (levels, 10^7 mmBtu)
UnitAct = sum(SpudMat(:,1:T),2);    % 0/1 whether unit was drilled
UnitSim = sum(ProbMat(:,1:T),2);    % total prob unit was drilled

% Create lowess smoothed fit of actual drilling to productivity
UnitActFit = fit([UnitProd ones(length(UnitAct),1)],UnitAct,'lowess','Span',1);
ya = feval(UnitActFit,[UnitProd ones(length(UnitAct),1)]);       % lowess fit to actual drilling
% Create lowess smoothed fit of simulated drilling to productivity
UnitSimFit = fit([UnitProd ones(length(UnitSim),1)],UnitSim,'lowess','Span',1);
ys = feval(UnitSimFit,[UnitProd ones(length(UnitSim),1)]);       % lowess fit to sim drilling

% Sort productivity in ascending order to plot line with fit
[UnitProdSort,I] = sort(UnitProd);      % sorted productivity
yaSort = ya(I); ysSort = ys(I);         % sorted lowess smooth

% Plot simulated drilling, actual drilling, and smoothed actual drilling
clf
str1 = [' Actual drilling'];
str2 = [' Lowess fit to actual drilling'];
str3 = [' Simulated drilling probability'];
str4 = [' Lowess fit to simulated drilling prob'];
plot(UnitProd*10,UnitAct,'ok','MarkerSize',10,'DisplayName',str1); hold on     % act drlg
plot(UnitProdSort*10,yaSort,'-k','LineWidth',2,'DisplayName',str2); hold on    % lowess fit to act
plot(UnitProd*10,UnitSim,'xk','MarkerSize',10,'DisplayName',str3);             % sim drlg
plot(UnitProdSort*10,ysSort,'--k','LineWidth',2,'DisplayName',str4); hold on   % lowess fit to act
axis([0 .25 0 1]); grid;
xlabel('Productivity coefficient (10^6 mmBtu)');
ylabel('Drilling probability');
legend('Location','northwest');
lgd = legend;
lgd.FontSize = 30; 
hold off
h = gcf;
set(gca,'FontSize',30);
set(h,'PaperUnits','inches','PaperType','usletter')
set(h,'PaperOrientation','landscape','PaperPosition', [-0.3 0 11.7 9.1]);
outfile = strcat(dirs.figfinalbeamerdir, 'estimation/SimActDrillingVsUnitProd.pdf');
print(h,outfile,'-dpdf');

% Plot formatted for paper
set(gca,'FontName','Times New Roman');
outfile = strcat(dirs.figfinaldir, 'estimation/SimActDrillingVsUnitProd.pdf');
print(h,outfile,'-dpdf');
clear h

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Single number file for number of simulated units drilled
fid = fopen([dirs.singlenumdir,'/Nunitsdrilled_sim.tex'],'w');
fprintf(fid,'%8.0f', SumSim);
fclose(fid);
