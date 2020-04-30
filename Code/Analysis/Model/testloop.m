% testloop.m
% Ryan Kellogg
% Created: 12 April, 2020


%{
This is code for testing functionality and output of the model.
Simulates the model for a few different lease cases
%}



clear all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Call simsetup.m to define directories and input parameters, instantiate
% the model, and simulate outcomes under a socially optimal lease
simsetup



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set up grid of lease terms for runs with 1 well
LEASETERMS = [0.5 0.1 0 0; 0.5 0.1 0.01 0; 0.5 0.1 0 3; 0.5 0.1 0.01 3];

% Run simulations
[EVLessorBMat,EVTotalBMat,~,ShareFirmsMat,EVBonusMat,...
    EDrillHazBMat,EDrillProbBMat,EProdBMat,EWaterBMat,...
    ~,~,~,~]...
    = SimLoop(obj,dirs,params,LEASETERMS,REPORTT);

% Create plot-friendly matrices of main results
[plotEVSocialOpt,plotEVLessor,plotEVTotal,plotEVBonus,plotShareFirms,...
            plotEDrillHazSocialOpt,plotEDrillProbSocialOpt,...
            plotEDrillHazB,plotEDrillProbB,plotEProdSocialOpt,plotEWaterSocialOpt,...
            plotEProdB,plotEWaterB,P0,P0H,P0L,DR0]...
            = PlotMatrices(obj,EVLessorBMat,EVTotalBMat,ShareFirmsMat,EVBonusMat,...
            EDrillHazBMat,EDrillProbBMat,EProdBMat,EWaterBMat,...
            SO_EVTotal,SO_EDrillHaz,SO_EDrillProb,SO_EProd,SO_EWater);

        

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Re-run with 3 wells
params.Wells = 3;     % wells per unit

% Re-run social opt
SO_LEASETERMS = [0 0 0 0];
[~,~,SO_EVTotal,~,~,...
    ~,~,~,~,...
    SO_EDrillHaz,SO_EDrillProb,SO_EProd,SO_EWater]...
    = SimLoop(obj,dirs,params,SO_LEASETERMS,REPORTT); 

% Run simulations
[EVLessorBMat3,EVTotalBMat3,~,ShareFirmsMat3,EVBonusMat3,...
    EDrillHazBMat3,EDrillProbBMat3,EProdBMat3,EWaterBMat3,...
    ~,~,~,~]...
    = SimLoop(obj,dirs,params,LEASETERMS,REPORTT);

% Create plot-friendly matrices of main results
[plotEVSocialOpt3,plotEVLessor3,plotEVTotal3,plotEVBonus3,plotShareFirms3,...
            plotEDrillHazSocialOpt3,plotEDrillProbSocialOpt3,...
            plotEDrillHazB3,plotEDrillProbB3,plotEProdSocialOpt3,plotEWaterSocialOpt3,...
            plotEProdB3,plotEWaterB3,P03,P0H3,P0L3,DR03]...
            = PlotMatrices(obj,EVLessorBMat3,EVTotalBMat3,ShareFirmsMat3,EVBonusMat3,...
            EDrillHazBMat3,EDrillProbBMat3,EProdBMat3,EWaterBMat3,...
            SO_EVTotal,SO_EDrillHaz,SO_EDrillProb,SO_EProd,SO_EWater);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Save workspace
outfile = [dirs.outputdir,'testloop_SimResults'];   
save(outfile);



















        
        
