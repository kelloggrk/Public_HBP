%% The class that instantiates the hbpmodelwaterest object 
% Subclass of hbpmodel that is used for estimating P_w
classdef hbpmodelwaterest < hbpmodel
properties
    % We specify here all of the properties we want to have
    % attached to each object

end
    
methods
    %% Constructor
    function obj = hbpmodelwaterest(dirs,params,Pi,DRi,Xi,royi)
        % Object defns from superclass
        obj = obj@hbpmodel(dirs,params);
        
        % Single price and dayrate states
        obj.Prices = Pi;
        obj.DR = DRi;
        obj.PDR = [Pi DRi];
        obj.nP = 1; obj.nD = 1;
        
        % Productivity and royalty (LC = 0)
        obj.dataX = Xi;     % production in 10^7 mmBtu
        obj.dataR = royi;
        obj.dataLC = 0;
        obj.N = 1;

        % Drilling costs during max(time-to-build,pri term) and
        % during infinite horizon
        [obj.DC, obj.DCInf] = DrillCosts(obj);  
    end
    
    
    
    %% Compute avg squared diff in profits at optimal vs observed water over all wells
    function [dist,b,meanpi] = PiDist(objw,welldata,AllWell_CostWaterDayrate,Pwi)
        % Outputs:
        % dist: root mean squared (profit at optimal water - profit at observed water)
        % b: 2x1 coefficients from projection of drilling cost (minus water) on
        % a constant and the dayrate. For obj.thetaD and obj.thetaDR.
        % meanpi: average profits at optimal water use ($10m)
        
        % Inputs:
        % Pwi: water price ($/gal)
        % welldata: nW by 10 matrix of inputs for wells in calibration sample. Inputs are:
        % 1: well id
        % 2: spud date
        % 3: well cost ($10m)
        % 4: water use (gal)
        % 5: productivity (10^7 mmBtu)
        % 6: royalty (fraction)
        % 7: spud date in unit time
        % 8: leased acreage share
        % 9: gas price at spud ($/mmBtu)
        % 10: dayrate at spud ($/day)
        % AllWell_CostWaterDayrate: nW0 by 3 matrix of data for all wells. Inputs are:
        % 1: well cost ($10m)
        % 2: water use (gal)
        % 3: dayrate at spud ($/day)
        
        nW = size(welldata,1);      % number of wells
        PiOpt = zeros(nW,1); PiObs = zeros(nW,1);       % initialize
        
        % Obtain drilling cost coefs by regressing drill cost - water cost on dayrate
        % Use full sample
        nW0 = size(AllWell_CostWaterDayrate,1);     % number of wells in full sample
        CostNoWater = AllWell_CostWaterDayrate(:,1) - Pwi * AllWell_CostWaterDayrate(:,2) / 1e7;
        b = regress(CostNoWater,[ones(nW0,1) AllWell_CostWaterDayrate(:,3)]);   % regression
        
        % Set water price and drilling cost properties in object
        objw.P_w = Pwi;
        objw.thetaD = b(1);     % drilling cost constant
        objw.thetaDR = b(2);    % coefficient on dayrate
        
        % Loop over wells. For each well, instantiate object and obtain
        % profits at both optimal and observed water
        for w = 1:nW
            Pi = welldata(w,9);
            DRi = welldata(w,10);
            Xi = welldata(w,5);
            royi = welldata(w,6);
            % Update object with values above
            objw.Prices = Pi; objw.DR = DRi;
            objw.PDR = [Pi DRi];
            objw.dataX = Xi;
            objw.dataR = royi;
            [objw.DC, objw.DCInf] = DrillCosts(objw);  
            % Obtain profits at optimal water use
            [PiOpt(w), ~, ~, ~] = Payoffst(objw,welldata(w,7),welldata(w,8));
            % Obtain profits at actual water use
            [PiObs(w), ~, ~, ~] = Payoffst(objw,welldata(w,7),welldata(w,8),welldata(w,4));            
        end
        
        dist = sqrt(mean((PiOpt - PiObs).^2));
        meanpi = mean(PiOpt);
        
    end

end
end

