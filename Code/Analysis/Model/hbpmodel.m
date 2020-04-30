%% The class that instantiates the hbpmodel object
% Creates simulated data for estimation purposes
classdef hbpmodel
properties
    % We specify here all of the properties we want to have
    % attached to each object
    perYear
    delta
    opcost
    sevrate
    itax_rate
    itax_ratecap
    beta
    P_w
    thetaD
    thetaDR
    thetaTTB
    thetaTTBt
    thetaDA
    epsScale
    nP
    Prices
    Pc
    nD
    DR
    DRc
    PDR
    PDcoefs
    PDT
    pddata0
    Tpd0
    Wells
    obsLshare
    dataSpudy
    dataSpudq
    obsSpud
    dataID
    dataR
    dataLC
    dataRent
    dataLshare
    dataX
    dataT0y
    dataT0q
    dataT0i
    starty
    startq
    starti
    TU
    TMAX
    reportT
    N
    DC
    DCInf
    NL
    lsharevec
    maxit
end
    
methods
    %% Constructor
    function obj = hbpmodel(dirs,params)
        % Set periods per year and discount rate
        obj.perYear = 4;                         % number of periods in a year
        NominalR = 0.125;                        % nominal discount rate
        Inflation = 0.023;                       % inflation rate
        RealR = (1+NominalR) / (1+Inflation);    % convert to real
        delta_ann = 1 / RealR;                   % discount factor (annual)
        obj.delta = delta_ann^(1/obj.perYear);   % convert to per-period
        
        % Load actual prices and dayrates
        % Input data columns are: (1) year; (2) quarter; (3) oil price; (4) gas price; (5) dayrate
        % Oil and gas prices are 12 month futures. Prices and dayrates are real$2014
        pdfile = [dirs.db,'IntermediateData/PriceDayrate/PricesAndDayrates_Quarterly.csv'];
        obj.pddata0 = csvread(pdfile, 1, 0);
        obj.Tpd0 = size(obj.pddata0,1);     % number of actual price and dayrate obs

        % Tax policy and operating costs
        obj.opcost = 0.6;               % Operating cost, $/mmBtu. Gulen et al (2015)
        obj.sevrate = 0.04;             % severance tax rate
        obj.itax_rate = 0.402;          % combined fed + state tax. Gulen et al (2015)
        itax_IDCshare = 0.5;            % fraction of well cost that is intangible / expensable
        itax_deprecT = 7;               % years of depreciation for tangible cost
        
        % Compute effective income tax rate for drilling cost. obj.itax_ratecap
        % Share itax_IDCshare is expensed. The remainder is depreciated on the
        % double declining balance method for itax_deprecT years
        % Calculate depreciation share taken in each year for tangible part
        tangdep = zeros(itax_deprecT,1); Disctangdep = zeros(itax_deprecT,1); % initialize loop output
        double = 1;     % flag for double declining balance being better than straight line
        for t = 1:itax_deprecT
            if double==1    % calc double declining depreciation and straight line
                if t==1
                    dep_double = 2 / itax_deprecT;  % double rate on remaining balance
                    dep_str = 1 / itax_deprecT;
                else
                    dep_double = 2 / itax_deprecT * (1-sum(tangdep(1:t-1))); 
                    % check straight line on remaining balance
                    dep_str = (1-sum(tangdep(1:t-1))) / (itax_deprecT - (t-1));    
                end
                if dep_double > dep_str     % stay with double
                    tangdep(t) = dep_double;
                else                        % switch to straight line
                    tangdep(t) = dep_str;
                    double = 0;
                end
            else        % in straight line mode
                tangdep(t) = dep_str;
            end    
            Disctangdep(t) = tangdep(t) * obj.delta^((t-1)*obj.perYear);
        end
        % Compute effective tax rate on drilling and completion cost
        obj.itax_ratecap = obj.itax_rate * (itax_IDCshare + (1-itax_IDCshare)*sum(Disctangdep));

        % Water use parameters
        obj.beta = params.beta;
        obj.P_w = params.P_w;

        % Drilling cost parameters
        obj.thetaD = params.thetaD;
        obj.thetaDR = params.thetaDR;
        obj.thetaTTB = params.thetaTTB; % time-to-build cost at unit start
        tmp = params.thetaTTBt;         % length of time to build period (years)
        obj.thetaTTBt = tmp * obj.perYear;
        
        % Additional drilling cost. First check if this is inluded in the
        % params struct
        if sum(strcmp(fieldnames(params), 'thetaDA')) == 1
            obj.thetaDA = params.thetaDA;
        else
            obj.thetaDA = 0;
        end

        % Set scale choice-specific logit cost shocks (post-tax values)
        obj.epsScale = params.epsScale_pretax * (1-obj.itax_rate) * (1-obj.sevrate);

        % Price state space
        Pl = min(obj.pddata0(:,4)) / 2;     % min output price per mmBtu
        Ph = max(obj.pddata0(:,4)) * 2;     % max output price per mmBtu
        obj.nP = 50;                        % number of price steps
        Step = (Ph / Pl)^(1/(obj.nP-1));    % step length (geometric)
        obj.Prices = zeros(obj.nP,1);
        for i = 1:obj.nP
            obj.Prices(i) = Pl * Step^(i-1);
        end
        % Cutoff before next highest price (geometric mean between current price and next price)
        obj.Pc = (obj.Prices(1:obj.nP-1).*obj.Prices(2:obj.nP)).^0.5;
        obj.Pc(obj.nP) = inf;

        % Dayrate state space
        DRl = min(obj.pddata0(:,5)) / 2;        % min dayrate $/day
        DRh = max(obj.pddata0(:,5)) * 2;        % max dayrate $/day       
        obj.nD = 25;                            % number of dayrate steps
        Step = (DRh / DRl)^(1/(obj.nD-1));      % step length (geometric)
        obj.DR = zeros(obj.nD,1);
        for i = 1:obj.nD
            obj.DR(i) = DRl * Step^(i-1);
        end
        % Cutoff before next highest DR (geometric mean between current DR and next DR)
        obj.DRc = (obj.DR(1:obj.nD-1).*obj.DR(2:obj.nD)).^0.5;
        obj.DRc(obj.nD) = inf;      

        % Create nP*nD by 2 statespace (all combos of Prices and DR)
        obj.PDR = repmat(obj.Prices,obj.nD,1);
        obj.PDR(:,2) = kron(obj.DR,ones(obj.nP,1));

        % Price-dayrate state transition matrix coefficients
        pricedayratefile = [dirs.db,'IntermediateData/PriceDayrate/PriceTransitionCoefs.csv'];
        obj.PDcoefs = csvread(pricedayratefile, 1, 0)';  

        % If coefficients and state space are the same as the last
        % model run, load the saved P-D transition matrix.
        % Otherwise, run PDtrans method to create the matrix (PDT).
        statePDtransvec = [obj.Prices; obj.DR; obj.PDcoefs];
        statePDtransfile = [dirs.db,'IntermediateData/PriceDayrate/StateSpacePDTrans.csv'];
        % See if statePDtransfile exists, and if so compare to statePDtransvec
        compok = 1;
        try
            checkdata = csvread(statePDtransfile,0,0);
        catch
            compok = 0;     % toggle to generate PDT
        end
        if compok==1
            if isequal(round(statePDtransvec,8,'significant'),...
                    round(checkdata,8,'significant'))
            else
                compok = 0; % change in model specification. gen PDT
            end
        else
        end
        % If no changes, load PDT matrix. Otherwise create it and
        % write it
        PDtransfile = [dirs.db,'IntermediateData/PriceDayrate/PDTrans.csv'];
        if compok==1
            obj.PDT = sparse(csvread(PDtransfile));     % read PDT            
        else
            PDT = PDtrans(obj);     % generate PDT
            obj.PDT = sparse(PDT);
            dlmwrite(PDtransfile, PDT, 'delimiter', ',', 'precision', 14);
            dlmwrite(statePDtransfile, statePDtransvec, 'delimiter', ',', 'precision', 14);
        end

        % Wells per unit
        obj.Wells = params.Wells;
        
        % Load unit data
        [obj.N, obj.dataR, obj.dataLC, obj.dataRent, obj.obsLshare, obj.dataLshare,...
            obj.dataSpudy, obj.dataSpudq, obj.obsSpud, obj.dataX, obj.dataID,...
            obj.dataT0y, obj.dataT0q, obj.starty, obj.startq, obj.TU] = loadUnit(obj,dirs);
        
        % Find row of price & dayrate data corresponding to unit data start
        % Loop over units
        obj.dataT0i = zeros(obj.N,1);       % initialize
        for n = 1:obj.N
            obj.dataT0i(n) = find(obj.pddata0(:,1)==obj.dataT0y(n) &...
                obj.pddata0(:,2)==obj.dataT0q(n));
        end      
        
        % Find index of price and dayrate data corresponding to data start
        obj.starti = find(obj.pddata0(:,1)==obj.starty &...
                obj.pddata0(:,2)==obj.startq);

        % Simulation time variables
        obj.TMAX = max([obj.TU; obj.thetaTTBt]);    % max of acreage profile and time to build
        obj.reportT = obj.TU;                       % time to forward simulate
        
        % Drilling costs during max(time-to-build,pri term) and
        % during infinite horizon
        [obj.DC, obj.DCInf] = DrillCosts(obj);
        
        % Set up vector of leased acreage shares at which to evaluate
        % multi-well continuation values
        obj.NL = 5;         % number of evaluation points, including zero and one
        obj.lsharevec = linspace(0,1,obj.NL)';

        % Optimization algorithm parameters
        obj.maxit = 10000;      % max # of Bellman iterations in inf horizon
  
    end




    %% Generate test unit data (use this for testing code)
    function [N, dataR, dataLC, dataRent, obsLshare, dataLshare, dataSpudy, dataSpudq,...
            obsSpud, dataX, dataT0y, dataT0q, starty, startq, TU] = genUnit(obj,dirs)
        % Outputs:
        % N: number of units
        % dataR, dataLC, dataRent: N by 1 vectors of unit royalties, lessor
        % costs, and rent
        % obsLshare: N by obsT matrix of share of acreage leased, by
        % unit-quarter, in calendar time starting from starty and startq
        % dataLshare: N by TU matrix of share of acreage leased, by unit-quarter
        % dataLshare starts counting from the period after the unit starts
        % dataSpudy, dataSpudq: year and quarter of first spud
        % obsSpud: N by obsT matrix of zeros and ones. One denotes date of
        % first spud. First column is starty and startq
        % dataX: N by 1 vector of productivity (in 10million mmBtu)
        % dataT0y, dataT0q: N by 1 vectors of unit start year and quarter
        % starty, startq: year and quarter of first observation
        % TU: number of time quarters in unit data
        
        % Time profiles of leased acreage shares. First observation for each is on
        % the same calendar date (as would be the case for real data)
        obsLshare = ...
            [repmat(0.3,1,11) zeros(1,9);...
            0.2 0.4 0.6 0.8 ones(1,7) zeros(1,9);...
            ones(1,10) 0.95 zeros(1,9);...
            ones(1,10) repmat(0.95,1,8) 0 0;...
            ones(1,10) 0.3 zeros(1,9);...
            ones(1,10) repmat(0.3,1,8) 0 0;...
            ones(1,8) 0.7 0.6 0.5 0.4 0.3 0.2 0.1 zeros(1,5)];
        obsLshare = repmat(obsLshare,1,1);
        N = size(obsLshare,1);
        obsT = size(obsLshare,2); 
        
        % Standardize royalty, lessor cost, and rent
        dataR = repmat(0.6,N,1);
        dataLC = repmat(0.1,N,1);
        dataRent = repmat(0,N,1);

        
        % set dataX to productivity of the median unit
        % Units are tens of millions of mmBtu
        muLogXfile = [dirs.db,'IntermediateData/CalibrationCoefs/muLogX.csv'];
        muLogXvec = csvread(muLogXfile, 1);
        sigmaLogXfile = [dirs.db,'IntermediateData/CalibrationCoefs/sigmaLogX.csv'];
        sigmaLogX = csvread(sigmaLogXfile, 1); 
        muLogX = muLogXvec - log(1e7) - sigmaLogX^2/2; 
        dataX = repmat(exp(muLogX),N,1);
        dataX(N) = dataX(N) * 1.05;
        
        % year and quarter units start (no drilling possible until following period)
        dataT0y = repmat(2009,N,1);
        dataT0y(4) = 2008;
        dataT0q = ones(N,1);   
        dataT0q(1) = 4;
        
        % calendar year and quarter of first observation (same for all units)
        starty = 2010; startq = 1;
        
        % first spud year and quarter (zeros indicate no spud)
        dataSpudy = zeros(N,1);
        dataSpudq = zeros(N,1);
        
        % Create N by obsT matrix of zeros and ones, where one denotes
        % quarter each unit was first spudded
        % First get spud time index relative to obs start
        spudt = dataSpudy * 4 + dataSpudq - (starty*4 + startq) + 1;
        spudOK = spudt>=1 & spudt<=obsT;    % spud in sample
        obsSpud = zeros(N,obsT);        % initialize spud matrix
        % Use linear indexing to fill obsSpud with ones
        I = [1:N]';             % unit indices
        ind = sub2ind([N obsT], I(spudOK), spudt(spudOK));
        obsSpud(ind) = 1;       % spud indicators
        
        % Transform obsLshare to dataLshare. First obs in latter for each
        % unit is the first quarter in which drlg is possible for the unit
        add = (starty*4 + startq) - (dataT0y*4 + dataT0q) - 1;  % num of obs to add for each unit
        maxadd = max(add);                                      % max number of obs to add
        TU = obsT + maxadd;     % total number of time observations
        dataLshare = zeros(N, TU);  % initialize matrix of leased acreage shares, starting from unit start
        % Loop over units and build dataLshare
        for i = 1:N
            if add(i)==0
                dataLshare(i,:) = [obsLshare(i,:) zeros(1,maxadd)];
            elseif add(i)==maxadd
                dataLshare(i,:) = [zeros(1,maxadd) obsLshare(i,:)];
            else
                dataLshare(i,:) = [zeros(1,add(i)) obsLshare(i,:) zeros(1,maxadd-add(i))];
            end
        end
        
    end
    
    
    
    %% Load unit data
    function [N, dataR, dataLC, dataRent, obsLshare, dataLshare, dataSpudy, dataSpudq,...
            obsSpud, dataX, dataID, dataT0y, dataT0q, starty, startq, TU] = loadUnit(obj,dirs)
        % Outputs:
        % N: number of units
        % dataR, dataLC, dataRent: N by 1 vectors of unit royalties, lessor
        % costs, and rent
        % obsLshare: N by obsT matrix of share of acreage leased, by
        % unit-quarter, in calendar time starting from starty and startq
        % dataLshare: N by TU matrix of share of acreage leased, by unit-quarter
        % dataLshare starts counting from the period after the unit starts
        % dataSpudy, dataSpudq: year and quarter of first spud
        % obsSpud: N by obsT matrix of zeros and ones. One denotes date of
        % first spud. First column is starty and startq
        % dataX: N by 1 vector of productivity (in 10million mmBtu)
        % dataT0y, dataT0q: N by 1 vectors of unit start year and quarter
        % starty, startq: year and quarter of first observation
        % TU: number of time quarters in unit data
        
        % Load time profiles of leased acreage shares. 
        % First observation for each is on starty and startq     
        obsLsharefile = [dirs.db,...
            'IntermediateData/StructuralEstimationData/fraction_leased.csv'];
        obsLshare0 = csvread(obsLsharefile,1,0);
        % Remove first two columns and grab the year and quarter of the
        % first observation (same for all units)
        yq = obsLshare0(:,1:2);
        starty = yq(2,1); startq = yq(2,2);
        obsLshare0 = obsLshare0(:,3:size(obsLshare0,2));
        % Transpose and then grab unit id's from first column
        obsLshare0 = obsLshare0';
        unitID = obsLshare0(:,1);
        obsT = size(obsLshare0,2) - 1;   % number of observation time periods
        obsLshare0 = obsLshare0(:,2:obsT+1);  % remove unit ids
        
        % Load unit characteristics (all except productivity)
        unitcharsfile = [dirs.db,...
            'IntermediateData/StructuralEstimationData/unit_chars.csv'];
        unitchars0 = csvread(unitcharsfile,1,0);
        % make sure unit ID's align
        unitID2 = unitchars0(:,1);
        test = unitID==unitID2;
        test = min(test);
        if min(test)==0         % mismatch
            error('Error. AUnit IDs in unit_chars.csv and fraction_leased.csv do not match.')
        else
        end
        
        % Filter units to go from "descriptive sample" to "calibration sample"
        % Flag units drilled >= start of sample (or never)
        spudy0 = unitchars0(:,3); spudq0 = unitchars0(:,4);     % spud year and qtr
        spudt0 = spudy0 * 4 + spudq0 - (starty*4 + startq) + 1; % spud time indexed from starty and startq
        spudcal = spudt0>0 | spudy0==0;         % spudded after sample start or never
        % Flag units leased < start of sample
        leasey0 = unitchars0(:,7); leaseq0 = unitchars0(:,8);   % lease year and qtr
        leaset0 = leasey0 * 4 + leaseq0 - (starty*4 + startq) + 1; % lease time indexed from starty and startq
        firstleasecal = leaset0<1;              % first leased before sample start
        % Flag units with >=2 wells in the caliper for productivity estimation
        wellscal = unitchars0(:,16)>=2;
        % Flag units with nonzero royalty
        roycal = unitchars0(:,2)>0;
        % Flag units where acreage leased increases within sample
        incflags = zeros(size(obsLshare0));
        for t = 2:obsT
            incflags(:,t) = obsLshare0(:,t)>obsLshare0(:,t-1);
        end
        incal = max(incflags')';
        incal = ~incal;
        % Flag units with >=160 acres during sample
        maxshare = max(obsLshare0')';               % highest share leased
        maxacres = maxshare .* unitchars0(:,10);    % highest acreage leased
        acrescal = maxacres>=160;
        % Flag units drilled when acreage = 0
        spudacres = ones(length(unitchars0(:,1)),1);    % initialize
        for i = 1:length(unitchars0(:,1))
            if spudt0(i)>=1 && spudt0(i)<=obsT              % spud in sample
                spudacres(i) = obsLshare0(i,spudt0(i));     % assign acreage at spud
            else
            end
        end
        zeroacrescal = spudacres>0;

        % Filter units
        unitchars = unitchars0(spudcal & firstleasecal & wellscal...
            & roycal & incal & acrescal & zeroacrescal,:);
        obsLshare = obsLshare0(spudcal & firstleasecal & wellscal...
            & roycal & incal & acrescal & zeroacrescal,:);
        % Number of units
        N = size(unitchars,1);

        % Export info on units filtered out
        % First: number of units satisfying basic spud and first lease date restrictions
        Nspudunitstart = sum(spudcal & firstleasecal);
        % Units dropped by caliper, royalty, decreasing acreage, and 160 acres restrictions
        DropCaliper = sum(spudcal & firstleasecal & ~wellscal);
        DropRoy = sum(spudcal & firstleasecal & ~roycal);
        DropDecreasingAcres = sum(spudcal & firstleasecal & ~incal);
        Drop160 = sum(spudcal & firstleasecal & ~acrescal);
        % Find # of units dropped due to drilling when zero acreage
        DropZeroAcres = sum(spudcal & firstleasecal & wellscal...
            & roycal & incal & acrescal & ~zeroacrescal);
        unitestsamplefile = [dirs.db,'IntermediateData/CalibrationCoefs/unitestsampleinfo.csv'];
        fileid = fopen(char(unitestsamplefile),'w');
        fprintf(fileid,'OrigNumUnits, N_spudtiming_unitstarttiming, D_2wellcaliper, D_royaltydata, D_decreasingacreage, D_160acres, D_zeroLL, FinalN \n');
        fprintf(fileid,'%3.0f,%3.0f,%3.0f,%3.0f,%3.0f,%3.0f,%3.0f,%3.0f',...
            [length(zeroacrescal) Nspudunitstart DropCaliper DropRoy,...
            DropDecreasingAcres Drop160 DropZeroAcres N]);
        fclose('all');
        % Export list of unit IDs
        unitIDfile = [dirs.db,'IntermediateData/CalibrationCoefs/unitestsampleIDs.csv'];
        dlmwrite(unitIDfile, unitchars(:,1), 'delimiter', ',', 'precision', 14);
        
        
        % Grab characteristics
        dataID = unitchars(:,1);        % unit IDs
        dataR = unitchars(:,2);         % royalties
        dataLC = zeros(N,1); dataRent = zeros(N,1); % lessor cost and rent are zero
        dataT0y = unitchars(:,7);       % unit start year
        dataT0q = unitchars(:,8);       % unit start quarter
        logX = unitchars(:,9);          % log production in mmBtu
        dataX = exp(logX - log(1e7));   % production in 10^7 mmBtu
        dataSpudy = unitchars(:,3);     % first spud year
        dataSpudq = unitchars(:,4);     % first spud quarter
       
        
        % Create N by obsT matrix of zeros and ones, where one denotes
        % quarter each unit was first spudded
        % First get spud time index relative to obs start
        spudt = dataSpudy * 4 + dataSpudq - (starty*4 + startq) + 1;
        spudOK = spudt>=1 & spudt<=obsT;    % spud in sample
        obsSpud = zeros(N,obsT);        % initialize spud matrix
        % Use linear indexing to fill obsSpud with ones
        I = [1:N]';             % unit indices
        ind = sub2ind([N obsT], I(spudOK), spudt(spudOK));
        obsSpud(ind) = 1;       % spud indicators

        % Transform obsLshare to dataLshare. First obs in latter for each
        % unit is the first quarter in which drlg is possible for the unit
        % This code assumes that observation start date is at least one quarter after
        % the latest unit start date
        add = (starty*4 + startq) - (dataT0y*4 + dataT0q) - 1;  % num of obs to add for each unit
        test = min(add);
        if min(test)<0          % start date is <= latest unit start date
            error('Error. Observation start date is <= at least one of the unit start dates')
        else
        end        
        maxadd = max(add);                                      % max number of obs to add
        TU = obsT + maxadd;     % total number of time observations
        dataLshare = zeros(N, TU);  % initialize matrix of leased acreage shares, starting from unit start
        % Loop over units and build dataLshare
        for i = 1:N
            if add(i)==0
                dataLshare(i,:) = [obsLshare(i,:) zeros(1,maxadd)];
            elseif add(i)==maxadd
                dataLshare(i,:) = [zeros(1,maxadd) obsLshare(i,:)];
            else
                dataLshare(i,:) = [zeros(1,add(i)) obsLshare(i,:) zeros(1,maxadd-add(i))];
            end
        end        
    end

    
    
    %% Calculate the price-dayrate matrix
    function PDT = PDtrans(obj)
        % Outputs PDT: price-dayrate transition matrix. nP*nD by nP*nD

        % Extract coefficients from obj.PDcoefs
        bP0 = obj.PDcoefs(3);
        bP1 = obj.PDcoefs(4);
        bD0 = obj.PDcoefs(5);
        bD1 = obj.PDcoefs(6);
        sigmaP = obj.PDcoefs(8);
        sigmaD = obj.PDcoefs(9);
        rho = obj.PDcoefs(12);

        % Initialize PDmat
        PDT = zeros(obj.nP*obj.nD,obj.nP*obj.nD);

        % Loop over prices and dayrates
        for jp = 1:obj.nP               % current price index
            p = obj.Prices(jp);
            for jd = 1:obj.nD           % current dayrate index
                d = obj.DR(jd);
                muP = bP0 + bP1 * p;    % expected change in log(p)
                muD = bD0 + bD1 * d;    % expected change in log(d)
                temp = 0;               % initialize summation over the elements k
                % set up triggers for picking a new starting point
                TrigP1 = 0; TrigP2 = 0;
                % with drift, diagonal is not always a relevant point!
                % calculate most likely landing point and work out from there
                tempP = exp(log(p)+muP);
                tempDR = exp(log(d)+muD);
                [~,eP] = min(abs(tempP-obj.Pc));
                [~,eD] = min(abs(tempDR-obj.DRc));

                for kpadj = 0:obj.nP-1  % distance from diagonal (based on expected drift)
                    for switchP = -1:2:1    % direction to go
                        % set up triggers for picking a new next dayrate
                        TrigD1 = 0; TrigD2 = 0;
                        kp = eP + switchP * kpadj;  % next price
                        if kp>obj.nP
                            TrigP2 = 1;             % out of range high
                        elseif kp<1
                            TrigP1 = 1;             % out of range low
                        elseif TrigP2==1 && switchP==1   % skip
                        elseif TrigP1==1 && switchP==-1  % skip
                        elseif kpadj==0 && switchP==1    % skip
                            if TrigP1==1; TrigP2 = 1; end % set trigger 
                        else                % OK to calc probabilities
                        tempold = temp;     % store current value of prob summation
                        for kdadj = 0:obj.nD-1  % distance from diagonal
                            for switchD = -1:2:1    % direction to go
                                kd = eD + switchD * kdadj;  % next dayrate
                                if kd>obj.nD
                                    TrigD2 = 1;     % out of range high
                                elseif kd<1
                                    TrigD1 = 1;     % out of range low
                                elseif TrigD2==1 && switchD==1   % skip
                                elseif TrigD1==1 && switchD==-1  % skip
                                elseif kdadj==0 && switchD==1    % skip
                                else        % OK to get probability
                                % get probability of transition to new price and
                                % dayrate
                                % this is prob that next price and dayrate will be
                                % within the rectangle defined by the cutoffs
                                Pcu = obj.Pc(kp);               % upper price
                                if kp==1; Pcl = -inf; else; Pcl = obj.Pc(kp-1); end % lower p
                                DRcu = obj.DRc(kd);             % upper dayrate
                                if kd==1; DRcl = -inf; else; DRcl = obj.DRc(kd-1); end % lower d
                                % Now get normalized price and dayrate changes
                                % Note: volatility impact is built into mu here since it's constant
                                if Pcu==inf; ZPu = 100000; else; ZPu = (log(Pcu) - log(p) - muP) / sigmaP; end
                                if Pcl==-inf; ZPl = -100000; else; ZPl = (log(Pcl) - log(p) - muP) / sigmaP; end
                                if DRcu==inf; ZDu = 100000; else; ZDu = (log(DRcu) - log(d) - muD) / sigmaD; end
                                if DRcl==-inf; ZDl = -100000; else; ZDl = (log(DRcl) - log(d) - muD) / sigmaD; end
                                Prob = mvncdf([ZPl ZDl],[ZPu,ZDu],[0 0],eye(2)+[0 rho; rho 0]);                           
                                if Prob > 0.001      % large enough to matter (easier to store zero if not)
                                   PDT((jd-1)*obj.nP+jp,(kd-1)*obj.nP+kp) = Prob;      % prob of change
                                   % get running total for row (jd-1)*np+jp & i
                                   % (don't count zero change twice)
                                   if kdadj==0 && switchD==1
                                   elseif kpadj==0 && switchP==1
                                   else
                                       temp = temp + Prob;
                                   end
                                elseif Prob<=0.001 && kdadj>0
                                    % set triggers for end of loop (at least in
                                    % one direction)
                                    if switchD==-1; TrigD1 = 1; else; TrigD2 = 1; end
                                else
                                end
                                end
                            end
                            % end loop over dayrates if zeros on both sides of diagonal
                            if TrigD1==1 && TrigD2==1; break; end
                        end
                        if tempold==temp && kpadj>0       % zero probability of change to kp
                            % set price triggers to end kp loop (at least in one
                            % direction)
                            if switchP==-1; TrigP1 = 1; else; TrigP2 = 1; end
                        end
                        end
                    end
                    % end loop over prices if zeros on both sides of diagonal
                    if TrigP1==1 && TrigP2==1; break; end
                end
                % Now normalize in the row so that probs add to one
                PDT((jd-1)*obj.nP+jp,:) = PDT((jd-1)*obj.nP+jp,:) / temp;
            end
        end   
    end



    %% Compute drilling costs
    function [DC, DCInf] = DrillCosts(obj)
        % Outputs:
        % DC: Drilling costs during the finite period when drilling costs decline
        % DC is nP*nD by TMAX
        % DCInf: Drilling costs during infinite period with constant drlg cost
        % DCInf is nP*nD vector
        % Drilling costs are all pre federal+state income tax

        % Drilling cost during infinite horizon period with constant costs
        DCInf = obj.thetaD + obj.thetaDA + obj.thetaDR * obj.PDR(:,2);

        % Initialize the DC matrix
        DC = zeros(obj.nP*obj.nD,obj.TMAX);

        % Count forward in time, starting with t = 1 (period just after lease signed)
        for t = 1:obj.TMAX
            % Create variable that is the max of 0 or obj.thetaTTBt- (t-1) 
            % Ensures floor on drilling cost that is thetaD + thetaDR * dayrate
            costtime = max([0; obj.thetaTTBt - (t-1)]);

            % Drilling cost
            DC(:,t) = DCInf + obj.thetaTTB * costtime / obj.thetaTTBt;
        end
    end
    
    
    
    %% Compute optimal water use, which depends on whether well pays out
    function [Wnp, Wp] = OptWater(obj,lshare)
    % Outputs:
    % Wnp, Wp: nP*nD x N matrices of optimal water use assuming the well:
    % does not pay out (np) or pays out (np) on profits before taxes, royalties, or op costs
    
    % Inputs:
    % lshare: N x 1 vector of fraction of unit acreage leased
    
    % Water use assuming well does not pay out (no sev tax or UMI payments)
    Wnp = zeros(obj.nP*obj.nD,obj.N);    % initialize (and set W = 0 if operating margin is < 0)
    OpMarg = (1 - repmat(lshare',obj.nP*obj.nD,1) .* obj.dataR')...
        .* obj.PDR(:,1) - obj.opcost;   % op margin per mmBtu
    PosMarg = OpMarg>0;
    fracWnp = obj.beta * OpMarg .* obj.dataX' / (obj.P_w / 1e7);    % interior of FOC
    Wnp(PosMarg) = fracWnp(PosMarg).^(1/(1-obj.beta));    % opt water use (gal)
    
    % Water use assuming well pays out (sev tax and UMI payments)
    Wp = zeros(obj.nP*obj.nD,obj.N);    % initialize (and set W = 0 if operating margin is < 0)
    OpMarg = repmat(lshare',obj.nP*obj.nD,1) .* (1-obj.sevrate) .* (1-obj.dataR')...
        .* obj.PDR(:,1) - obj.opcost;   % op margin per mmBtu
    PosMarg = OpMarg>0;
    fracWp = obj.beta * OpMarg .* obj.dataX' ./...
        (obj.P_w / 1e7 * lshare' .* (1 - obj.sevrate + obj.sevrate * obj.dataR'));    % interior of FOC
    Wp(PosMarg) = fracWp(PosMarg).^(1/(1-obj.beta));    % opt water use (gal)

    end
    
    
    
    %% Compute a single period's static payoff to the firm and lessor,
    % and calc prod and water use
    function [PiDrillt, RoyDrillt, Qt, Wt] = Payoffst(obj,tvec,lshare,Wi)    
    % Outputs:
    % PiDrillt, RoyDrillt: firm profits and royalties. $10millions. nP*nD x N
    % Note that payoffs do not include rental payments
    % Payoffs are post severance tax and post federal+state income tax
    % Qt, Wt: optimized water use (gallons) and production (10 million mmBtu). nP*nD x N
    
    % Inputs:
    % tvec: N x 1 vector of times (in unit time) to compute payoffs at
    % lshare: N x 1 vector of fraction of unit acreage leased
    % Wi: nP*nD x N optional input of water use in each state-unit.
    % Overrides optimal water use
    
    % Concatenate obj.DC and obj.DCInf matrices
    DCall = cat(2, obj.DC, obj.DCInf);
    
    % Replace any times in tvec that are greater than TMAX with TMAX+1
    % These times will them point to DCInf
    tvec(tvec>obj.TMAX) = obj.TMAX + 1; 
    
    % For each unit, obtain drilling cost at time given in tvec
    % Use linear indexing to collect elements from obj.DC
    I1 = repmat([1:obj.nP*obj.nD]',obj.N,1);    % row indices
    I2 = kron(tvec, ones(obj.nP*obj.nD,1));     % column indices
    ind = sub2ind([obj.nP*obj.nD obj.TMAX+1], I1, I2);    % linear indices
    % Drilling cost at tvec. nP*nD by N
    DCt = reshape(DCall(ind), obj.nP*obj.nD, obj.N);
    
    if nargin==4        % use input water use
        Wt = Wi;        
    else
        % Obtain optimal water under assumptions that the well doesn't pay out
        % or does pay out on pre-tax pre opcost profits
        [Wnp, Wp] = OptWater(obj,lshare);

        % Compute pre-tax, pre-opcost profits for both water use types
        pPinp = obj.PDR(:,1) .* obj.dataX' .* Wnp.^obj.beta...
            - obj.P_w * Wnp / 1e7 - DCt;        % non payout
        pPip = obj.PDR(:,1) .* obj.dataX' .* Wp.^obj.beta...
            - obj.P_w * Wp / 1e7 - DCt;         % payout
        % Determine when well actually does or does not pay out
        Pip_pos = pPip>0; Pinp_neg = pPinp<0;
        % Identify cases when optimal water use involves breakeven
        BE = ~Pip_pos & ~Pinp_neg;
        % Interpolate water use that results in break even profits
        alpha = zeros(obj.nP*obj.nD,obj.N);     % initialize interpolation weights
        alpha(BE) = (0 - pPip(BE)) ./ (pPinp(BE) - pPip(BE));  % interp weights
        W0 = zeros(obj.nP*obj.nD,obj.N);     % initialize breakeven water
        W0(BE) = (1-alpha(BE)) .* Wp(BE) + alpha(BE) .* Wnp(BE);
        % Final water use
        Wt = Wp;                      % start with payout water use
        Wt(Pinp_neg) = Wnp(Pinp_neg); % water if well does not pay out
        Wt(BE) = W0(BE);              % breakeven water  
    end
    
    % Calculate production (in tens of millions of Btu) at optimal water
    Qt = obj.dataX' .* Wt.^obj.beta;
    
    % Calculate operating costs (units of $10 million)
    OpCost = obj.opcost * Qt;

	% Calculate revenue (units of $10million)
	RevDrill = obj.PDR(:,1) .* Qt;
    
    % Build profits before royalty, severance taxes, payments to UMI, 
    % income taxes, op cost, and drlg subsidy
    % Loop over time periods
    tempPi = RevDrill - DCt - obj.P_w * Wt / 1e7;
    
    % Calculate payments to UMIs: 1-lshare fraction of tempPi, with a floor of zero
    UMI = max((1-lshare') .* tempPi, 0);
    
    % Calculate severance taxes: sevrate fraction of tempPi less UMI, with a floor of zero
    Sev = max(obj.sevrate .* (tempPi - UMI), 0);

    % Calculate pre-tax royalty payments (which are post UMI and severance tax)  
    Pos = tempPi>0;                 % positive pre-tax, pre-opcost profits
    % First calculate royalties assuming well does not pay out
    % These are lease share times the royalty rate times revenue
    RoyDrillPreTax = lshare' .* obj.dataR' .* RevDrill;
    % If well pays out, pay the above royalty on revenue up to completion
    % cost, and then pay royalty on lshare share profits net of sev tax
    tempRoy = lshare' .* obj.dataR' .* (DCt + obj.P_w * Wt / 1e7);
    tempRoy = tempRoy + lshare' .* (1-obj.sevrate) .* obj.dataR' .* tempPi;
    RoyDrillPreTax(Pos) = tempRoy(Pos);
    
    % Royalties after income tax
    RoyDrillt = RoyDrillPreTax * (1-obj.itax_rate);
    
    % Firm profits after royalty, severance tax, op cost, UMI, and drilling subsidy
    % post income tax
    PiDrillt = (RevDrill - RoyDrillPreTax - UMI - Sev - OpCost) * (1-obj.itax_rate)...
         - obj.P_w * Wt * (1-obj.itax_rate) / 1e7...
         - DCt * (1-obj.itax_ratecap)...
         + repmat(obj.dataLC'.*lshare',obj.nP*obj.nD,1);      
    end
    
    
    
    %% Compute per-period payoffs to the firm and lessor, and calc prod and water use
    function [PiDrill, PiDrillInf, RoyDrill, RoyDrillInf,...
            Q, QInf, W, WInf] = Payoffs(obj,lshare)
    % Outputs:
    % PiDrill, RoyDrill: firm profits and royalties during max of 
    % {pri term, cost decline period}. $10millions. nP*nD x N x TMAX
    % PiDrillInf, RoyDrillInf: firm profits and royalties during infinite
    % horizon when costs are constant. $10millions. nP*nD x N
    % Note that payoffs do not include rental payments
    % Payoffs are post severance tax and post federal+state income tax
    % Q, W: optimized water use (gallons) and production (10 million mmBtu). nP*nD x N by TMAX
    % QInf, WInf: water use and production in inf horizon. nP*nD x N
    
    % Inputs:
    % lshare: N x 1 vector of fraction of unit acreage leased
    
    % Get infinite horizon payoffs, production, and water use
    tvec = repmat(obj.TMAX+1,obj.N,1);  % call infinite horizon drlg costs
    [PiDrillInf, RoyDrillInf, QInf, WInf] = Payoffst(obj,tvec,lshare);  
    
    % Initialize matrices for finite horizon (time to build) period
    PiDrill = zeros(obj.nP*obj.nD, obj.N, obj.TMAX);
    RoyDrill = zeros(obj.nP*obj.nD, obj.N, obj.TMAX);
    Q = zeros(obj.nP*obj.nD, obj.N, obj.TMAX);
    W = zeros(obj.nP*obj.nD, obj.N, obj.TMAX);
    
    % Loop over time to build period
    for t = 1:obj.thetaTTBt
        tvec = repmat(t,obj.N,1);   % period to pull payoffs for
        [PiDrill(:,:,t), RoyDrill(:,:,t), Q(:,:,t), W(:,:,t)]...
            = Payoffst(obj,tvec,lshare);  
    end
    
    % Extend the above to TMAX if needed
    if obj.TMAX > obj.thetaTTBt
        PiDrill(:,:,obj.thetaTTBt+1:obj.TMAX)...
            = repmat(PiDrillInf,1,1,obj.TMAX-obj.thetaTTBt);
        RoyDrill(:,:,obj.thetaTTBt+1:obj.TMAX)...
            = repmat(RoyDrillInf,1,1,obj.TMAX-obj.thetaTTBt);
        Q(:,:,obj.thetaTTBt+1:obj.TMAX)...
            = repmat(QInf,1,1,obj.TMAX-obj.thetaTTBt);
        W(:,:,obj.thetaTTBt+1:obj.TMAX)...
            = repmat(WInf,1,1,obj.TMAX-obj.thetaTTBt);
    else
    end
    
    
      
    end
    
    
    %% Compute choice probabilities and logit-inclusive values given payoffs
    function [pr,lic] = LogitProbs(obj,payoffs,epsscale)
        % Outputs:
        % pr: matrix of logit conditional choice probabilities. nk columns.
        % lic: vector of logit inclusive values. 

        % Inputs
        % payoffs enter as matrix. usually nP*nD*N rows and nk columns
        % epsscale is a vector of logit shock scales. usually nP*nD*N rows 
        % (must be same # of rows as payoffs)
        
        % Scales by the largest payoff to avoid numerical overflow
        % See Jason Blevins blog post: http://jblevins.org/log/log-sum-exp
        
        nk = size(payoffs,2);       % number of choices
        
        zscale = epsscale==0;       % rows with no logit shock
        
        % Scale payoffs by scale of logit shocks
        v = payoffs ./ epsscale;
        temp = v;
        temp(isinf(temp)) = -Inf;

        % Find max scaled payoff    
        [c,~] = max(temp,[],2);
        c(isinf(c)) = 0;
        
        % Compute lic and probabilities, using max payoff to avoid
        % numerical issues
        lic = epsscale .* (log(sum(exp(v - c), 2)) + c);
        pr = exp(v - c) ./ sum(exp(v - c), 2);      
        
        % Deal with rows that have zero logit shock
        if sum(zscale)>0
            pos = zeros(size(payoffs,1),1);            % initialize position matrix
            [lic(zscale), pos(zscale)] = max(payoffs(zscale,:),[],2);  % max of payoffs
            pr(zscale,:) = zeros(sum(zscale),nk);
            ind = [1:size(payoffs,1)]';
            indices = (pos(zscale)-1) * size(payoffs,1) + ind(zscale);
            pr(indices) = 1;
        else
        end
        
    end

    
    
    %% Compute a single Bellman iteration
    function [EV,DrillHaz,ExpireHaz,DrillHazMout] = BellmanIt(obj,Vnext,tempPi,...
            tempRoy,tempRent,lshare,Vnextm,Vm,DrillHazM)
        % Outputs:
        % EV: struct of expected values, at "start" of period, for firm,
        % royalty, lessor cost, rent, and bonus payments. All expected
        % values are nP*nD by N
        % DrillHaz: nP*nD by N matrix of drilling hazards
        % ExpireHaz: nP*nD by N matrix of expiration hazards
        % DrillHazMout: nP*nD by N matrix of multi-well drilling hazards
        
        % Inputs:
        % Vnext: struct of continuation values for firm, royalty, lessor
        % cost, rents, and bonus payments. All continuation values are
        % nP*nD by N. They are discounted expected values for next period.
        % Thus, this function does not multiply them by delta * PDT
        % tempPi,tempRoy: firm profits and royalties from drilling today. nP*nD by N
        % tempRent: N by 1 vector of per-period rental rates
        % Vnextm: struct of discounted expected values of having an additional well to
        % drill next period if the firm drills the first well now. nP*nD by N. 
        % Vm: firm's expected value at the "start" of the period for drilling
        % an additional well. nP*nD by N. 
        % DrillHazM: hazard of drilling multiple wells this period. nP*nD by N.
        % lshare: N by 1 vector of fraction of unit acreage leased
        
        % Structs in EV and Vnext are .Firm, .Roy, .LC, .Rent, and .Bonus
        % Vnextm only includes .Firm, .Roy, and .LC
        
        % If the multi-well arguments are missing, replace them with zeros
        if nargin==6
            Vnextm.Firm = zeros(obj.nP*obj.nD,obj.N); Vnextm.Roy = zeros(obj.nP*obj.nD,obj.N);
            Vnextm.LC = zeros(obj.nP*obj.nD,obj.N);
            Vm = zeros(obj.nP*obj.nD,obj.N);
            DrillHazM = zeros(obj.nP*obj.nD,obj.N);
        else
        end

        % Initialize output multi-well drilling haz to be same as input
        DrillHazMout = DrillHazM;        
        
        % Obtain nP*nD*N vector of epsilon shock scale factors
        % Scale down baseline shock by share of acreage leased
        lsharelong = reshape(repmat(lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);
        epsscale = obj.epsScale * lsharelong;
        
        % the value from extending is the future expected value - today's rent
        vExtend = reshape(Vnext.Firm - tempRent'.*lshare',obj.nP*obj.nD*obj.N,1);

        % the value from letting expire today is just today's rent
        vExpire = -reshape(repmat(tempRent'.*lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);

        % value of not drilling is the max of expire or extend
        [vNoDrill,c] = max(cat(2,vExtend,vExpire),[],2);
        % c==1: extend the lease given the firm decides not to drill
        % c==2: let the lease expire given the firm decides not to drill 
        % max picks c==1 if indifferent
        
        % Obtain drilling hazards and firm values assuming that the
        % per-well continuation value from additional wells to drill is greater
        % than the per-well value of next period in the absence of any drilling
        % First, get value of drilling one well: drilling profits plus continuation
        vDrill1 = tempPi(:) + (obj.Wells-1)*Vnextm.Firm(:)...
            - reshape(repmat(tempRent'.*lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);         
        % choice probs and logit inclusive value of wait/expire vs drill one well
        PayoffsIter = [vNoDrill,vDrill1];
        [tempPr,tempV1] = LogitProbs(obj,PayoffsIter,epsscale);

        % Calculate the firm's expected discounted (over epsilon) value at the
        % "start" of the period
        tempV = tempV1 + (obj.Wells-1) * (Vm(:) - Vnextm.Firm(:));
        
        % Now identify cases where the per-well continuation value from additional
        % wells to drill is less than the per-well value of next period in the
        % absence of any drilling. In these cases firm will never drill one
        % well, and the input DrillHazM values are too large
        Ind = (Vnext.Firm(:) / obj.Wells > Vnextm.Firm(:)) & Vm(:)>0;   % nP*nD*N vector of logicals
        if sum(Ind)>0           % inequality holds in at least one cell
            % get value of drilling all wells
            vDrillall = obj.Wells * tempPi(:)...
                - reshape(repmat(tempRent'.*lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);
            % choice probs and logit inclusive value of wait/expire vs drill all wells
            PayoffsIterall = [vNoDrill,vDrillall];
            [tempPrall,tempVall] = LogitProbs(obj,PayoffsIterall,obj.Wells*epsscale);    
            % Store firm values and drilling haz in cells denoted by Ind
            tempV(Ind) = tempVall(Ind);
            tempPr(Ind,:) = tempPrall(Ind,:);
            % Correct multi-well hazards in cells denoted by Ind
            DrillHazMout(Ind) = tempPrall(Ind,2);
        else                    % no need for any changes
        end
        
        % Report drilling and expiration probabilities
        DrillHaz = reshape(tempPr(:,2),obj.nP*obj.nD,obj.N);
        ExpireHaz = reshape(tempPr(:,1).*(c==2),obj.nP*obj.nD,obj.N);
        
        % Output expected value to firm
        EV.Firm = reshape(tempV,obj.nP*obj.nD,obj.N);
        
        % Output expected value of royalty
        tempVr = tempPr(:,1).*(c==1).*Vnext.Roy(:)... 
            + (tempPr(:,2)-DrillHazM(:)) .* (tempRoy(:)+(obj.Wells-1)*Vnextm.Roy(:))...
            + DrillHazM(:).*(obj.Wells*tempRoy(:));
        EV.Roy = reshape(tempVr,obj.nP*obj.nD,obj.N);     

        % Output expected lessor cost
        tempVLC = tempPr(:,1).*(c==1).*Vnext.LC(:)... 
            + (tempPr(:,2)-DrillHazM(:)) .*...
            (reshape(repmat(obj.dataLC'.*lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1)...
            + (obj.Wells-1)*Vnextm.LC(:))...
            + DrillHazM(:).*(obj.Wells*...
            reshape(repmat(obj.dataLC'.*lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1));
        EV.LC = reshape(tempVLC,obj.nP*obj.nD,obj.N);        

        % Output expected value of rent
        tempVRent = reshape(repmat(tempRent'.*lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1)...
                + tempPr(:,1).*(c==1).*Vnext.Rent(:);
        EV.Rent = reshape(tempVRent,obj.nP*obj.nD,obj.N);  
        
        % Output expected value of future extension bonus
        tempBonus = tempPr(:,1).*(c==1).*Vnext.Bonus(:);  
        EV.Bonus = reshape(tempBonus,obj.nP*obj.nD,obj.N);  
    end    
    
    
    
    %% Infinite recursion function. Computes stationary values and drilling hazards
    function [EV,DrillHaz,ExpireHaz] = RecursionInfinite(obj,PiDrillInf,...
            RoyDrillInf,tempRent,lshare,Vm,DrillHazM)
        % Outputs:
        % EV: struct of expected values, at "start" of period, for firm,
        % royalty, lessor cost, rent, and bonus payments. All expected
        % values are nP*nD by N
        % DrillHaz: nP*nD by N matrix of drilling hazards
        % ExpireHaz: nP*nD by N matrix of expiration hazards
        
        % Inputs:
        % PiDrillInf: nP*nD by N matrix of firm drilling profits
        % RoyDrillInf: nP*nD by N matrix of lessor royalties
        % tempRent: N by 1 vector of per-period rental rates
        % Vm: struct of expected value at the "start" of the period for drilling
        % an additional well (in addition to first well). nP*nD by N
        % DrillHazM: hazard of drilling multiple wells. nP*nD by N.
        % lshare: N by 1 vector of fraction of unit acreage leased
        
        % Structs in EV are .Firm, .Roy, .LC, .Rent, and .Bonus
        % Vm only includes .Firm, .Roy, and .LC        
        
        % If the multi-well arguments are missing, replace them with zeros
        if nargin==5
            Vm.Firm = zeros(obj.nP*obj.nD,obj.N); Vm.Roy = zeros(obj.nP*obj.nD,obj.N);
            Vm.LC = zeros(obj.nP*obj.nD,obj.N);
            DrillHazM = zeros(obj.nP*obj.nD,obj.N);
        else
        end    
        
        % Obtain nP*nD*N vector of epsilon shock scale factors
        % Scale down baseline shock by share of acreage leased
        lsharelong = reshape(repmat(lshare',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);
        epsscale = obj.epsScale * lsharelong; 
        
        % Initial guesses for the EV struct
        EV.Firm = max(PiDrillInf,0);
        Payoffs0 = [obj.delta*vec(EV.Firm),PiDrillInf(:)];
        [tempPr,tempV0] = LogitProbs(obj,Payoffs0,epsscale);
        EV.Firm = reshape(tempV0,obj.nP*obj.nD,obj.N);
        tempV0r = tempPr(:,2).*RoyDrillInf(:);
        EV.Roy = reshape(tempV0r,obj.nP*obj.nD,obj.N);
        tempV0LC = tempPr(:,2).*reshape(repmat(obj.dataLC',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);
        EV.LC = reshape(tempV0LC,obj.nP*obj.nD,obj.N).*lshare';
        EV.Rent = repmat(tempRent',obj.nP*obj.nD,1).*lshare';
        
        % Bonus is always zero in infinite horizon problem
        EV.Bonus = zeros(obj.nP*obj.nD,obj.N);
        
        % Discounted expected value of multiple wells next period
        Vnextm.Firm = obj.delta * obj.PDT * Vm.Firm;
        Vnextm.Roy = obj.delta * obj.PDT * Vm.Roy;
        Vnextm.LC = obj.delta * obj.PDT * Vm.LC; 
        
        % Bellman iteration
        tic
        for iter = 1:obj.maxit
            % Set EVold for next iteration
            EVold = EV;
            % Discount and multiply by PDT to get Vnext
            Vnext.Firm = obj.delta * obj.PDT * EVold.Firm;
            Vnext.Roy = obj.delta * obj.PDT * EVold.Roy;
            Vnext.LC = obj.delta * obj.PDT * EVold.LC;
            Vnext.Rent = obj.delta * obj.PDT * EVold.Rent;
            Vnext.Bonus = obj.delta * obj.PDT * EVold.Bonus;            
            % call to value function iteration - this is the workhorse of the entire call
            [EV,DrillHaz,ExpireHaz,~] = BellmanIt(obj,Vnext,PiDrillInf,RoyDrillInf,...
                tempRent,lshare,Vnextm,Vm.Firm,DrillHazM);
            % Obtain value function change in the sup norm
            Change = max([vec(abs(EV.Firm-EVold.Firm)); vec(abs(EV.Roy-EVold.Roy));...
                vec(abs(EV.LC-EVold.LC)); vec(abs(EV.Rent-EVold.Rent));...
                vec(abs(EV.Bonus-EVold.Bonus))]);
            if Change<=1e-6; break; end
        end
        
        % Tell user what happened
        if Change>1e-6, warning('Failure to converge with function iteration'),end
        disp(['Infinite horizon value function took ' ,num2str(toc),' seconds'...
            ' and ',num2str(iter),' iterations'])
        if max(vec(isnan(EV.Firm)+isinf(EV.Firm))) >0
            error('Error. At least one element of value function is infinite or NaN')
        end
    end
    
    
    
    %% Obtain continuation values after extension or drilling of first well
    function [EVc,DrillHazc,ExpireHazc]...
            = ContinuationValues(obj,PiDrill,PiDrillInf,RoyDrill,RoyDrillInf,...
            tempRent,lshare,Vcm,DrillHazM)
        % Outputs:
        % EVc: struct of expected values, at "start" of each period, for firm,
        % royalty, lessor cost, rent, and bonus payments. All expected
        % values are nP*nD by N by TMAX+1
        % DrillHazc: nP*nD by N by TMAX+1 matrix of drilling hazards
        % ExpireHazc: nP*nD by N by TMAX+1 matrix of expiration hazards
        % The "+1" time dimension is for the stationary inf horizon period after TMAX
        
        % Inputs:
        % PiDrill, RoyDrill: nP*nD by N by TMAX matrices of firm drlg profits and royalties
        % PiDrillInf, RoyDrillInf: nP*nD by N by matrices of firm drlg profits
        % and royalties in inf horizon
        % tempRent: N by 1 vector of per-period rental rates
        % Vcm: struct of values of having an additional well to drill this
        % period if the firm drills the first well now. nP*nD by N by TMAX+1
        % DrillHazM: hazard of drilling multiple wells each period.
        % nP*nD by N by TMAX+1
        % lshare: N by 1 vector of fraction of unit acreage leased
        
        % Structs in EVc are .Firm, .Roy, .LC, .Rent, and .Bonus
        % Vcm only includes .Firm, .Roy, and .LC     
        
        % If the multi-well arguments are missing, replace them with zeros
        if nargin==7
            Vcm.Firm = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1); 
            Vcm.Roy = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
            Vcm.LC = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
            DrillHazM = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        else
        end   
        
        % Initialize output matrices
        EVc.Firm = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        EVc.Roy = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        EVc.LC = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        EVc.Rent = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        EVc.Bonus = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        DrillHazc = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        ExpireHazc = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);
        
        % Obtain infinite horizon continuation values
        % First extract multi-well continuation values at inf horizon
        Vminf.Firm = squeeze(Vcm.Firm(:,:,obj.TMAX+1));
        Vminf.Roy = squeeze(Vcm.Roy(:,:,obj.TMAX+1));
        Vminf.LC = squeeze(Vcm.LC(:,:,obj.TMAX+1));
        DrillHazMInf = squeeze(DrillHazM(:,:,obj.TMAX+1));
        % Run RecursionInfinite
        [EVcinf,DrillHazc(:,:,obj.TMAX+1),ExpireHazc(:,:,obj.TMAX+1)] =...
            RecursionInfinite(obj,PiDrillInf,RoyDrillInf,tempRent,lshare,Vminf,DrillHazMInf);
        % Store stationary values in EVc struct
        EVc.Firm(:,:,obj.TMAX+1) = EVcinf.Firm; EVc.Roy(:,:,obj.TMAX+1) = EVcinf.Roy;
        EVc.LC(:,:,obj.TMAX+1) = EVcinf.LC; EVc.Rent(:,:,obj.TMAX+1) = EVcinf.Rent;
        EVc.Bonus(:,:,obj.TMAX+1) = EVcinf.Bonus;   % zero in continuation problem
        
        % Work backwards in time from TMAX to t=1, calling BellmanIt at each step
        for s = 1:obj.TMAX
            t = obj.TMAX - s + 1;       % forward time
            % Obtain elements of the Vnext struct
            Vnext.Firm = obj.delta * obj.PDT * squeeze(EVc.Firm(:,:,t+1));
            Vnext.Roy = obj.delta * obj.PDT * squeeze(EVc.Roy(:,:,t+1));
            Vnext.LC = obj.delta * obj.PDT * squeeze(EVc.LC(:,:,t+1));
            Vnext.Rent = obj.delta * obj.PDT * squeeze(EVc.Rent(:,:,t+1));
            Vnext.Bonus = obj.delta * obj.PDT * squeeze(EVc.Bonus(:,:,t+1));
            % Obtain period profits and royalties
            tempPi = squeeze(PiDrill(:,:,t)); tempRoy = squeeze(RoyDrill(:,:,t));
            % Obtain elements of the Vnextm struct
            Vnextm.Firm = obj.delta * obj.PDT * squeeze(Vcm.Firm(:,:,t+1));
            Vnextm.Roy = obj.delta * obj.PDT * squeeze(Vcm.Roy(:,:,t+1));
            Vnextm.LC = obj.delta * obj.PDT * squeeze(Vcm.LC(:,:,t+1));
            % Obtain Vm (multi-well value at start of this period)
            Vm = squeeze(Vcm.Firm(:,:,t));
            % Obtain drillhazm (haz of drilling mult wells this period)
            drillhazm = squeeze(DrillHazM(:,:,t));
            % Execute Bellman step
            [EVct,DrillHazc(:,:,t),ExpireHazc(:,:,t),~] =...
                BellmanIt(obj,Vnext,tempPi,tempRoy,tempRent,lshare,Vnextm,Vm,drillhazm);
            % Store EVct values in EVc
            EVc.Firm(:,:,t) = EVct.Firm; EVc.Roy(:,:,t) = EVct.Roy;
            EVc.LC(:,:,t) = EVct.LC; EVc.Rent(:,:,t) = EVct.Rent;
            EVc.Bonus(:,:,t) = EVct.Bonus;   % zero in continuation problem            
        end
    end

    
    
    %% Simulate multi-well drilling hazards and per-well values for a pre-set vector
    % of leased acreage shares
    function [DrillHazM_mat,EVm_mat] = MultWellVals(obj)
        % Outputs:
        % DrillHazM_mat: nP*nD by N by TMAX+1 by NL matrix of multi-well drilling hazards
        % EVm_mat: struct of expected per-well values for multi-well drilling, at the start of 
        % each period. nP*nD by N by TMAX+1 by NL       
        
        % Initialize output matrices
        DrillHazM_mat = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1,obj.NL);
        EVm_matFirm = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1,obj.NL);
        EVm_matRoy = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1,obj.NL);
        EVm_matLC = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1,obj.NL);
        EVm_matRent = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1,obj.NL);
        
        tempRent = zeros(obj.N,1);      % no rent after first well drilled
        
        % Loop over lessor shares in lsharevec, capturing hazards and
        % values each time
        % Skip first element. lshare = 0 returns all zeros.
        parfor i = 2:obj.NL
            lshare = repmat(obj.lsharevec(i),obj.N,1);
            % Get static profits and royalties per period
            [PiDrill, PiDrillInf, RoyDrill, RoyDrillInf,...
                ~, ~, ~, ~] = Payoffs(obj,lshare);
            % Get multi-well valuations (per well) and multi-well drilling hazards
            [evm,DrillHazM_mat(:,:,:,i),~] = ContinuationValues(obj,...
                PiDrill,PiDrillInf,RoyDrill,RoyDrillInf,tempRent,lshare);
            EVm_matFirm(:,:,:,i) = evm.Firm;
            EVm_matRoy(:,:,:,i) = evm.Roy;
            EVm_matLC(:,:,:,i) = evm.LC;
            EVm_matRent(:,:,:,i) = evm.Rent;
        end
        
        % Assemble values into struct
        EVm_mat.Firm = EVm_matFirm;
        EVm_mat.Roy = EVm_matRoy;
        EVm_mat.LC = EVm_matLC;
        EVm_mat.Rent = EVm_matRent;         
    end
    
    

    %% Simulate primary term
    function [DrillHaz,DrillHazM,ExpireHaz,EV0,EV,Q,W] = RunPriTerm(obj)
        % Outputs:
        % DrillHaz: nP*nD by N by TU by matrix of first-well drilling hazards
        % DrillHazM: nP*nD by N by TU matrix of multi-well drilling hazards
        % ExpireHaz: nP*nD by N by TU matrix of expiration hazards
        % EV0: struct of expected values, at lease start, for firm,
        % royalty, lessor cost, and rent payments. All expected
        % values are nP*nD by N. 
        % EV: struct of expected values at the start of each period of the pri term
        % Q, W: production and water use if drilled. nP*nD by N by TU
        
        % First step: build matrices of static drilling profit each period
        % Will need to loop through time, getting correct leased share for
        % each unit in each time step
        % First, initialize output matrices
        PiDrill = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        RoyDrill = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        Q = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        W = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        % Now loop forward through time, building static payoffs
        for t = 1:obj.TU
            % Grab leased acreage share for each unit
            lshare = obj.dataLshare(:,t);
            % Vector of unit times
            tvec = repmat(t,obj.N,1);
            % Get payoffs, Q, and W given tvec and lshare
            [PiDrill(:,:,t), RoyDrill(:,:,t), Q(:,:,t), W(:,:,t)]...
                = Payoffst(obj,tvec,lshare);  
        end
        
        % If there can be more than one well per unit, calculate multi-well
        % hazards and per-well values each period for multi-wells
        % Start by setting hazards and values to zero, which will be
        % default if obj.Wells=1
        DrillHazM = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EVm = zeros(obj.nP*obj.nD,obj.N,obj.TU);    % firm's multi-well value at start of t
        EVnextm.Firm = zeros(obj.nP*obj.nD,obj.N,obj.TU);   % multi-well values at start of t+1
        EVnextm.Roy = zeros(obj.nP*obj.nD,obj.N,obj.TU);    % using leased acreage shares at t
        EVnextm.LC = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EVnextm.Rent = zeros(obj.nP*obj.nD,obj.N,obj.TU);        
        if obj.Wells>1
            % Simulate multi-well drilling hazards and per-well values for a pre-set vector
            % of leased acreage shares (obj.lsharevec)
            [DrillHazM_mat,EVm_mat] = MultWellVals(obj);   
            % Next, interpolate multi-well hazards and per-well values each 
            % period, since actual leased share will fall between the values in
            % lsharevec upon which those hazards and values were computed
            % Again need to loop forward through time
            for t = 1:obj.TU
                % Grab leased acreage share for each unit
                lshare = obj.dataLshare(:,t);
                % Loop over units to identify elements of lsharevec that are
                % above and below each element of lshare
                indl = zeros(obj.N,1); indh = zeros(obj.N,1);   % initialize indices
                for i = 1:obj.N
                    indl(i) = find(obj.lsharevec<=lshare(i), 1, 'last' );
                    indh(i) = find(obj.lsharevec>=lshare(i), 1, 'first' );
                end
                % Obtain interpolation weights
                alpha = (lshare - obj.lsharevec(indl)) ./...
                    (obj.lsharevec(indh) - obj.lsharevec(indl));
                % Address infs (which occur when lshare lands on an element of lsharevec)
                badi = isinf(alpha) | isnan(alpha);
                alpha(badi) = 1;
                % Grab multi-well hazards and values at t
                dhazm = squeeze(DrillHazM_mat(:,:,t,:));
                evm = squeeze(EVm_mat.Firm(:,:,t,:));       % val to firm at start of t
                evnextm.firm = squeeze(EVm_mat.Firm(:,:,t+1,:));    % vals at start of t+1
                evnextm.roy = squeeze(EVm_mat.Roy(:,:,t+1,:));
                evnextm.lc = squeeze(EVm_mat.LC(:,:,t+1,:));
                evnextm.rent = squeeze(EVm_mat.Rent(:,:,t+1,:));
                % Create linear indices for the needed elements of dhazm,
                % evm, and evnextm
                I1 = repmat([1:obj.nP*obj.nD]',obj.N,1);    % row indices
                I2 = reshape(repmat([1:obj.N],obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);  % col indices
                I3l = reshape(repmat(indl',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);     % low lsharevec indices
                I3h = reshape(repmat(indh',obj.nP*obj.nD,1),obj.nP*obj.nD*obj.N,1);     % high lsharevec indices
                lindl = sub2ind(size(dhazm),I1,I2,I3l);     % linear indices for low lsharevec
                lindh = sub2ind(size(dhazm),I1,I2,I3h);     % linear indices for high lsharevec
                % Interpolate
                DrillHazM(:,:,t) = (1 - alpha') .* reshape(dhazm(lindl),obj.nP*obj.nD,obj.N)...
                    + alpha' .* reshape(dhazm(lindh),obj.nP*obj.nD,obj.N);
                EVm(:,:,t) = (1 - alpha') .* reshape(evm(lindl),obj.nP*obj.nD,obj.N)...
                    + alpha' .* reshape(evm(lindh),obj.nP*obj.nD,obj.N); 
                EVnextm.Firm(:,:,t) = (1 - alpha') .* reshape(evnextm.firm(lindl),obj.nP*obj.nD,obj.N)...
                    + alpha' .* reshape(evnextm.firm(lindh),obj.nP*obj.nD,obj.N);            
                EVnextm.Roy(:,:,t) = (1 - alpha') .* reshape(evnextm.roy(lindl),obj.nP*obj.nD,obj.N)...
                    + alpha' .* reshape(evnextm.roy(lindh),obj.nP*obj.nD,obj.N);  
                EVnextm.LC(:,:,t) = (1 - alpha') .* reshape(evnextm.lc(lindl),obj.nP*obj.nD,obj.N)...
                    + alpha' .* reshape(evnextm.lc(lindh),obj.nP*obj.nD,obj.N); 
                EVnextm.Rent(:,:,t) = (1 - alpha') .* reshape(evnextm.rent(lindl),obj.nP*obj.nD,obj.N)...
                    + alpha' .* reshape(evnextm.rent(lindh),obj.nP*obj.nD,obj.N); 
            end
        else
        end
        
        % Define terminal values at end of primary term
        Vnext.Firm = zeros(obj.nP*obj.nD,obj.N);
        Vnext.Roy = zeros(obj.nP*obj.nD,obj.N);
        Vnext.LC = zeros(obj.nP*obj.nD,obj.N);
        Vnext.Rent = zeros(obj.nP*obj.nD,obj.N);
        Vnext.Bonus = zeros(obj.nP*obj.nD,obj.N);
        
        % Initialize primary term output
        DrillHaz = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        ExpireHaz = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        DrillHazMout = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EV.Firm = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EV.Roy = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EV.LC = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EV.Rent = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EV.Bonus = zeros(obj.nP*obj.nD,obj.N,obj.TU);

        % Backwards recursion through primary term, calling BellmanIt each time
        for s = 1:obj.TU
            t = obj.TU - s + 1;         % forward time
            % Obtain period profits and royalties
            tempPi = squeeze(PiDrill(:,:,t)); tempRoy = squeeze(RoyDrill(:,:,t));
            % Obtain elements of the Vnextm struct
            Vnextm.Firm = obj.delta * obj.PDT * squeeze(EVnextm.Firm(:,:,t));
            Vnextm.Roy = obj.delta * obj.PDT * squeeze(EVnextm.Roy(:,:,t));
            Vnextm.LC = obj.delta * obj.PDT * squeeze(EVnextm.LC(:,:,t));
            % Obtain Vm (multi-well value at start of this period)
            Vm = squeeze(EVm(:,:,t));
            % Obtain drillhazm (haz of drilling mult wells this period)
            drillhazm = squeeze(DrillHazM(:,:,t));
            % Execute Bellman step
            [EVt,DrillHaz(:,:,t),ExpireHaz(:,:,t),DrillHazMout(:,:,t)]...
                = BellmanIt(obj,Vnext,tempPi,tempRoy,obj.dataRent,...
                obj.dataLshare(:,t),Vnextm,Vm,drillhazm); 
            % Record values at the start of period t
            EV.Firm(:,:,t) = EVt.Firm; EV.Roy(:,:,t) = EVt.Roy;
            EV.LC(:,:,t) = EVt.LC; EV.Rent(:,:,t) = EVt.Rent;
            EV.Bonus(:,:,t) = EVt.Bonus; 
            % Update the Vnext struct
            Vnext.Firm = obj.delta * obj.PDT * EVt.Firm;
            Vnext.Roy = obj.delta * obj.PDT * EVt.Roy;
            Vnext.LC = obj.delta * obj.PDT * EVt.LC;
            Vnext.Rent = obj.delta * obj.PDT * EVt.Rent;
            Vnext.Bonus = obj.delta * obj.PDT * EVt.Bonus;
        end     
        
        % Replace DrillHazM with DrillHazMout
        DrillHazM = DrillHazMout;
        
        % Extract expected values at lease signing
        EV0.Firm = Vnext.Firm;
        EV0.Roy = Vnext.Roy;
        EV0.LC = Vnext.LC;
        EV0.Rent = Vnext.Rent;
        EV0.Bonus = Vnext.Bonus;
        
        % Dummy values for extension bonus
        EV.ExtBonus = zeros(obj.nP*obj.nD,obj.N,obj.TU);
        EV0.ExtBonus = zeros(obj.nP*obj.nD,obj.N);
    
    end
    
    
    
    %% Find interpolation points and weights for a price, dayrate pair
    function [pdState11,pdState12,pdState21,pdState22,alphap,alphad] = InterpPoints(obj,p,d)
        % Outputs:
        % pdState11,12,21,22: indices of states above and below p and d
        % alphap,alphad: interpolation weights for the states above
        
        % Inputs:
        % p: gas price
        % d: dayrate
        
        % Obtain price and dayrate states that bound p and d
        pState1 = find(obj.Prices<=p, 1, 'last' );
        pState2 = find(obj.Prices>=p, 1 );
        dState1 = find(obj.DR<=d, 1, 'last' );
        dState2 = find(obj.DR>=d, 1 );  
        if pState2==pState1       % if price is exact hit on a state
            pState2 = pState1 + 1;
        else
        end
        if dState2==dState1       % if DR is exact hit on a state
            dState2 = dState1 + 1;
        else
        end
        
        % Obtain state indices
        pdState11 = pState1 + obj.nP * (dState1-1);
        pdState12 = pState1 + obj.nP * (dState2-1);
        pdState21 = pState2 + obj.nP * (dState1-1);
        pdState22 = pState2 + obj.nP * (dState2-1);         
        
        % Get interpolation weights
        alphap = (p - obj.Prices(pState1)) / (obj.Prices(pState2)-obj.Prices(pState1));
        alphad = (d - obj.DR(dState1)) / (obj.DR(dState2)-obj.DR(dState1));      
    end
    
    
    
    %% Find interpolation points and weights for a price, dayrate pair
    function InterpY = InterpState(obj,y11,y12,y21,y22,alphap,alphad)
        % Outputs:
        % InterpY: vector of interpolated values between y11...y22
        
        % Inputs:
        % y11,...,y22: vectors (all of same length K) of values to
        % interpolate between
        % alphap: weight vector (length K) on y21 vs y11 and y22 vs y12
        % alphad: weight vector (length K) on y12 vs y11 and y22 vs y21
        
        InterpY = y11.*(1-alphap).*(1-alphad) + y12.*(1-alphap).*alphad...
            + y21.*alphap.*(1-alphad) + y22.*alphap.*alphad;
    end 
    
    
    
    %% Forward simulation given real prices and dayrates
    function [FSimDrillProb,FSimDrillProbM,FSimExpireProb,FSimProd,FSimWater,...
            FSimProdM,FSimWaterM,FSimProdCond,FSimWaterCond,FSimProdCondM,FSimWaterCondM,...
            FSimValReal,FSimValReal0,FSimP,FSimDR]...
            = ForwardSim(obj,DrillHaz,DrillHazM,ExpireHaz,Q,W,V)
        % Outputs:
        % FSimDrillProb: N by reportT matrix of drilling probs in lease time
        % FSimDrillProbM, FSimExpireProb: as above but for multi-well
        % drilling and lease expiration
        % FSimProd,FSimWater: N by reportT matrix of production and water
        % use in lease time
        % FSimProdM,FSimWaterM: as above but production and water from
        % multiple wells
        % Production and water variables with "Cond" in the name are
        % conditional on drilling
        % FSimValReal: struct of N by reportT matrices of firm and lessor
        % realized values in each period of the lease
        % FSimValReal0: struct of N-vectors of firm and lessor discounted
        % realized values summed over all periods of the lease
        % FSimP,FSimDR: N by reportT matrices of gas price and day rate in
        % lease time
        
        % Inputs:
        % DrillHaz: nP*nD by N by reportT matrix of drilling hazards
        % DrillHazM,ExpireHaz: as above but for multi-well
        % drilling and lease expiration
        % Q,W: nP*nD by N by reportT matrices of production and water use
        % V: struct of nP*nD by N by reportT matrices of firm and lessor
        % expected values at the start of each lease period
        
        % Find endpoint of simulation in calendar time
        % Extend pddata matrix if needed, using zeros as placeholders for now
        Tpd = max(obj.dataT0i) + obj.reportT;   % endpoint of simulation in calendar time
        pddata = obj.pddata0;                   % placeholder p-d data to use in simulation
        if Tpd>obj.Tpd0                         % need to extend pddata
            pddata = [pddata; zeros(Tpd-obj.Tpd0, size(pddata,2))];
        else
            pddata = pddata(1:Tpd,:);
        end
        
        % Initialize vectors of interpolation points and weights
        pdState11 = zeros(Tpd,1); pdState12 = zeros(Tpd,1);     % p-d state indices
        pdState21 = zeros(Tpd,1); pdState22 = zeros(Tpd,1);
        alphap = zeros(Tpd,1); alphad = zeros(Tpd,1);           % interpolation weights
        
        % Loop through calendar time observations, finding interpolation points and weights.
        % If time step exceeds Tpd0, forecast prices and dayrates
        for t = 1:Tpd
            % If no data at t, get expected price and dayrate at t, using values from t-1
            % and the state transition matrix. Start with expectations at the four
            % interpolation points at t-1, then interpolate
            if pddata(t,4)==0
                % Get expected gas price and dayrate at t
                pd11 = obj.PDT(pdState11(t-1),:) * obj.PDR;
                pd12 = obj.PDT(pdState12(t-1),:) * obj.PDR;
                pd21 = obj.PDT(pdState21(t-1),:) * obj.PDR;
                pd22 = obj.PDT(pdState22(t-1),:) * obj.PDR;
                pddata(t,4:5) = InterpState(obj,pd11,pd12,pd21,pd22,alphap(t-1),alphad(t-1));
                % Ignore oil price
                pddata(t,3) = 0;
                % Increment year and quarter
                ym = pddata(t-1,1) + pddata(t-1,2)/4;
                pddata(t,1) = floor(ym);        % year
                pddata(t,2) = (ym - pddata(t,1)) * 4 + 1;   % quarter
                if pddata(t,2)==0
                    pddata(t,2) = 4;
                else
                end
            else        % real price and dayrate data exist at t                
            end
            % Get interplation points and weights at t
            [pdState11(t),pdState12(t),pdState21(t),pdState22(t),alphap(t),alphad(t)]...
                = InterpPoints(obj,pddata(t,4),pddata(t,5));
        end
             
        % For each unit period, record units' price and dayrate in lease time
        % Initialize output matrices
        FSimP = zeros(obj.N,obj.reportT);
        FSimDR = zeros(obj.N,obj.reportT);
        % Loop through simulation times
        for s = 1:obj.reportT
            tvec = obj.dataT0i + s;                 % calendar time index for each unit
            % Capture prices and dayrates for period s
            FSimP(:,s) = pddata(tvec,4);
            FSimDR(:,s) = pddata(tvec,5);
        end
        
        % For each calendar time period, get interpolation points by unit
        % Initialize matrices of indices. Each is N by reportT
        IND11 = zeros(obj.N,obj.reportT); IND12 = zeros(obj.N,obj.reportT); 
        IND21 = zeros(obj.N,obj.reportT); IND22 = zeros(obj.N,obj.reportT);
        J = [1:obj.N]';         % unit indices for use in linear indexing
        % Loop through simulation in lease time
        for s = 1:obj.reportT
            tvec = obj.dataT0i + s;     % calendar time index for each unit
            % Use linear indexing to find correct interpolation points
            IND11(:,s) = sub2ind([obj.nP*obj.nD obj.N],pdState11(tvec), J);     % linear indices
            IND12(:,s) = sub2ind([obj.nP*obj.nD obj.N],pdState12(tvec), J);
            IND21(:,s) = sub2ind([obj.nP*obj.nD obj.N],pdState21(tvec), J);
            IND22(:,s) = sub2ind([obj.nP*obj.nD obj.N],pdState22(tvec), J); 
        end
        
        % For each unit period, get drilling probabilities, production, and water
        % use, by unit
        % Initialize output matrices
        FSimDrillProb = zeros(obj.N,obj.reportT);
        FSimDrillProbM = zeros(obj.N,obj.reportT);
        FSimExpireProb = zeros(obj.N,obj.reportT);
        FSimProd = zeros(obj.N,obj.reportT); FSimProdM = zeros(obj.N,obj.reportT);
        FSimWater = zeros(obj.N,obj.reportT); FSimWaterM = zeros(obj.N,obj.reportT);
        prnodrill = ones(obj.N,1);      % initialize prob drilling hasn't happened yet
        prnodrillm = ones(obj.N,1);     % initialize prob multiwell drilling hasn't happened yet
        % Loop through simulation times
        for s = 1:obj.reportT
            tvec = obj.dataT0i + s;                 % calendar time index for each unit
            ap = alphap(tvec); ad = alphad(tvec);   % unit interpolation weights
            % Interpolate hazards, production, and water use for period s
            dhaz = squeeze(DrillHaz(:,:,s)); 
            dhazm = squeeze(DrillHazM(:,:,s));
            ehaz = squeeze(ExpireHaz(:,:,s));
            prd = dhaz.*squeeze(Q(:,:,s)); prdm = dhazm.*squeeze(Q(:,:,s));
            wtr = dhaz.*squeeze(W(:,:,s)); wtrm = dhazm.*squeeze(W(:,:,s));
            drillhaz = InterpState(obj,dhaz(IND11(:,s)),dhaz(IND12(:,s)),...
                dhaz(IND21(:,s)),dhaz(IND22(:,s)),ap,ad);
            drillhazm = InterpState(obj,dhazm(IND11(:,s)),dhazm(IND12(:,s)),...
                dhazm(IND21(:,s)),dhazm(IND22(:,s)),ap,ad);
            exphaz = InterpState(obj,ehaz(IND11(:,s)),ehaz(IND12(:,s)),...
                ehaz(IND21(:,s)),ehaz(IND22(:,s)),ap,ad);
            prod = InterpState(obj,prd(IND11(:,s)),prd(IND12(:,s)),...
                prd(IND21(:,s)),prd(IND22(:,s)),ap,ad);
            water = InterpState(obj,wtr(IND11(:,s)),wtr(IND12(:,s)),...
                wtr(IND21(:,s)),wtr(IND22(:,s)),ap,ad);
            prodm = InterpState(obj,prdm(IND11(:,s)),prdm(IND12(:,s)),...
                prdm(IND21(:,s)),prdm(IND22(:,s)),ap,ad);
            waterm = InterpState(obj,wtrm(IND11(:,s)),wtrm(IND12(:,s)),...
                wtrm(IND21(:,s)),wtrm(IND22(:,s)),ap,ad);
            % Compute per-period drilling probabilities, production, and
            % water use
            FSimDrillProb(:,s) = prnodrill .* drillhaz;
            FSimDrillProbM(:,s) = prnodrillm .* drillhazm;
            FSimExpireProb(:,s) = prnodrill .* exphaz;
            FSimProd(:,s) = prnodrill .* prod; FSimProdM(:,s) = prnodrillm .* prodm;
            FSimWater(:,s) = prnodrill .* water; FSimWaterM(:,s) = prnodrillm .* waterm;
            prnodrill = prnodrill - FSimDrillProb(:,s) - FSimExpireProb(:,s);  
            prnodrillm = prnodrillm - FSimDrillProbM(:,s) - FSimExpireProb(:,s); 
        end
        
        % Compute production and water use conditional on drilling
        FSimProdCond = FSimProd ./ FSimDrillProb;
        FSimWaterCond = FSimWater ./ FSimDrillProb;
        FSimProdCondM = FSimProdM ./ FSimDrillProbM;
        FSimWaterCondM = FSimWaterM ./ FSimDrillProbM;
            
        % Create matrix of firm and lessor realized value in each lease period, for all states
        % In each period, this equals V minus extend prob. * continuation val
        % Start by creating continuation values by multiplying V by delta*PDT
        % In last simulated period, don't subtract the continuation value
        CV.Firm = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
        CV.Roy = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
        CV.LC = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
        CV.Rent = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
        CV.ExtBonus = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
        for s = 1:obj.reportT-1
            CV.Firm(:,:,s) = obj.delta * obj.PDT * V.Firm(:,:,s+1);
            CV.Roy(:,:,s) = obj.delta * obj.PDT * V.Roy(:,:,s+1);
            CV.LC(:,:,s) = obj.delta * obj.PDT * V.LC(:,:,s+1);
            CV.Rent(:,:,s) = obj.delta * obj.PDT * V.Rent(:,:,s+1);
            CV.ExtBonus(:,:,s) = obj.delta * obj.PDT * V.ExtBonus(:,:,s+1);
        end
        % Now create realized values
        ValReal.Firm = V.Firm - (1-DrillHaz-ExpireHaz) .* CV.Firm;
        ValReal.Roy = V.Roy - (1-DrillHaz-ExpireHaz) .* CV.Roy;
        ValReal.LC = V.LC - (1-DrillHaz-ExpireHaz) .* CV.LC;
        ValReal.Rent = V.Rent - (1-DrillHaz-ExpireHaz) .* CV.Rent;
        ValReal.ExtBonus = V.ExtBonus - (1-DrillHaz-ExpireHaz) .* CV.ExtBonus;

        % For each lease period, get realized values by unit
        % Initialize simulated realized values. Unit specific.
        FSimValReal.Firm = zeros(obj.N,obj.reportT); FSimValReal.Roy = zeros(obj.N,obj.reportT);
        FSimValReal.LC = zeros(obj.N,obj.reportT); FSimValReal.Rent = zeros(obj.N,obj.reportT);
        FSimValReal.ExtBonus = zeros(obj.N,obj.reportT);
        prnodrill = ones(obj.N,1);      % initialize prob drilling hasn't happened yet
        % Loop through simulation times. Realized profits multiplied by probability
        % of reaching each period (prnodrill)
        for s = 1:obj.reportT
            tvec = obj.dataT0i + s;                 % calendar time index for each unit
            ap = alphap(tvec); ad = alphad(tvec);   % unit interpolation weights
            % Interpolate realized value for each unit
            vfirm = squeeze(ValReal.Firm(:,:,s));                   % values at s
            vroy = squeeze(ValReal.Roy(:,:,s));
            vlc = squeeze(ValReal.LC(:,:,s));
            vrp = squeeze(ValReal.Rent(:,:,s));
            vx = squeeze(ValReal.ExtBonus(:,:,s));
            FSimValReal.Firm(:,s) = InterpState(obj,vfirm(IND11(:,s)),vfirm(IND12(:,s)),...
                vfirm(IND21(:,s)),vfirm(IND22(:,s)),ap,ad) .* prnodrill;
            FSimValReal.Roy(:,s) = InterpState(obj,vroy(IND11(:,s)),vroy(IND12(:,s)),...
                vroy(IND21(:,s)),vroy(IND22(:,s)),ap,ad) .* prnodrill;
            FSimValReal.LC(:,s) = InterpState(obj,vlc(IND11(:,s)),vlc(IND12(:,s)),...
                vlc(IND21(:,s)),vlc(IND22(:,s)),ap,ad) .* prnodrill;
            FSimValReal.Rent(:,s) = InterpState(obj,vrp(IND11(:,s)),vrp(IND12(:,s)),...
                vrp(IND21(:,s)),vrp(IND22(:,s)),ap,ad) .* prnodrill;
            FSimValReal.ExtBonus(:,s) = InterpState(obj,vx(IND11(:,s)),vx(IND12(:,s)),...
                vx(IND21(:,s)),vx(IND22(:,s)),ap,ad) .* prnodrill;
            % Update probability of continuing
            prnodrill = prnodrill - FSimDrillProb(:,s) - FSimExpireProb(:,s); 
        end
        
        % Obtain total lessor realized value
        FSimValReal.Lessor = FSimValReal.Roy - FSimValReal.LC + FSimValReal.Rent...
            + FSimValReal.ExtBonus;
        
        % Get total discounted (to t=0) realized value over the lease
        DiscVec = obj.delta.^(1:obj.reportT)';   % vector of discount rates
        FSimValReal0.Firm = FSimValReal.Firm * DiscVec;
        FSimValReal0.Roy = FSimValReal.Roy * DiscVec;
        FSimValReal0.LC = FSimValReal.LC * DiscVec;
        FSimValReal0.Rent = FSimValReal.Rent * DiscVec;
        FSimValReal0.ExtBonus = FSimValReal.ExtBonus * DiscVec;
        FSimValReal0.Lessor = FSimValReal0.Roy - FSimValReal0.LC + FSimValReal0.Rent...
            + FSimValReal0.ExtBonus;
    end
    
    
    
    %% Convert forward simulation from unit time to calendar time
    function [CSimDrillProb,CSimDrillProbM,CSimExpireProb,CSimProd,CSimWater,...
            CSimProdM,CSimWaterM,CSimProdCond,CSimWaterCond,CSimProdCondM,CSimWaterCondM,...
            CSimValReal,CSimP,CSimDR]...
            = CalSim(obj,FSimDrillProb,FSimDrillProbM,FSimExpireProb,FSimProd,FSimWater,...
            FSimProdM,FSimWaterM,FSimProdCond,FSimWaterCond,FSimProdCondM,FSimWaterCondM,...
            FSimValReal,FSimP,FSimDR)
        
        % Outputs:
        % Method outputs the input variables below, which are input in
        % terms of each unit's time since unit start (t=1 denotes the first
        % period after unit start), converted to calendar time
        % The first calendar period is given by obj.starty and obj.startq
        % First calendar period is assumed to be the same for all units
        
        % Inputs:
        % FSimDrillProb: N by reportT matrix of drilling probs in lease time
        % FSimDrillProbM, FSimExpireProb: as above but for multi-well
        % drilling and lease expiration
        % FSimProd,FSimWater: N by reportT matrix of production and water
        % use in lease time
        % FSimProdM,FSimWaterM: as above but production and water from
        % multiple wells
        % Production and water variables with "Cond" in the name are
        % conditional on drilling
        % FSimValReal: struct of N by reportT matrices of firm and lessor
        % realized values in each period of the lease
        % FSimP,FSimDR: N by reportT matrices of gas price and day rate in
        % lease time
        
        % Get total number of calendar periods to simulate
        CT = obj.reportT + 1 + max(obj.dataT0i) - obj.starti;
        
        % Initialize outputs
        CSimDrillProb = zeros(obj.N,CT); CSimDrillProbM = zeros(obj.N,CT);
        CSimExpireProb = zeros(obj.N,CT); CSimProd = zeros(obj.N,CT);
        CSimWater = zeros(obj.N,CT); CSimProdM = zeros(obj.N,CT);
        CSimWaterM = zeros(obj.N,CT); CSimProdCond = zeros(obj.N,CT);
        CSimWaterCond = zeros(obj.N,CT); CSimProdCondM = zeros(obj.N,CT);
        CSimWaterCondM = zeros(obj.N,CT); CSimP = zeros(obj.N,CT); 
        CSimDR = zeros(obj.N,CT); 
        CSimValReal.Firm = zeros(obj.N,CT); 
        CSimValReal.Roy = zeros(obj.N,CT);
        CSimValReal.LC = zeros(obj.N,CT);
        CSimValReal.Rent = zeros(obj.N,CT);
        CSimValReal.ExtBonus = zeros(obj.N,CT);
        CSimValReal.Lessor = zeros(obj.N,CT);
        
        % Loop over calendar time periods
        for c = 1:CT
            t = obj.starti + c - 1 - obj.dataT0i;       % unit time corresponding to c
            active = t>0 & t<=obj.reportT;              % active leases
            % Set up linear index for forward sim elements to pull
            J = [1:obj.N]';         % unit indices
            Ja = J(active);         % indices of active leases
            ta = t(active);         % lease time indices for active leases
            ind = sub2ind([obj.N obj.reportT], Ja, ta);      % linear index for forward sim   
            CSimDrillProb(Ja,c) = FSimDrillProb(ind);
            CSimDrillProbM(Ja,c) = FSimDrillProbM(ind);
            CSimExpireProb(Ja,c) = FSimExpireProb(ind);
            CSimProd(Ja,c) = FSimProd(ind);
            CSimWater(Ja,c) = FSimWater(ind);
            CSimProdM(Ja,c) = FSimProdM(ind);
            CSimWaterM(Ja,c) = FSimWaterM(ind);
            CSimProdCond(Ja,c) = FSimProdCond(ind);
            CSimWaterCond(Ja,c) = FSimWaterCond(ind);
            CSimProdCondM(Ja,c) = FSimProdCondM(ind);
            CSimWaterCondM(Ja,c) = FSimWaterCondM(ind);
            CSimP(Ja,c) = FSimP(ind);
            CSimDR(Ja,c) = FSimDR(ind);
            CSimValReal.Firm(Ja,c) = FSimValReal.Firm(ind);
            CSimValReal.Roy(Ja,c) = FSimValReal.Roy(ind);
            CSimValReal.LC(Ja,c) = FSimValReal.LC(ind);
            CSimValReal.Rent(Ja,c) = FSimValReal.Rent(ind);
            CSimValReal.ExtBonus(Ja,c) = FSimValReal.ExtBonus(ind);
            CSimValReal.Lessor(Ja,c) = FSimValReal.Lessor(ind);
        end
        
    end
    
    

    %% Calculate log likelihood
    function [LL, SumSim, SumAct, drop, ProbMat, SpudMat] = LogLike(obj,CSimDrillProb)    
        % Outputs:
        % LL: log likelihood (scalar)
        % SumSim: sum of all simulated drilling
        % SumAct: total number of wells actually drilled
        % drop: number of units dropped due to zero likelihood
        % ProbMat: N by TA+1 matrix of simulated drilling probs
        % SpudMat: N by TA+1 matrix of 0/1 drilling dummies from data
        
        % Inputs:
        % CSimDrillProb: N by TU matrix of simulated drilling probs

        % First add column to obj.obsSpud with a one for every unit that
        % was never drilled
        ActDrill = sum(obj.obsSpud')';  % zero / one for no drill vs drill
        TA = size(obj.obsSpud,2);       % number of periods of observation
        SpudMat = obj.obsSpud;          % zeros and ones by period
        SpudMat(:,TA+1) = ~ActDrill;    % one in last column if never drilled
        
        % Drop columns >TA from CSimDrillProb, and add column with prop of
        % never drilling
        ProbMat = CSimDrillProb(:,1:TA);        % drop extra columns
        ProbDrill = sum(ProbMat')';             % prob drilled in simulation
        ProbMat(:,TA+1) = 1 - ProbDrill;        % prob not drilled in sim
        
        % Get the probability of the observed outcome for each unit
        ProbSpudMat = SpudMat .* ProbMat;
        UnitLike = sum(ProbSpudMat')';      % likelihood of outcome for each unit
        
        % Drop observations with zero likelihood (well drilled with zero
        % acreage leased)
        ind = UnitLike>0;       % units with strictly positive likelihood
        drop = obj.N - sum(ind);    % number of units dropped
        
        % Get log likelihood
        UnitLogLike = log(UnitLike(ind));
        LL = sum(UnitLogLike);
        
        % report sum of simulated and actual drilling
        SumSim = sum(ProbDrill(ind));
        SumAct = sum(ActDrill(ind));
    end
    
    
    
    %% Run entire model and calculate log likelihood
    % Runs, in sequence, the RunPriTerm, ForwardSim, CalSim, and LogLike methods
    function [LL, SumSim, SumAct, drop, ProbMat, SpudMat] = RunLogLike(obj)
        % Outputs:
        % LL: log likelihood (scalar)
        % SumSim: sum of all simulated drilling
        % SumAct: total number of wells actually drilled
        % drop: number of units dropped due to zero likelihood
        % ProbMat: N by TA+1 matrix of simulated drilling probs
        % SpudMat: N by TA+1 matrix of 0/1 drilling dummies from data
        
        % Run primary term model
        [DrillHaz,DrillHazM,ExpireHaz,EV0,EV,Q,W] = RunPriTerm(obj);

        % Time dimension of these results represents unit time
        % t = 1 is the first period after the unit starts
        [FSimDrillProb,FSimDrillProbM,FSimExpireProb,FSimProd,FSimWater,...
                    FSimProdM,FSimWaterM,FSimProdCond,FSimWaterCond,FSimProdCondM,FSimWaterCondM,...
                    FSimValReal,FSimValReal0,FSimP,FSimDR]...
                    = ForwardSim(obj,DrillHaz,DrillHazM,ExpireHaz,Q,W,EV);

        % Convert output to calendar time, starting with obj.starti
        [CSimDrillProb,CSimDrillProbM,CSimExpireProb,CSimProd,CSimWater,...
            CSimProdM,CSimWaterM,CSimProdCond,CSimWaterCond,CSimProdCondM,CSimWaterCondM,...
            CSimValReal,CSimP,CSimDR]...
            = CalSim(obj,FSimDrillProb,FSimDrillProbM,FSimExpireProb,FSimProd,FSimWater,...
            FSimProdM,FSimWaterM,FSimProdCond,FSimWaterCond,FSimProdCondM,FSimWaterCondM,...
            FSimValReal,FSimP,FSimDR);

        % Get log likelihood
        [LL, SumSim, SumAct, drop, ProbMat, SpudMat] = LogLike(obj,CSimDrillProb);        
    end
    
    
    
    %% Run entire model and calculate log likelihood, taking P_w and thetaDA as inputs
    % Instantiates object and then runs RunLogLike. Called by runML.m.
    function [LL, SumSim, SumAct, drop] = LoopLogLike(obj,dirs,params,x)
        % Outputs:
        % LL: log likelihood (scalar)
        % SumSim: sum of all simulated drilling
        % SumAct: total number of wells actually drilled
        % drop: number of units dropped due to zero likelihood
        
        % Inputs:
        % x: 2x1 vector. First element is params.epsScale. Second is params.thetaDA
        
        % Update params struct
        params.epsScale_pretax = x(1);
        params.thetaDA = x(2);
        
        % Instantiate model with updated params
        objt = hbpmodel(dirs,params);
        
        % Get log likelihood
        x           % show guess
        [LL, SumSim, SumAct, drop, ~, ~] = RunLogLike(objt);        
    end    
end
end






























