%% EstimateDecline.m
%   Take monthly data on cumulative production
%   Estimate parameters of 2-stage decline curve
%   Tau and d are common to all wells
%   M is the "well fixed effect"
%   Written by: Evan Herrnstadt
%   Created:    25 Sept. 2018

%% Set up filepaths %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all
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

spec.wdir = [repodir '/Code/Analysis/Louisiana/Productivity'];
spec.texdir = [repodir '/Paper/Figures/single_numbers_tex'];
spec.dropbox = [dropbox '/IntermediateData/Louisiana/DIProduction'];
addpath(genpath(spec.wdir))

%% Read in data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tempNum = csvread([spec.dropbox, '/time_series_4_decline_estimation.csv'],1,0);
data.t          = tempNum(:,3);
% Keep only production after first 3 months
ok = data.t > 3;
data.t          = data.t(ok);
data.wellID     = tempNum(ok,2);
data.cumProd    = tempNum(ok,4);

NominalR    = 0.125;                            % nominal discount rate
Inflation   = 0.023;                            % inflation rate
RealR       = (1+NominalR) / (1+Inflation) - 1; % convert to real
param.delta = 1./(1 + RealR);                   % discount factor (annual)
param.T     = 240;                              % Lifetime (months)


spec.option = optimoptions(@lsqnonlin, ...
                           'display',                   'iter', ...
                           'maxIterations',             500, ...
                           'maxFunctionEvaluations',    1e+5, ...
                           'functionTolerance',         1e-14,...
                           'stepTolerance',             1e-14,...
                           'optimalityTolerance',       1e-6,...
                           'SpecifyObjectiveGradient',  true);

tauVec = [12*1.18, 30];                          % Interference Period
for tt = 1:numel(tauVec)

    param.tau = tauVec(tt);

    %% Estimate decline curve, fix initial decline %%%%%%%%%%%%%%%%%%%%%%%%%
    [wells, ~, wellIDX] = unique(data.wellID);

    % Start values are [d2*100, M / 1e6]
    startVal    = [5;       1 * ones(numel(wells),1)];
    scaleVec    = [0.01;    1e6 * ones(numel(wells),1)];

    param.d1   = 0.5;

    fcn = @(x) DeclineFcn_FixD1(x, data, param.d1, param.tau, wellIDX, scaleVec);
    [decline, diff, ~, exitflag] = lsqnonlin(fcn,startVal,zeros(size(startVal)),[],spec.option);

    decline = decline .* scaleVec;
    paramOut{1,tt}          = param;
    paramOut{1,tt}.diff     = diff;
    paramOut{1,tt}.exitflag = exitflag;
    paramOut{1,tt}.d1       = param.d1;
    paramOut{1,tt}.d2       = decline(1);
    paramOut{1,tt}.M        = decline(2:end);

    %% Estimate decline curve, estimate initial decline %%%%%%%%%%%%%%%%%%%%%%%%%
    [wells, ~, wellIDX] = unique(data.wellID);

    % Start values are [d1, d2*100, M / 1e6]
    startVal    = [0.5; 5;      1 * ones(numel(wells),1)];
    scaleVec    = [1;   0.01;   1e6 * ones(numel(wells),1)];

    fcn = @(x) DeclineFcn_EstD1(x, data, param.tau, wellIDX, scaleVec);
    [decline, diff, ~, exitflag] = lsqnonlin(fcn,startVal,zeros(size(startVal)),[],spec.option);

    decline = decline .* scaleVec;
    paramOut{2,tt}          = param;
    paramOut{2,tt}.diff     = diff;
    paramOut{2,tt}.exitflag = exitflag;
    paramOut{2,tt}.d1       = decline(1);
    paramOut{2,tt}.d2       = decline(2);
    paramOut{2,tt}.M        = decline(3:end);

    %% Project lifetime production %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Compute discounted expected lifetime production (param.T months)
    [totProd{1,tt} discProd{1,tt}]  = LifetimeProd(paramOut{1,tt});
    [totProd{2,tt} discProd{2,tt}]  = LifetimeProd(paramOut{2,tt});
end

% Save to csv
tableOut = table(wells,discProd{1,1}',discProd{1,2}',discProd{2,1}',discProd{2,2}',...
            'VariableNames',{'well_id','disc_prod_1','disc_prod_2','disc_prod_3','disc_prod_4'});

writetable(tableOut,[spec.dropbox '/disc_prod_patzek.csv']);


for i=1:2
    for j=1:2
        tau(j+(i-1)*2,1) = paramOut{i,j}.tau;
        d1(j+(i-1)*2,1) = paramOut{i,j}.d1;
        d2(j+(i-1)*2,1) = paramOut{i,j}.d2;
        exitflag(j+(i-1)*2,1) = paramOut{i,j}.exitflag;
        totProdMean(j+(i-1)*2,1) = mean(totProd{i,j});
        totProdMedian(j+(i-1)*2,1) = median(totProd{i,j});
        discProdMean(j+(i-1)*2,1) = mean(discProd{i,j});
        discProdMedian(j+(i-1)*2,1) = median(discProd{i,j});
    end
end


tableParam = table(tau,d1,d2,exitflag,totProdMean,totProdMedian,discProdMean,discProdMedian,...
            'VariableNames',{'tau','d1','d2','exitflag','totProdMean','totProdMedian','discProdMean','discProdMedian'});

writetable(tableParam,[spec.dropbox '/decline_table.csv']);

%%%%%%%% Write in-text numbers %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Decline rate from fixed case with 14.16 month intital period
fid = fopen([spec.texdir '/decline_parameter_d.tex'],'w');
d_out = fprintf(fid, '%8.3f', paramOut{1,1}.d2);
fclose(fid);

% Annual discount rate
fid = fopen([spec.texdir '/decline_annual_disc.tex'],'w');
d_out = fprintf(fid, '%8.3f', param.delta);
fclose(fid);

% Monthly discount rate
fid = fopen([spec.texdir '/decline_monthly_disc.tex'],'w');
d_out = fprintf(fid, '%8.3f', param.delta^(1/12));
fclose(fid);

% Quantiles of m (millions of mmBtu)
m25 = quantile(paramOut{1,1}.M,0.25);
m50 = quantile(paramOut{1,1}.M,0.50);
m75 = quantile(paramOut{1,1}.M,0.75);

fid = fopen([spec.texdir '/decline_m_p25.tex'],'w');
d_out = fprintf(fid, '%8.2f', m25/1e6);
fclose(fid);

fid = fopen([spec.texdir '/decline_m_p50.tex'],'w');
d_out = fprintf(fid, '%8.2f', m50/1e6);
fclose(fid);

fid = fopen([spec.texdir '/decline_m_p75.tex'],'w');
d_out = fprintf(fid, '%8.2f', m75/1e6);
fclose(fid);





