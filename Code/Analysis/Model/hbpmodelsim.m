%% The class that instantiates the hbpmodelsim object 
% Subclass of hbpmodel that is used for counterfactual simulation
classdef hbpmodelsim < hbpmodel
properties
    % We specify here all of the properties we want to have
    % attached to each object (except those already defined in the
    % superclass)
    dataT
    maxT
    sigmaLogX
    muLogX
end

methods
    %% Constructor
    function obj = hbpmodelsim(dirs,params)
        % Object defns from superclass
        obj = obj@hbpmodel(dirs,params);

        % Productivity standard deviation multiplier. First check to see if
        % ProdMult is included in the params struct
        if sum(strcmp(fieldnames(params), 'ProdMult')) == 1
            prodmult = params.ProdMult;
        else
            prodmult = 1;
        end            
        % Productivity standard deviation multiplier. First check to see if
        % sigmaLogXmult is included in the params struct
        if sum(strcmp(fieldnames(params), 'sigmaLogXmult')) == 1
            sigmult = params.sigmaLogXmult;
        else
            sigmult = 1;
        end        
        
        % Unit productivity parameters: mean and sd of log productivity. 
        % Units are tens of millions of mmBtu
        logX = log(obj.dataX);          % log productivity for each unit in data
        obj.sigmaLogX = std(logX) * sigmult;    % std dev of log(prod)
        % Set muLogX so that E[productivity] = mean(productivity) from data
        obj.muLogX = mean(logX) + log(prodmult); 
        
        % total number of units to simulate
        obj.N = 500;    

        % Set start date at estimation sample start date
        obj.dataT0y = repmat(obj.starty,obj.N,1); obj.dataT0q = repmat(obj.startq,obj.N,1); 
        obj.dataT0i = repmat(obj.starti,obj.N,1);

        % Unit lease terms: royalty (fraction), pri term length (quarters), 
        % lessor cost ($10m), rent ($10m per period), share of unit acreage leased
        obj.dataR = repmat(params.roy,obj.N,1);
        obj.dataT = repmat(params.T,obj.N,1) * obj.perYear;
        obj.dataLC = repmat(params.LC,obj.N,1);
        obj.dataRent = repmat(params.rent,obj.N,1);
        obj.dataLshare = repmat(params.Lshare,obj.N,1);

        % Unit expected production
        % Even draws over productivity distribution
        tempbins1 = linspace(0,1,obj.N+1);
        tempbins1 = (tempbins1(:,1:end-1) + tempbins1(:,2:end)) / 2;
        obj.dataX = logninv(tempbins1,obj.muLogX,obj.sigmaLogX)';

        % Store primary term length as scalar
        obj.maxT = params.T * obj.perYear;      % primary term scalar

        % Max of longest pri term and time-to-build period
        obj.TMAX = max([obj.maxT; obj.thetaTTBt]);
        
        % Drilling costs during max(time-to-build,pri term) and
        % during infinite horizon
        [obj.DC, obj.DCInf] = DrillCosts(obj);        

        % Number of years to simulate
        reportTy = 15;  
        % Simulate max of reportTy*perYear and TMAX+1
        obj.reportT = max([reportTy * obj.perYear; obj.TMAX+1]);
    end
    
    
    
    %% Find the lessor's optimal bonus given firm and lessor lease or extension payoffs
    function Bonus = optBonus(obj,ValFirmx,ValLessorx)
        % Outputs:
        % BonusIndex: np*nD vector of firm that is indifferent to paying
        % the optimal bonus
        % Bonus: nP*nD vector of optimal bonus
        
        % Inputs:
        % ValFirmx: nP*nD by N matrix of firm expected values next period if
        % it signs the lease or extension
        % ValLessorx: nP*nD by N matrix of lessor expected values next period if
        % the firm signs the lease or extension (values from royalties, LC,
        % rent, and future bonuses)

        % Initialize matrix of expected lessor values at different bonuses
        % Expectation to be taken over firm types
        lessorvals = zeros(obj.nP*obj.nD,obj.N);

        % cycle through each possible bonus value and obtain lessor value at each
        for i = 1:obj.N
            bonusi = ValFirmx(:,i);      % value of firm i
            firmvalwithbonus = ValFirmx - bonusi;
            lessorvalwithbonus = ValLessorx + bonusi;
            lessorvalwithbonus(firmvalwithbonus<0) = 0; % firms with neg value don't participate
            % return lessor's expected value over firm types
            lessorvals(:,i) = sum(lessorvalwithbonus,2) / obj.N;
        end
 
        % Obtain the index for the optimal bonus. Note that this may be negative
        [~, BonusIndexraw] = max(lessorvals,[],2);      
        
        % Use linear indexing to find the optimal bonus
        I = (1:size(ValFirmx,1)) .';
        J = BonusIndexraw;
        BonusInd2 = sub2ind(size(ValFirmx),I,J);        
        BonusRaw = ValFirmx(BonusInd2);
        
        % Replace negative bonuses with zero
        negBonus = BonusRaw<0;          % find negatives
        Bonus = BonusRaw;
        Bonus(negBonus) = 0;            % replace with zero bonus
    end

    

    %% Simulate multi-well and extension drilling hazards and payoffs
    function [DrillHazM,DrillHazx,ExpireHazx,EVx,EVm]...
            = MultWellAndExtension(obj,PiDrill,PiDrillInf,RoyDrill,RoyDrillInf)
        % Outputs:
        % DrillHazM: nP*nD by N by reportT matrix of multi-well drilling hazards
        % DrillHazx: nP*nD by N by reportT matrix of drilling hazards
        % during a lease extension period
        % ExpireHazx: nP*nD by N by reportT matrix of expiration hazards
        % during a lease extension period
        % EVx: struct of expected values at the start of each period of the
        % extension. nP*nD by N by reportT.
        % EVm: struct of expected values for multi-well drilling, at the start of 
        % each period. nP*nD by N by reportT.
        
        % Inputs:
        % PiDrill, RoyDrill: nP*nD by N by TMAX matrices of firm drlg profits and royalties
        % PiDrillInf, RoyDrillInf: nP*nD by N by matrices of firm drlg profits
        % and royalties in inf horizon
        
        % Compute per-well continuation values and multi-well drlg hazards if obj.Wells>1.
        % EVm gives per-well values for additional wells at the start of each period
        if obj.Wells>1
            tempRent = zeros(obj.N,1);      % no rent after first well drilled
            [EVm,DrillHazM,ExpireHazM] = ContinuationValues(obj,PiDrill,PiDrillInf,...
                RoyDrill,RoyDrillInf,tempRent,obj.dataLshare);
        else
            EVm.Firm = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1);       % no continuation values
            EVm.Roy = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1); 
            EVm.LC = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1); 
            EVm.Rent = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1); 
            EVm.Bonus = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1); 
            DrillHazM = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1); 
            ExpireHazM = zeros(obj.nP*obj.nD,obj.N,obj.TMAX+1); 
        end

        % Extension values EVx. Value if unit is extended before first well is drilled
        % If rent==0 & obj.Wells>1, then extension val is just EVc times obj.Wells
        % If rent==0 & obj.Wells==1, need to call ContinuationValues
        % If rent>0, need to call ContinuationValues, using the multi-well
        % continuation values as inputs
        if max(obj.dataRent)==0 && obj.Wells>1
            EVx.Firm = obj.Wells * EVm.Firm; EVx.Roy = obj.Wells * EVm.Roy;
            EVx.LC = obj.Wells * EVm.LC; EVx.Rent = obj.Wells * EVm.Rent;
            EVx.Bonus = obj.Wells * EVm.Bonus;
            DrillHazx = DrillHazM; ExpireHazx = ExpireHazM;
        else
            [EVx,DrillHazx,ExpireHazx] = ContinuationValues(obj,PiDrill,PiDrillInf,...
                RoyDrill,RoyDrillInf,obj.dataRent,obj.dataLshare,EVm,DrillHazM);
        end
        
        % Extend continuation and extension drilling and expiration hazards to reportT
        % Do same with values EVx
        td = obj.reportT - (obj.TMAX+1);    % number of periods to add
        if td>0
            DrillHazM = cat(3, DrillHazM, repmat(DrillHazM(:,:,obj.TMAX+1),1,1,td));
            DrillHazx = cat(3, DrillHazx, repmat(DrillHazx(:,:,obj.TMAX+1),1,1,td));
            ExpireHazx = cat(3, ExpireHazx, repmat(ExpireHazx(:,:,obj.TMAX+1),1,1,td));
            EVx.Firm = cat(3, EVx.Firm, repmat(EVx.Firm(:,:,obj.TMAX+1),1,1,td));
            EVx.Roy = cat(3, EVx.Roy, repmat(EVx.Roy(:,:,obj.TMAX+1),1,1,td));
            EVx.LC = cat(3, EVx.LC, repmat(EVx.LC(:,:,obj.TMAX+1),1,1,td));
            EVx.Rent = cat(3, EVx.Rent, repmat(EVx.Rent(:,:,obj.TMAX+1),1,1,td));
            EVx.Bonus = cat(3, EVx.Bonus, repmat(EVx.Bonus(:,:,obj.TMAX+1),1,1,td));
        else
        end                
    end

    
    
    %% Simulate primary term
    function [DrillHaz,ExpireHaz,EV0,EV]...
            = RunPriTerm(obj,DrillHazM,DrillHazx,ExpireHazx,EVx,EVm,PiDrill,RoyDrill)
        % Outputs:
        % DrillHaz: nP*nD by N by reportT matrix of drilling hazards
        % ExpireHaz: nP*nD by N by reportT matrix of expiration hazards
        % EV0: struct of expected values, at lease start, for firm,
        % royalty, lessor cost, rent, and extension bonus payments. All expected
        % values are nP*nD by N. Original signing bonus not included.
        % EV: struct of expected values at the start of each period of the
        % lease, including at least one extension period. nP*nD by N by reportT.
        % Above outputs include extension period to the extent reportT > maxT

        % Inputs:
        % DrillHazM: nP*nD by N by reportT matrix of multi-well drilling hazards
        % DrillHazx: nP*nD by N by reportT matrix of drilling hazards
        % during a lease extension period
        % ExpireHazx: nP*nD by N by reportT matrix of expiration hazards
        % during a lease extension period
        % EVx: struct of expected values at the start of each period of the
        % extension. nP*nD by N by reportT.
        % EVm: struct of expected values for multi-well drilling, at the start of 
        % each period. nP*nD by N by reportT.       
        % PiDrill, RoyDrill: nP*nD by N by TMAX matrices of firm drlg profits and royalties
        
        
        % If lease is infinite horizon, the extension values contain the
        % info we need. If not, need to compute extension bonus and then
        % backward recursion through primary term
        if obj.maxT==0          % if infinite horizon
            DrillHaz = DrillHazx; ExpireHaz = ExpireHazx;
            EV.Firm = EVx.Firm; EV.Roy = EVx.Roy; EV.LC = EVx.LC;
            EV.Rent = EVx.Rent; EV.Bonus = EVx.Bonus;
            EV0.Firm = obj.delta * obj.PDT * squeeze(EVx.Firm(:,:,1));
            EV0.Roy = obj.delta * obj.PDT * squeeze(EVx.Roy(:,:,1));
            EV0.LC = obj.delta * obj.PDT * squeeze(EVx.LC(:,:,1));
            EV0.Rent = obj.delta * obj.PDT * squeeze(EVx.Rent(:,:,1));
            EV0.Bonus = obj.delta * obj.PDT * squeeze(EVx.Bonus(:,:,1));
        else
            % Initialize hazard and EV matrices
            DrillHaz = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
            ExpireHaz = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
            EV.Firm = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
            EV.Roy = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
            EV.LC = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
            EV.Rent = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
            EV.Bonus = zeros(obj.nP*obj.nD,obj.N,obj.reportT);
            
            % Hazards after expiration are the extension hazards
            DrillHaz(:,:,obj.maxT+1:obj.reportT) = DrillHazx(:,:,obj.maxT+1:obj.reportT);
            ExpireHaz(:,:,obj.maxT+1:obj.reportT) = ExpireHazx(:,:,obj.maxT+1:obj.reportT);
            
            % Obtain firm and total lessor value, as expected before the start of the extension
            % (i.e. at the end of period maxT)
            ValFirmx = obj.delta * obj.PDT * squeeze(EVx.Firm(:,:,obj.maxT+1));
            ValRoyx = obj.delta * obj.PDT * squeeze(EVx.Roy(:,:,obj.maxT+1));
            ValLCx = obj.delta * obj.PDT * squeeze(EVx.LC(:,:,obj.maxT+1));
            ValRentx = obj.delta * obj.PDT * squeeze(EVx.Rent(:,:,obj.maxT+1));            
            ValLessorx = ValRoyx - ValLCx + ValRentx;

            % Obtain optimal bonus and index of the firm that is the last to stay in
            Bonus = optBonus(obj, ValFirmx, ValLessorx);    
            
            % Incorporate bonus into firm and lessor values at the "end" of period maxT
            % These values become Vnext in the Bellman iteration for period maxT
            Vnext.Firm = ValFirmx - Bonus;
            Dropout = Vnext.Firm<0;
            % Lessor continuation values are zero for firms that drop out
            Vnext.Roy = ValRoyx; Vnext.Roy(Dropout) = 0;
            Vnext.LC = ValLCx; Vnext.LC(Dropout) = 0;
            Vnext.Rent = ValRentx; Vnext.Rent(Dropout) = 0;
            Vnext.Bonus = repmat(Bonus,1,obj.N); Vnext.Bonus(Dropout) = 0;    
            
            % Backwards recursion through primary term, calling BellmanIt each time
            for s = 1:obj.maxT
                t = obj.maxT - s + 1;       % forward time
                % Obtain period profits and royalties
                tempPi = squeeze(PiDrill(:,:,t)); tempRoy = squeeze(RoyDrill(:,:,t));
                % Obtain elements of the Vnextm struct
                Vnextm.Firm = obj.delta * obj.PDT * squeeze(EVm.Firm(:,:,t+1));
                Vnextm.Roy = obj.delta * obj.PDT * squeeze(EVm.Roy(:,:,t+1));
                Vnextm.LC = obj.delta * obj.PDT * squeeze(EVm.LC(:,:,t+1));
                % Obtain Vm (multi-well value at start of this period)
                Vm = squeeze(EVm.Firm(:,:,t));
                % Obtain drillhazm (haz of drilling mult wells this period)
                drillhazm = squeeze(DrillHazM(:,:,t));
                % Execute Bellman step
                [EVt,DrillHaz(:,:,t),ExpireHaz(:,:,t),~] = BellmanIt(obj,Vnext,...
                    tempPi,tempRoy,obj.dataRent,obj.dataLshare,Vnextm,Vm,drillhazm); 
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
            
            % Extract expected values at lease signing
            EV0.Firm = Vnext.Firm;
            EV0.Roy = Vnext.Roy;
            EV0.LC = Vnext.LC;
            EV0.Rent = Vnext.Rent;
            EV0.Bonus = Vnext.Bonus;      
            
            % Extend EV through reportT using extension values
            EV.Firm(:,:,obj.maxT+1:obj.reportT) = EVx.Firm(:,:,obj.maxT+1:obj.reportT);
            EV.Roy(:,:,obj.maxT+1:obj.reportT) = EVx.Roy(:,:,obj.maxT+1:obj.reportT);
            EV.LC(:,:,obj.maxT+1:obj.reportT) = EVx.LC(:,:,obj.maxT+1:obj.reportT);
            EV.Rent(:,:,obj.maxT+1:obj.reportT) = EVx.Rent(:,:,obj.maxT+1:obj.reportT);
            EV.Bonus(:,:,obj.maxT+1:obj.reportT) = EVx.Bonus(:,:,obj.maxT+1:obj.reportT);  
        end
    
    end
    
    
    
    %% Simulate drilling hazards and payoffs through reportT
    % Runs, in sequence:
    % Payoffs: get per-period drilling payoffs
    % MultWellAndExtension: gets extension and per-well multi-well hazards and payoffs
    % RunPriTerm: runs the primary term
    function [DrillHaz,DrillHazM,ExpireHaz,EV0,EV,Q,W] = DrillHazSim(obj)    
        % Outputs:
        % DrillHaz: nP*nD by N by reportT matrix of drilling hazards
        % DrillHazM: nP*nD by N by reportT matrix of multi-well drilling hazards
        % ExpireHaz: nP*nD by N by reportT matrix of expiration hazards
        % EV0: struct of expected values, at lease start, for firm,
        % royalty, lessor cost, rent, and extension bonus payments. All expected
        % values are nP*nD by N. Original signing bonus not included.
        % EV: struct of expected values at the start of each period of the
        % lease, including at least one extension period. nP*nD by N by reportT.
        % Q, W: production and water use if drilled. nP*nD by N by reportT

        % Compute per-period payoffs for t = 1:TMAX and inf horizon
        [PiDrill, PiDrillInf, RoyDrill, RoyDrillInf, Q, QInf, W, WInf] = Payoffs(obj,obj.dataLshare);
        
        % Extend Q and W matrices to reportT using QInf and WInf
        td = obj.reportT - obj.TMAX;        % number of periods to add
        Q = cat(3, Q, repmat(QInf,1,1,td));
        W = cat(3, W, repmat(WInf,1,1,td));
        
        % Compute per-well hazards and values for multi-well drilling (zero
        % if Wells==1) and extension hazards and values
        [DrillHazM,DrillHazx,ExpireHazx,EVx,EVm]...
            = MultWellAndExtension(obj,PiDrill,PiDrillInf,RoyDrill,RoyDrillInf);
        
        % Run primary term
        [DrillHaz,ExpireHaz,EV0,EV]...
            = RunPriTerm(obj,DrillHazM,DrillHazx,ExpireHazx,EVx,EVm,PiDrill,RoyDrill);
    end


    
    
    %% Compute expectation over firm types of all values at lease signing
    function [EV0,EVB0] = LessorExpectVal(obj,V0,VB0)
        % Outputs:
        % EV0: struct of firm and lessor expected values contingent on state at
        % lease signing. nP*nD vector
        % EVB0: as above but taking into account the optimal bonus

        % Inputs:
        % V0: struct of firm and lessor expected values contingent on firm type
        % and on state at lease signing. nP*nD by N matrix
        % Vb0: as above but taking into account the optimal bonus
        % Dropout: nP*nD by N matrix of logicals for which firms do not sign
        % the lease in each state
        
        % Struct components are .Firm, .Roy, .LC, .Rent, .Bonus, .ExtBonus,
        % and .Lessor. EV0 does not include .Bonus.

        % Take valuation expectations over firm types
        EV0.Firm = sum(V0.Firm,2) / obj.N; EVB0.Firm = sum(VB0.Firm,2) / obj.N;
        EV0.Roy = sum(V0.Roy,2) / obj.N; EVB0.Roy = sum(VB0.Roy,2) / obj.N;  
        EV0.LC = sum(V0.LC,2) / obj.N; EVB0.LC = sum(VB0.LC,2) / obj.N;  
        EV0.Rent = sum(V0.Rent,2) / obj.N; EVB0.Rent = sum(VB0.Rent,2) / obj.N;  
        EVB0.Bonus = sum(VB0.Bonus,2) / obj.N;  
        EV0.ExtBonus = sum(V0.ExtBonus,2) / obj.N; EVB0.ExtBonus = sum(VB0.ExtBonus,2) / obj.N;  
        EV0.Lessor = sum(V0.Lessor,2) / obj.N; EVB0.Lessor = sum(VB0.Lessor,2) / obj.N; 
    end
    
    

    %% Compute optimal bonus at signing and expected values including bonus
    function [EV0,EVB0,V,Dropout,ShareFirms,Bonus] = SimEV0(obj,V0,V)
        % Method runs the optBonus and LessorExpectVal
        % methods on the output of DrillHazSim to find the optimal
        % state-contingent bonuses and calculate firm and lessor
        % expected-values at the beginning of the lease
        % Outputs:
        % EV0: struct of firm and lessor expected values contingent on state at
        % lease signing. nP*nD vector
        % EVB0: as above but taking into account the optimal bonus


        % ShareFirms: nP*nD vector indictating the fraction of firms
        % signing the lease
        
        % Inputs:
        % V0: struct of expected values, at lease start, for firm,
        % royalty, lessor cost, rent, and extension bonus payments. All expected
        % values are nP*nD by N. Original signing bonus not included.
        % V: struct of nP*nD by N by reportT matrices of firm and lessor
        % expected values at the start of each lease period     

        % Rename V.Bonus to V.ExtBonus
        V.ExtBonus = V.Bonus;
        fields = 'Bonus';
        V = rmfield(V,fields);
        
        % Obtain value of lease to lessor. Rename V0.Bonus V0.ExtBonus
        V0.ExtBonus = V0.Bonus;
        V0.Bonus = zeros(obj.nP*obj.nD,obj.N);
        V0.Lessor = V0.Roy - V0.LC + V0.Rent + V0.ExtBonus;

        % Compute optimal state-contingent bonus
        Bonus = optBonus(obj, V0.Firm, V0.Lessor);  

        % Compute bonus-inclusive values VB. Account for non-participation of firms
        % with value less than zero
        VB0 = V0;
        VB0.Firm = V0.Firm - Bonus;
        Dropout = VB0.Firm<0;
        VB0.Firm(Dropout) = 0;      % firms that don't partcipate
        % Lessor values are zero for firms that drop out
        VB0.Roy(Dropout) = 0; VB0.LC(Dropout) = 0;
        VB0.Rent(Dropout) = 0; VB0.ExtBonus(Dropout) = 0;
        VB0.Bonus = repmat(Bonus,1,obj.N); VB0.Bonus(Dropout) = 0;  

        % Calculate total value for lessor, accounting for bonus
        VB0.Lessor = VB0.Roy - VB0.LC + VB0.Rent + VB0.Bonus + VB0.ExtBonus;

        % Calculate share of firms that participate in each state
        ShareFirms = 1 - sum(Dropout,2) / obj.N;

        % Compute expectation over firm types of all values at lease signing
        [EV0,EVB0] = LessorExpectVal(obj,V0,VB0);        
    end
    
    
    
    %% Convert drilling and expiration hazards to probabilities, conditional on state
    % at lease signing. Also obtain expected water use and production each
    % period (conditional on state at lease signing)
    function [DrillProb,ExpireProb,DrillProbM,Prod,Water,ProdM,WaterM,ProdCond,...
            WaterCond,ProdCondM,WaterCondM] = HazToProb(obj,DrillHaz,ExpireHaz,DrillHazM,Q,W)
        % Outputs:
        % DrillProb, ExpireProb: nP*nD by N by size(DrillHaz,3) matrix of drilling
        % and expiration probabilities, conditional on price,dayrate state at lease
        % signing
        % DrillProbM: nP*nD by N by size(DrillHaz,3) matrix of multi-well drilling
        % probabilities, conditional on price,dayrate state at lease signing
        % Prod,Water: nP*nD by N by size(DrillHaz,3) matrix of expected production
        % and water use, conditional on price,dayrate state at lease signing
        % ProdM,WaterM: same as above but associated with multiple wells
        % ProdCond,WaterCond,ProdCondM,WaterCondM: same as above, but
        % conditional on drilling
        
        % Inputs:
        % DrillHaz, ExpireHaz: hazard of drilling or expiring this period.
        % nP*nD by N by size(DrillHaz,3)
        % DrillHazM: hazard of drilling multiple wells this period.
        % nP*nD by N by size(DrillHaz,3)
        % Q,W: nP*nD by N by reportT matrices of production and water use
        
        % Initialize outputs
        DrillProb = zeros(obj.nP*obj.nD,obj.N,size(DrillHaz,3));
        ExpireProb = zeros(obj.nP*obj.nD,obj.N,size(DrillHaz,3));
        DrillProbM = zeros(obj.nP*obj.nD,obj.N,size(DrillHaz,3));
        Prod = zeros(obj.nP*obj.nD,obj.N,size(DrillHaz,3)); 
        Water = zeros(obj.nP*obj.nD,obj.N,size(DrillHaz,3));
        ProdM = zeros(obj.nP*obj.nD,obj.N,size(DrillHaz,3));
        WaterM = zeros(obj.nP*obj.nD,obj.N,size(DrillHaz,3));
        
        % Prob of drilling in first period is just the first period hazard,
        % iterated by PDT
        DrillProb(:,:,1) = obj.PDT * DrillHaz(:,:,1);
        ExpireProb(:,:,1) = obj.PDT * ExpireHaz(:,:,1);
        DrillProbM(:,:,1) = obj.PDT * DrillHazM(:,:,1);
        % Production and water use in the first period
        Prod(:,:,1) = obj.PDT * (DrillHaz(:,:,1).*Q(:,:,1));
        ProdM(:,:,1) = (obj.Wells-1) * obj.PDT * (DrillHazM(:,:,1).*Q(:,:,1));
        Water(:,:,1) = obj.PDT * (DrillHaz(:,:,1).*W(:,:,1));
        WaterM(:,:,1) = (obj.Wells-1) * obj.PDT * (DrillHazM(:,:,1).*W(:,:,1)); 
        
        % Initialize loop
        prnodrill = 1 - DrillProb(:,:,1) - ExpireProb(:,:,1);     % prob in risk set
        prnodrillm = 1 - DrillProbM(:,:,1) - ExpireProb(:,:,1);   % prob in multiwell risk set
        trans = obj.PDT^2;                                  % future price distribution
        
        % loop to end of conditional probabilities. 
        for t = 2:size(DrillHaz,3)
            DrillProb(:,:,t) = prnodrill .* (trans * DrillHaz(:,:,t));
            DrillProbM(:,:,t) = prnodrillm .* (trans * DrillHazM(:,:,t));
            ExpireProb(:,:,t) = prnodrill .* (trans * ExpireHaz(:,:,t));
            Prod(:,:,t) = prnodrill .* (trans * (DrillHaz(:,:,t) .* Q(:,:,t)));
            ProdM(:,:,t) = (obj.Wells-1) * prnodrillm .* (trans * (DrillHazM(:,:,t) .* Q(:,:,t)));
            Water(:,:,t) = prnodrill .* (trans * (DrillHaz(:,:,t) .* W(:,:,t)));
            WaterM(:,:,t) = (obj.Wells-1) * prnodrillm .* (trans * (DrillHazM(:,:,t) .* W(:,:,t)));
            % update prnodrill and trans
            prnodrill = prnodrill - DrillProb(:,:,t) - ExpireProb(:,:,t);
            prnodrillm = prnodrillm - DrillProbM(:,:,t) - ExpireProb(:,:,t);
            trans = trans * obj.PDT;
        end      
        
        % Production and water use each period conditional on drilling each
        % period (and conditional on initial state and on type)
        ProdCond = Prod ./ DrillProb; WaterCond = Water ./ DrillProb;
        ProdCondM = ProdM ./ DrillProbM; WaterCondM = WaterM ./ DrillProbM;
    end


    
    
    %% Compute expectation over firm types of drilling probs and hazards at lease signing
    function EDrillS = LessorExpectDrill(obj,DrillProb,ExpireProb,DrillProbM,...
            Dropout,ShareFirms,Prod,Water,ProdM,WaterM)
        % Outputs EDrillS, struct that contains these nP*nD by size(DrillProb,3) matrices:
        % EDrillHaz through EDrillProbM: expected drilling hazards and
        % probabilities, taken over firm types
        % EDrillHazB through EDrillProbMB: as above but taking into account the optimal bonus
        % All expectations taken conditional on state at lease signing
        % EProd,EProdM,EProdB,EProdMB: first and multi-well production 
        % (*B accounts for bonus)
        % EWater,EWaterM,EWaterB,EWaterMB: same as prod but for water input
        % Same as above but ending in *Cond: expected production / water
        % conditional on drilling

        % Inputs:
        % DrillHaz, ExpireHaz: hazard of drilling or expiring this period.
        % nP*nD by N by size(DrillProb,3)
        % DrillHazM: hazard of drilling multiple wells this period.
        % nP*nD by N by size(DrillProb,3)
        % DrillProb,ExpireProb,DrillProbM: probabilities rather than
        % hazards. All nP*nD by N by size(DrillProb,3)
        % Dropout: nP*nD by N matrix of logicals for which firms do not sign
        % the lease in each state
        % ShareFirms: nP*nD vector indictating the fraction of firms
        % signing the lease
        % Prod,Water: nP*nD by N by size(DrillProb,3) matrices of expected production
        % and water use, conditional on price,dayrate state at lease signing
        % ProdM,WaterM: same as above but associated with multiple wells
        
        T = size(DrillProb,3);       % time dimension
        
        % Get expected drilling probs as average over types
        EDrillProb = squeeze(sum(DrillProb,2) / obj.N);
        EDrillProbM = squeeze(sum(DrillProbM,2) / obj.N);
        EExpireProb = squeeze(sum(ExpireProb,2) / obj.N);
        
        % Initialize probabilities accounting for bonus
        EDrillProbB = zeros(obj.nP*obj.nD,T);
        EDrillProbMB = zeros(obj.nP*obj.nD,T);
        EExpireProbB = zeros(obj.nP*obj.nD,T);
        
        % Loop through times to get expected probs, accounting for bonus
        for t = 1:T
            temp = squeeze(DrillProb(:,:,t));
            temp(Dropout) = 0;
            EDrillProbB(:,t) = squeeze(sum(temp,2) / obj.N);
            temp = squeeze(DrillProbM(:,:,t));
            temp(Dropout) = 0;
            EDrillProbMB(:,t) = squeeze(sum(temp,2) / obj.N);
            temp = squeeze(ExpireProb(:,:,t));
            temp(Dropout) = 0;
            EExpireProbB(:,t) = squeeze(sum(temp,2) / obj.N);
        end       

        % Initialize hazard matrices
        EDrillHaz = zeros(obj.nP*obj.nD,T); EDrillHazB = zeros(obj.nP*obj.nD,T);
        EDrillHazM = zeros(obj.nP*obj.nD,T); EDrillHazMB = zeros(obj.nP*obj.nD,T);
        EExpireHaz = zeros(obj.nP*obj.nD,T); EExpireHazB = zeros(obj.nP*obj.nD,T);
        
        % First period hazard is just the first period drilling prob
        EDrillHaz(:,1) = EDrillProb(:,1); EDrillHazB(:,1) = EDrillProbB(:,1) ./ ShareFirms;
        EDrillHazM(:,1) = EDrillProbM(:,1); EDrillHazMB(:,1) = EDrillProbMB(:,1) ./ ShareFirms;
        EExpireHaz(:,1) = EExpireProb(:,1); EExpireHazB(:,1) = EExpireProbB(:,1) ./ ShareFirms;       
    
        % Initialize loop
        prnodrill = 1 - EDrillProb(:,1) - EExpireProb(:,1);       % prob in risk set
        prnodrillm = 1 - EDrillProbM(:,1) - EExpireProb(:,1);     % prob in multiwell risk set
        prnodrillb = ShareFirms - EDrillProbB(:,1) - EExpireProbB(:,1);
        prnodrillmb = ShareFirms - EDrillProbMB(:,1) - EExpireProbB(:,1);
        
        % Loop to end of drilling probs
        for t = 2:T
            EDrillHaz(:,t) = EDrillProb(:,t) ./ prnodrill;
            EDrillHazM(:,t) = EDrillProbM(:,t) ./ prnodrillm;
            EExpireHaz(:,t) = EExpireProb(:,t) ./ prnodrill;
            prnodrill = prnodrill - EDrillProb(:,t) - EExpireProb(:,t);
            prnodrillm = prnodrillm - EDrillProbM(:,t) - EExpireProb(:,t);
            EDrillHazB(:,t) = EDrillProbB(:,t) ./ prnodrillb;
            EDrillHazMB(:,t) = EDrillProbMB(:,t) ./ prnodrillmb;
            EExpireHazB(:,t) = EExpireProbB(:,t) ./ prnodrillb;
            prnodrillb = prnodrillb - EDrillProbB(:,t) - EExpireProbB(:,t);
            prnodrillmb = prnodrillmb - EDrillProbMB(:,t) - EExpireProbB(:,t);
        end
        
        % Get expected first-well and multi-well production and water use
        EProd = squeeze(sum(Prod,2) / obj.N); EWater = squeeze(sum(Water,2) / obj.N);
        EProdM = squeeze(sum(ProdM,2) / obj.N); EWaterM = squeeze(sum(WaterM,2) / obj.N);
        
        % Initialize production and water matrices that account for bonus
        EProdB = zeros(obj.nP*obj.nD,T); EWaterB = zeros(obj.nP*obj.nD,T);
        EProdMB = zeros(obj.nP*obj.nD,T); EWaterMB = zeros(obj.nP*obj.nD,T);
        
        % Loop through times to get expected prod and water, accounting for bonus
        for t = 1:T
            temp = squeeze(Prod(:,:,t));
            temp(Dropout) = 0;
            EProdB(:,t) = squeeze(sum(temp,2) / obj.N);
            temp = squeeze(Water(:,:,t));
            temp(Dropout) = 0;
            EWaterB(:,t) = squeeze(sum(temp,2) / obj.N);
            temp = squeeze(ProdM(:,:,t));
            temp(Dropout) = 0;
            EProdMB(:,t) = squeeze(sum(temp,2) / obj.N);
            temp = squeeze(WaterM(:,:,t));
            temp(Dropout) = 0;
            EWaterMB(:,t) = squeeze(sum(temp,2) / obj.N);
        end         

        % Expected first-well production and water use, conditional on drilling
        EProdCond = EProd ./ EDrillProb; 
        EWaterCond = EWater ./ EDrillProb;
        EProdCondB = EProdB ./ EDrillProbB; 
        EWaterCondB = EWaterB ./ EDrillProbB;        
 
        % Expected multi-well production and water use, conditional on drilling
        EProdCondM = EProdM ./ EDrillProbM; 
        EWaterCondM = EWaterM ./ EDrillProbM;
        EProdCondMB = EProdMB ./ EDrillProbMB; 
        EWaterCondMB = EWaterMB ./ EDrillProbMB; 
 
        % Compile EDrillS
        EDrillS.EDrillHaz = EDrillHaz; EDrillS.EExpireHaz = EExpireHaz;
        EDrillS.EDrillHazM = EDrillHazM; EDrillS.EDrillProb = EDrillProb;
        EDrillS.EExpireProb = EExpireProb; EDrillS.EDrillProbM = EDrillProbM;
        EDrillS.EDrillHazB = EDrillHazB; EDrillS.EExpireHazB = EExpireHazB;
        EDrillS.EDrillHazMB = EDrillHazMB; EDrillS.EDrillProbB = EDrillProbB;
        EDrillS.EExpireProbB = EExpireProbB; EDrillS.EDrillProbMB = EDrillProbMB;
        EDrillS.EProd = EProd; EDrillS.EWater = EWater;
        EDrillS.EProdM = EProdM; EDrillS.EWaterM = EWaterM;
        EDrillS.EProdB = EProdB; EDrillS.EWaterB = EWaterB;
        EDrillS.EProdMB = EProdMB; EDrillS.EWaterMB = EWaterMB;
        EDrillS.EProdCond = EProdCond; EDrillS.EWaterCond = EWaterCond;
        EDrillS.EProdCondB = EProdCondB; EDrillS.EWaterCondB = EWaterCondB;
        EDrillS.EProdCondM = EProdCondM; EDrillS.EWaterCondM = EWaterCondM;
        EDrillS.EProdCondMB = EProdCondMB; EDrillS.EWaterCondMB = EWaterCondMB;
    end
    
    

    %% Output E[lessor value] at optimal primary term, given other inputs
    % Called by optroypriterm when searching for optimal royalty - pri term combo
    function [EVLout,Topt,EVL_T0] = LessorValOptPriTerm(obj,dirs,params,roy)
        % Outputs:
        % EVLout: expected lessor val at the optimal primary term
        % Topt: optimal pri term in years
        % EVL_TO: expected lessor val at inf primary term
        
        % Inputs:
        % roy: royalty
        
        % max pri term to search over (years)
        maxT = 30;
        % Update params inputs with royalty and maxT
        params.roy = roy; params.T = maxT;      % setting max pri term will set obj.TMAX in the model
        % Instantiate initial object
        obj = hbpmodelsim(dirs,params);
            
        % Compute static profits (not dependent on T)
        [PiDrill, PiDrillInf, RoyDrill, RoyDrillInf,...
                Q, QInf, W, WInf] = Payoffs(obj,obj.dataLshare);
        % Compute extension profits (not dependent on T)
        [DrillHazM,DrillHazx,ExpireHazx,EVx,EVm]...
                = MultWellAndExtension(obj,PiDrill,PiDrillInf,RoyDrill,RoyDrillInf);
            
        % Do coarse grid search for optimal pri term
        grid = linspace(0,maxT,16)';        % vector of pri terms to search over
        EVLgrid = zeros(length(grid),1);    % initialize output
        parfor i = 1:length(grid)
            % Set primary term
            T = grid(i);
            objt = obj;         % define new object to enable parfor loop
            objt.dataT = repmat(T,objt.N,1) * objt.perYear;
            objt.maxT = T * objt.perYear;
            % Run primary term simulation
            [DrillHaz,ExpireHaz,V0,V]...
                = RunPriTerm(objt,DrillHazM,DrillHazx,ExpireHazx,EVx,EVm,PiDrill,RoyDrill);
            % Compute expected values over types, including bonus
            [EV0,EVB0,V,Dropout,ShareFirms,Bonus] = SimEV0(objt,V0,V);
            % Obtain interpolation points and weights for the actual price and dayrate
            [pdState11,pdState12,pdState21,pdState22,alphap,alphad]...
                = InterpPoints(objt,objt.pddata0(objt.dataT0i(1),4),objt.pddata0(objt.dataT0i(1),5));
            % Interpolated lessor value, inclusive of bonus
            EVB0_Lessor = InterpState(objt,EVB0.Lessor(pdState11),...
                EVB0.Lessor(pdState12),...
                EVB0.Lessor(pdState21),...
                EVB0.Lessor(pdState22),...
                alphap,alphad);  
            % Store output
            EVLgrid(i) = EVB0_Lessor;                
        end
        
        % Value at inf pri term
        EVL_T0 = EVLgrid(1);
        
        % Check if optimum is zero or maxT. If so, stop. If not, do fine local search
        guess = grid(EVLgrid==max(EVLgrid));            % best pri term from coarse search
        if guess==0
            EVLout = max(EVLgrid); Topt = 0;
        elseif guess==maxT
            EVLout = max(EVLgrid); Topt = maxT;
        else 
            grid2 = linspace(guess-1.75,guess+1.75,15)';    % grid for fine search
            EVLgrid2 = zeros(length(grid2),1);    % initialize output
            parfor i = 1:length(grid2)
                % Set primary term
                T = grid2(i);
                objt = obj;         % define new object to enable parfor loop
                objt.dataT = repmat(T,objt.N,1) * objt.perYear;
                objt.maxT = T * objt.perYear;
                % Run primary term simulation
                [DrillHaz,ExpireHaz,V0,V]...
                    = RunPriTerm(objt,DrillHazM,DrillHazx,ExpireHazx,EVx,EVm,PiDrill,RoyDrill);
                % Compute expected values over types, including bonus
                [EV0,EVB0,V,Dropout,ShareFirms,Bonus] = SimEV0(objt,V0,V);
                % Obtain interpolation points and weights for the actual price and dayrate
                [pdState11,pdState12,pdState21,pdState22,alphap,alphad]...
                    = InterpPoints(objt,objt.pddata0(objt.dataT0i(1),4),objt.pddata0(objt.dataT0i(1),5));
                % Interpolated lessor value, inclusive of bonus
                EVB0_Lessor = InterpState(objt,EVB0.Lessor(pdState11),...
                    EVB0.Lessor(pdState12),...
                    EVB0.Lessor(pdState21),...
                    EVB0.Lessor(pdState22),...
                    alphap,alphad);  
                % Store output
                EVLgrid2(i) = EVB0_Lessor;                
            end
            opt = grid2(EVLgrid2==max(EVLgrid2));   
            EVLout = max(EVLgrid2); Topt = opt;
        end  
        [Topt EVLout];      % display answer
    end
    
    

    %% Output E[lessor value] at a given royalty and lessor cost
    % Called by optroypriterm when searching for optimal royalty - LC term combo
    function EVB0_Lessor = LessorVal_RoyLC(obj,dirs,params,x)
        % Outputs:
        % EVLout: expected lessor val
        
        % Inputs:
        % x: 1x2 vector of royalty and LC
        
        % Update params inputs with royalty and LC
        params.roy = x(1); params.LC = x(2);
        % Sense check on royalty
        if params.roy<0.01
            params.roy = 0.01;
        elseif params.roy>0.9
            params.roy = 0.9;
        end
        % Instantiate initial object
        obj = hbpmodelsim(dirs,params); 
        
        % Run primary term model
        [~,~,~,V0,V,~,~] = DrillHazSim(obj);
        % Take expectation over types
        [~,EVB0,~,~,~,~] = SimEV0(obj,V0,V);
        
        % Obtain interpolation points and weights for the actual price and dayrate
        [pdState11,pdState12,pdState21,pdState22,alphap,alphad]...
            = InterpPoints(obj,obj.pddata0(obj.dataT0i(1),4),obj.pddata0(obj.dataT0i(1),5));
        % Interpolated lessor value, inclusive of bonus
        EVB0_Lessor = InterpState(obj,EVB0.Lessor(pdState11),...
            EVB0.Lessor(pdState12),...
            EVB0.Lessor(pdState21),...
            EVB0.Lessor(pdState22),...
            alphap,alphad);           
    end
    
    
    
    %% Output simulation results, looping over lease paramter inputs
    function [EVLessorBMat,EVTotalBMat,EVTotalMat,ShareFirmsMat,EVBonusMat,...
            EDrillHazBMat,EDrillProbBMat,EProdBMat,EWaterBMat,...
            EDrillHazMat,EDrillProbMat,EProdMat,EWaterMat]...
            = SimLoop(obj,dirs,params,LEASETERMS,REPORTT)  
        % Outputs: (let NLT = size(LEASETERMS,1))
        % EVLessorBMat: nP*nD by NLT matrix of lessor val with bonus
        % EVTotalBMat: nP*nD by NLT matrix of total val with bonus
        % EVTotalMat: nP*nD by NLT matrix of total val ignoring bonus dropouts
        % ShareFirmsMat: nP*nD by NLT matrix of share of firms staying
        % EVBonusMat: nP*nD by NLT matrix of optimal bonus
        % EDrillHazBMat: nP*nD by reportT by NLT matrix of drilling hazards
        % EDrillProbBMat: nP*nD by reportT by NLT matrix of drilling probs
        % EProdBMat: nP*nD by NLT matrix of production cond on drlg
        % EWaterBMat: nP*nD by NLT matrix of water cond on drlg
        % Above 4 variables without "B" in name: ignoring bonus dropout
        
        % Inputs:
        % LEASETERMS: NLT by 4 matrix of lease terms: roy, LC, rent, T
        % REPORTT: reporting period in years
        
        % Initial setup
        NLT = size(LEASETERMS,1);       % number of input parameter sets to loop over
        params.T = REPORTT;             % maximum pri term (yrs). sets obj.TMAX and obj.reportT in model
        obj = hbpmodelsim(dirs,params); % instantiate model
        
        % Initialize output matrices
        EVLessorBMat = zeros(obj.nP*obj.nD,NLT);
        EVTotalBMat = zeros(obj.nP*obj.nD,NLT);
        EVTotalMat = zeros(obj.nP*obj.nD,NLT);
        ShareFirmsMat = zeros(obj.nP*obj.nD,NLT);
        EVBonusMat = zeros(obj.nP*obj.nD,NLT);
        EDrillHazBMat = zeros(obj.nP*obj.nD,obj.reportT-1,NLT);
        EDrillProbBMat = zeros(obj.nP*obj.nD,obj.reportT-1,NLT);
        EProdBMat = zeros(obj.nP*obj.nD,NLT);
        EWaterBMat = zeros(obj.nP*obj.nD,NLT);     
        
        % If roy, LC, and rent don't vary, find continuation value outside the loop
        varyflag = max(std(LEASETERMS(:,1:3)),[],2);    % = 0 if no variance
        if varyflag<1e-8
            % Define lease terms
            obj.dataR = repmat(LEASETERMS(1,1),obj.N,1);    % royalty
            obj.dataLC = repmat(LEASETERMS(1,2),obj.N,1);   % lessor cost
            obj.dataRent = repmat(LEASETERMS(1,3),obj.N,1); % rent
            % Compute static profits
            [PiDrill0, PiDrillInf0, RoyDrill0, RoyDrillInf0,...
                    Q0, QInf0, W0, WInf0] = Payoffs(obj,obj.dataLshare);
            % Extend Q and W matrices to reportT using QInf and WInf
            td = obj.reportT - obj.TMAX;        % number of periods to add
            Q0 = cat(3, Q0, repmat(QInf0,1,1,td));
            W0 = cat(3, W0, repmat(WInf0,1,1,td));
            % Compute extension and continuation profits
            [DrillHazM0,DrillHazx0,ExpireHazx0,EVx0,EVm0]...
                    = MultWellAndExtension(obj,PiDrill0,PiDrillInf0,RoyDrill0,RoyDrillInf0);            
        else        % set up dummies so loop below runs ok
            PiDrill0 = 0; PiDrillInf0 = 0;
            RoyDrill0 = 0; RoyDrillInf0 = 0;
            Q0 = 0; QInf0 = 0; W0 = 0; WInf0 = 0;
            DrillHazM0 = 0; DrillHazx0 = 0;
            ExpireHazx0 = 0; EVx0 = 0; EVm0 = 0;            
        end
        
        % Loop over lease terms
        parfor i = 1:NLT
            obji = obj;         % define new object to enable parfor loop
            % Define lease terms
            obji.dataR = repmat(LEASETERMS(i,1),obji.N,1);                  % royalty
            obji.dataLC = repmat(LEASETERMS(i,2),obji.N,1);                 % lessor cost
            obji.dataRent = repmat(LEASETERMS(i,3),obji.N,1);               % rent
            obji.dataT = repmat(LEASETERMS(i,4),obji.N,1) * obji.perYear;   % pri term
            obji.maxT = LEASETERMS(i,4) * obji.perYear;    
            % Get extension and continuation profits if not done above
            if varyflag>=1e-8
                % Compute static profits
                [PiDrill, PiDrillInf, RoyDrill, RoyDrillInf,...
                        Q, QInf, W, WInf] = Payoffs(obji,obji.dataLshare);
                % Extend Q and W matrices to reportT using QInf and WInf
                td = obji.reportT - obji.TMAX;        % number of periods to add
                Q = cat(3, Q, repmat(QInf,1,1,td));
                W = cat(3, W, repmat(WInf,1,1,td));
                % Compute extension and continuation profits
                [DrillHazM,DrillHazx,ExpireHazx,EVx,EVm]...
                        = MultWellAndExtension(obji,PiDrill,PiDrillInf,RoyDrill,RoyDrillInf);                 
            else        % Use values defined before loop
                PiDrill = PiDrill0; PiDrillInf = PiDrillInf0;
                RoyDrill = RoyDrill0; RoyDrillInf = RoyDrillInf0;
                Q = Q0; QInf = QInf0; W = W0; WInf = WInf0;
                DrillHazM = DrillHazM0; DrillHazx = DrillHazx0;
                ExpireHazx = ExpireHazx0; EVx = EVx0; EVm = EVm0;
            end
            % Run primary term simulation
            [DrillHaz,ExpireHaz,V0,V]...
                = RunPriTerm(obji,DrillHazM,DrillHazx,ExpireHazx,EVx,EVm,PiDrill,RoyDrill);
            % Compute expected values over types, including bonus
            [EV0,EVB0,~,Dropout,ShareFirms,Bonus] = SimEV0(obji,V0,V);    
            % Drilling probabilities conditional on state at lease signing
            [DrillProb,ExpireProb,DrillProbM,Prod,Water,ProdM,WaterM,~,...
                        ~,~,~] = HazToProb(obji,DrillHaz,ExpireHaz,DrillHazM,Q,W);
            % Take expectations over firm types        
            EDrillS = LessorExpectDrill(obji,DrillProb,ExpireProb,DrillProbM,...
                        Dropout,ShareFirms,Prod,Water,ProdM,WaterM); 
            % Store output            
            EVLessorBMat(:,i) = EVB0.Lessor;               % lessor val with bonus
            EVTotalBMat(:,i) = EVB0.Firm + EVB0.Lessor;    % total val with bonus
            EVTotalMat(:,i) = EV0.Firm + EV0.Lessor;       % total val ignoring bonus dropouts
            ShareFirmsMat(:,i) = ShareFirms;               % share of firms staying
            EVBonusMat(:,i) = Bonus;                       % bonus
            EDrillHazBMat(:,:,i) = EDrillS.EDrillHazB(:,1:obji.reportT-1);      % drilling hazard
            EDrillProbBMat(:,:,i) = EDrillS.EDrillProbB(:,1:obji.reportT-1);    % drilling prob
            EProdBMat(:,i) = sum(EDrillS.EProdB(:,1:obji.reportT-1),2)...
                ./ sum(EDrillS.EDrillProbB(:,1:obji.reportT-1),2);    % production cond on drlg
            EWaterBMat(:,i) = sum(EDrillS.EWaterB(:,1:obji.reportT-1),2)...
                ./ sum(EDrillS.EDrillProbB(:,1:obji.reportT-1),2);    % water cond on drlg
            EDrillHazMat(:,:,i) = EDrillS.EDrillHaz(:,1:obji.reportT-1);        % drilling hazard, ignoring bonus
            EDrillProbMat(:,:,i) = EDrillS.EDrillProb(:,1:obji.reportT-1);      % drilling prob, ignoring bonus
            EProdMat(:,i) = sum(EDrillS.EProd(:,1:obji.reportT-1),2)...
                ./ sum(EDrillS.EDrillProb(:,1:obji.reportT-1),2);       % production cond on drlg, ignoring bonus
            EWaterMat(:,i) = sum(EDrillS.EWater(:,1:obji.reportT-1),2)...
                ./ sum(EDrillS.EDrillProb(:,1:obji.reportT-1),2);       % water cond on drlg, ignoring bonus
        end
    end
    
    
    
    %% Set up plot-friendly matrices of main simulation results
    function [plotEVSocialOpt,plotEVLessor,plotEVTotal,plotEVBonus,plotShareFirms,...
            plotEDrillHazSocialOpt,plotEDrillProbSocialOpt,...
            plotEDrillHazB,plotEDrillProbB,plotEProdSocialOpt,plotEWaterSocialOpt,...
            plotEProdB,plotEWaterB,P0,P0H,P0L,DR0]...
            = PlotMatrices(obj,EVLessorBMat,EVTotalBMat,ShareFirmsMat,EVBonusMat,...
            EDrillHazBMat,EDrillProbBMat,EProdBMat,EWaterBMat,...
            SO_EVTotal,SO_EDrillHaz,SO_EDrillProb,SO_EProd,SO_EWater)  
        % Outputs: plot* matrices. Last dimension has three elements,
        % corresponding to the low, middle, and high initial price states
        % Note NLT = size(LEASETERMS,1)
        % plotEVSocialOpt: 1 by 3 socially optimal total values
        % plotEVLessor,plotEVTotal: NLT by 3 value to lessor and total
        % plotEVBonus: NLT by 3 optimal bonus
        % plotShareFirms: NLT by 3 share of firms signing lease
        % plotEDrillHazSocialOpt,plotEDrillProbSocialOpt: reportT by 3
        % socially opt drlg hazard and bonus
        % plotEDrillHazB,plotEDrillProbB: reportT by NLT by 3 drlg hazard and bonus
        % plotEProdSocialOpt,plotEWaterSocialOpt: 1 by 3 socially opt prod and water | drlg
        % plotEProdB,plotEWaterB: NLT by 3 prod and water | drlg
        % P0,P0H,P0L: middle, high, and low gas prices
        % DR0: dayrate
        
        % Inputs:
        % EVLessorBMat: nP*nD by NLT matrix of lessor val with bonus
        % EVTotalBMat: nP*nD by NLT matrix of total val with bonus
        % ShareFirmsMat: nP*nD by NLT matrix of share of firms staying
        % EVBonusMat: nP*nD by NLT matrix of optimal bonus
        % EDrillHazBMat: nP*nD by reportT by NLT matrix of drilling hazards
        % EDrillProbBMat: nP*nD by reportT by NLT matrix of drilling probs
        % EProdBMat: nP*nD by NLT matrix of production cond on drlg
        % EWaterBMat: nP*nD by NLT matrix of water cond on drlg
        % SO_EVTotal: nP*nD vector of total value at social opt
        % SO_EDrillHaz: nP*nD by reportT matrix of socially opt drilling hazards
        % SO_EDrillProb: nP*nD by reportT matrix of socially opt drilling probs
        % SO_EProd: nP*nD vector of socially opt production | drlg
        % SO_EWater: nP*nD vector of socially opt water | drlg
        
        % Find price and dayrate at lease start, 50% higher and 50% lower price
        % Start with actual price and dayrate in start quarter
        P0 = obj.pddata0(obj.dataT0i(1),4); DR0 = obj.pddata0(obj.dataT0i(1),5);  
        P0H = P0 * 4/3; P0L = P0 * 2/3;     % prices 50% higher and lower
        % Obtain interpolation points and weights for all three prices and dayrates
        [pdState11,pdState12,pdState21,pdState22,alphap,alphad] = InterpPoints(obj,P0,DR0);
        [pdState11H,pdState12H,pdState21H,pdState22H,alphapH,alphadH] = InterpPoints(obj,P0H,DR0);
        [pdState11L,pdState12L,pdState21L,pdState22L,alphapL,alphadL] = InterpPoints(obj,P0L,DR0);  
        
        % Set up plot vectors for y axis
        % Extract from model runs the values and drilling probabilities, starting
        % with expectations at lease signing.
        % Get expectations both at the true initial price at signing (P0) and at
        % prices higher (P0h) and lower (P0l). Dayrate is DR0.

        % Expected socially optimal value. Low, medium, high prices.
        values = SO_EVTotal;
        ValLow = InterpState(obj,values(pdState11L),values(pdState12L),...
            values(pdState21L),values(pdState22L),alphapL,alphadL);
        ValMed = InterpState(obj,values(pdState11),values(pdState12),...
            values(pdState21),values(pdState22),alphap,alphad);
        ValHigh = InterpState(obj,values(pdState11H),values(pdState12H),...
            values(pdState21H),values(pdState22H),alphapH,alphadH);
        plotEVSocialOpt = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected lessor values over lease terms. Low, medium, high prices.
        values = EVLessorBMat;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotEVLessor = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected total values over lease terms. Low, medium, high prices.
        values = EVTotalBMat;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotEVTotal = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected bonus over lease terms. Low, medium, high prices.
        values = EVBonusMat;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotEVBonus = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Share of firms that participate over terms in LEASE (changes explain
        % occasional jumps in plots). Low, medium, high prices.
        values = ShareFirmsMat;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotShareFirms = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected drilling probs at social optimum. Low, medium, high prices.
        values = SO_EDrillProb;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotEDrillProbSocialOpt = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected drilling hazards at social optimum. Low, medium, high prices.
        values = SO_EDrillHaz;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotEDrillHazSocialOpt = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected drilling probs (accounting for firm dropout) over lease terms
        % Low, medium, high prices.
        values = EDrillProbBMat;
        ValLow = squeeze(InterpState(obj,values(pdState11L,:,:),values(pdState12L,:,:),...
            values(pdState21L,:,:),values(pdState22L,:,:),alphapL,alphadL))';
        ValMed = squeeze(InterpState(obj,values(pdState11,:,:),values(pdState12,:,:),...
            values(pdState21,:,:),values(pdState22,:,:),alphap,alphad))';
        ValHigh = squeeze(InterpState(obj,values(pdState11H,:,:),values(pdState12H,:,:),...
            values(pdState21H,:,:),values(pdState22H,:,:),alphapH,alphadH))';
        plotEDrillProbB = cat(3,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected drilling hazards (accounting for firm dropout) over lease terms
        % Low, medium, high prices.
        values = EDrillHazBMat;
        ValLow = squeeze(InterpState(obj,values(pdState11L,:,:),values(pdState12L,:,:),...
            values(pdState21L,:,:),values(pdState22L,:,:),alphapL,alphadL))';
        ValMed = squeeze(InterpState(obj,values(pdState11,:,:),values(pdState12,:,:),...
            values(pdState21,:,:),values(pdState22,:,:),alphap,alphad))';
        ValHigh = squeeze(InterpState(obj,values(pdState11H,:,:),values(pdState12H,:,:),...
            values(pdState21H,:,:),values(pdState22H,:,:),alphapH,alphadH))';
        plotEDrillHazB = cat(3,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected production at social optimum, cond on drlg. Low, medium, high prices.
        values = SO_EProd;    % production cond on drlg
        ValLow = InterpState(obj,values(pdState11L),values(pdState12L),...
            values(pdState21L),values(pdState22L),alphapL,alphadL);
        ValMed = InterpState(obj,values(pdState11),values(pdState12),...
            values(pdState21),values(pdState22),alphap,alphad);
        ValHigh = InterpState(obj,values(pdState11H),values(pdState12H),...
            values(pdState21H),values(pdState22H),alphapH,alphadH);
        plotEProdSocialOpt = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected water use at social optimum, cond on drlg. Low, medium, high prices.
        values = SO_EWater;    % water cond on drlg
        ValLow = InterpState(obj,values(pdState11L),values(pdState12L),...
            values(pdState21L),values(pdState22L),alphapL,alphadL);
        ValMed = InterpState(obj,values(pdState11),values(pdState12),...
            values(pdState21),values(pdState22),alphap,alphad);
        ValHigh = InterpState(obj,values(pdState11H),values(pdState12H),...
            values(pdState21H),values(pdState22H),alphapH,alphadH);
        plotEWaterSocialOpt = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected production over lease terms. Low, medium, high prices.
        values = EProdBMat;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotEProdB = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values 

        % Expected water use over lease terms. Low, medium, high prices.
        values = EWaterBMat;
        ValLow = InterpState(obj,values(pdState11L,:),values(pdState12L,:),...
            values(pdState21L,:),values(pdState22L,:),alphapL,alphadL)';
        ValMed = InterpState(obj,values(pdState11,:),values(pdState12,:),...
            values(pdState21,:),values(pdState22,:),alphap,alphad)';
        ValHigh = InterpState(obj,values(pdState11H,:),values(pdState12H,:),...
            values(pdState21H,:),values(pdState22H,:),alphapH,alphadH)';
        plotEWaterB = cat(2,ValLow,ValMed,ValHigh);
        clear ValLow ValMed ValHigh values         
    end
end
end






























