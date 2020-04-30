% varyPriTerm_multwells.m
% Ryan Kellogg
% Created: 15 November, 2019


%{
This is the top-level for producing results that vary the primary term,
holding the royalty fixed at the optimal royalty + pri term combo
With multiple wells per unit

High-level order of operations is:
1. Define key parameters to input into the model
2. Instantiate the simulation subclass of the model
3. Simulate outcomes under a socially optimal lease
4. Vary the primary term and for each lease term,
simulate outcomes
5. Save all results and generate figures
%}


clear all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Call simsetup.m to define directories and input parameters, instantiate
% the model, and simulate outcomes under a socially optimal lease
simsetup
       


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set number of wells per unit and re-run social optimum
wellsperunitfile = [dirs.db,'IntermediateData/CalibrationCoefs/Wellsperunit.csv'];
params.Wells = csvread(wellsperunitfile,0);     % wells per unit
clear wellsperunitfile
SO_LEASETERMS = [0 0 0 0];
[~,~,SO_EVTotal,~,~,...
    ~,~,~,~,...
    SO_EDrillHaz,SO_EDrillProb,SO_EProd,SO_EWater]...
    = SimLoop(obj,dirs,params,SO_LEASETERMS,REPORTT);     



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set up grid of primary terms to simulate over and call SimLoop method to run sims
Tvec = [linspace(0.25,10,40)'; linspace(10.5,15,10)'; 0];  % pri terms in years
NLT = length(Tvec);
LEASETERMS = [repmat(optr,NLT,1) zeros(NLT,1) zeros(NLT,1) Tvec];

% Run simulations
[EVLessorBMat,EVTotalBMat,~,ShareFirmsMat,EVBonusMat,...
    EDrillHazBMat,EDrillProbBMat,EProdBMat,EWaterBMat,...
    ~,~,~,~]...
    = SimLoop(obj,dirs,params,LEASETERMS,REPORTT);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Create plot-friendly matrices of main results
[plotEVSocialOpt,plotEVLessor,plotEVTotal,plotEVBonus,plotShareFirms,...
            plotEDrillHazSocialOpt,plotEDrillProbSocialOpt,...
            plotEDrillHazB,plotEDrillProbB,plotEProdSocialOpt,plotEWaterSocialOpt,...
            plotEProdB,plotEWaterB,P0,P0H,P0L,DR0]...
            = PlotMatrices(obj,EVLessorBMat,EVTotalBMat,ShareFirmsMat,EVBonusMat,...
            EDrillHazBMat,EDrillProbBMat,EProdBMat,EWaterBMat,...
            SO_EVTotal,SO_EDrillHaz,SO_EDrillProb,SO_EProd,SO_EWater); 
     


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot expected lessor value as share of social opt value
% Calc value share (in %) for each case
plotLessorShare = plotEVLessor ./ plotEVSocialOpt * 100;

% Create x variable (here, lease primary term in years)
X = Tvec;

% Drop last case (infinite horizon lease)
plotLessorShare = plotLessorShare(1:NLT-1,:);
X = X(1:NLT-1);

% Rename plot vectors (helps standardize plotting code)
Xp = X; Yp = plotLessorShare;

% Create legend labels for different gas prices
formatSpec = '$%2.2f/mmBtu';
str1 = sprintf(formatSpec,P0L);
str2 = sprintf(formatSpec,P0);
str3 = sprintf(formatSpec,P0H);
% x axis ticks
xaxisticks = 0:3:max(Xp);

% Plot
clf
plot(Xp,Yp(:,1),'-k','LineWidth',2,'DisplayName',str1);
hold on
plot(Xp,Yp(:,2),'-.r','LineWidth',2,'DisplayName',str2);
plot(Xp,Yp(:,3),'--b','LineWidth',2,'DisplayName',str3);
axis([0 max(Xp) 64 76]);
xlabel('Primary term (years)'); xticks(xaxisticks);
ylabel('Value to owner (as % of socially optimal surplus)');
set(gca, 'YGrid', 'on', 'XGrid', 'off')
legend('Location','best')
lgd = legend;
lgd.FontSize = 24; lgd.Title.String = 'Initial gas price';
set(gca,'fontsize',24)
set(gca, 'FontName', 'Times New Roman')
h = gcf;
set(h,'PaperOrientation','landscape');
set(h,'PaperUnits','normalized');
set(h,'PaperPosition', [0 0 1 1]);
% Save plot
saveas(h,[dirs.figfinaldir,'EVlessorprofit_vs_priterm_multwells.pdf'])

% Beamer version
set(gca, 'FontName', 'Helvetica')
legend('Location','best')
saveas(h,[dirs.figbeamerdir,'EVlessorprofit_vs_priterm_multwells.pdf'])
     


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot expected total value as share of social opt value
% Calc value share (in %) for each case
plotTotalShare = plotEVTotal ./ plotEVSocialOpt * 100;

% Create x variable (here, lease primary term in years)
X = Tvec;

% Drop last case (infinite horizon lease)
plotTotalShare = plotTotalShare(1:NLT-1,:);
X = X(1:NLT-1);

% Rename plot vectors (helps standardize plotting code)
Xp = X; Yp = plotTotalShare;

% Create legend labels for different gas prices
formatSpec = '$%2.2f/mmBtu';
str1 = sprintf(formatSpec,P0L);
str2 = sprintf(formatSpec,P0);
str3 = sprintf(formatSpec,P0H);
% x axis ticks
xaxisticks = 0:3:max(Xp);

% Plot
clf
plot(Xp,Yp(:,1),'-k','LineWidth',2,'DisplayName',str1);
hold on
plot(Xp,Yp(:,2),'-.r','LineWidth',2,'DisplayName',str2);
plot(Xp,Yp(:,3),'--b','LineWidth',2,'DisplayName',str3);
axis([0 max(Xp) 80 90]);
xlabel('Primary term (years)'); xticks(xaxisticks);
ylabel('Firm + owner value (as % of social optimum)');
set(gca, 'YGrid', 'on', 'XGrid', 'off')
legend('Location','best')
lgd = legend;
lgd.FontSize = 24; lgd.Title.String = 'Initial gas price';
set(gca,'fontsize',24)
set(gca, 'FontName', 'Times New Roman')
h = gcf;
set(h,'PaperOrientation','landscape');
set(h,'PaperUnits','normalized');
set(h,'PaperPosition', [0 0 1 1]);
% Save plot
saveas(h,[dirs.figfinaldir,'EVtotal_vs_priterm_multwells.pdf'])

% Beamer version
set(gca, 'FontName', 'Helvetica')
legend('Location','best')
saveas(h,[dirs.figbeamerdir,'EVtotal_vs_priterm_multwells.pdf'])


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot expected drilling probabilities for medium price case
% Obtain vectors for social optimum, royalty with no pri term, optimal pri term
DrillPlot1 = plotEDrillProbSocialOpt(:,2);                      % drlg at social opt
DrillPlot2 = squeeze(plotEDrillProbB(NLT,:,2))';                 % drlg with no pri term
bestterm = find(Tvec==optT);
DrillPlot3 = squeeze(plotEDrillProbB(bestterm,:,2))';           % drlg with best pri term
Ypd = [DrillPlot1 DrillPlot2 DrillPlot3];

% set up x axis
maxxpd = length(DrillPlot1) / obj.perYear;       % # of years of drilling probs
Xpd = [1/obj.perYear:1/obj.perYear:maxxpd]';
xaxisticks = 0:3:max(Xpd);
clear DrillPlot1 DrillPlot2 DrillPlot3

% Create legend labels
strd1 = sprintf('Social optimum');
strd2 = sprintf('%2.0f%% royalty, no primary term', optr*100);
strd3 = sprintf('%2.0f%% royalty, %2.2f year primary term', optr*100, optT);

% Plot
clf
plot(Xpd,Ypd(:,1),'-k','LineWidth',2,'DisplayName',strd1);
hold on
plot(Xpd,Ypd(:,2),'-.r','LineWidth',2,'DisplayName',strd2);
plot(Xpd,Ypd(:,3),'--b','LineWidth',2,'DisplayName',strd3);
xlabel('Years since lease signed'); xticks(xaxisticks);
ylabel('Expected drilling probability (quarterly)');
set(gca, 'YGrid', 'on', 'XGrid', 'off')
legend('Location','northeast')
lgd = legend;
lgd.FontSize = 24;
set(gca,'fontsize',24)
set(gca, 'FontName', 'Times New Roman')
h = gcf;
set(h,'PaperOrientation','landscape');
set(h,'PaperUnits','normalized');
set(h,'PaperPosition', [0 0 1 1]);
saveas(h,[dirs.figfinaldir,'Edrillingprobs_priterm_multwells.pdf'])

% Beamer version
set(gca, 'FontName', 'Helvetica')
saveas(h,[dirs.figbeamerdir,'Edrillingprobs_priterm_multwells.pdf'])



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot expected drilling hazards for medium price case
% Obtain vectors for social optimum, royalty with no pri term, optimal pri term
DrillPlot1 = plotEDrillHazSocialOpt(:,2);                      % drlg at social opt
DrillPlot2 = squeeze(plotEDrillHazB(NLT,:,2))';                 % drlg with no pri term
bestterm = find(Tvec==optT);
DrillPlot3 = squeeze(plotEDrillHazB(bestterm,:,2))';           % drlg with best pri term
Ypd = [DrillPlot1 DrillPlot2 DrillPlot3];

% set up x axis
maxxpd = length(DrillPlot1) / obj.perYear;       % # of years of drilling probs
Xpd = [1/obj.perYear:1/obj.perYear:maxxpd]';
xaxisticks = 0:3:max(Xpd);
clear DrillPlot1 DrillPlot2 DrillPlot3

% Create legend labels
strd1 = sprintf('Social optimum');
strd2 = sprintf('%2.0f%% royalty, no primary term', optr*100);
strd3 = sprintf('%2.0f%% royalty, %2.2f year primary term', optr*100, optT);

% Plot
clf
plot(Xpd,Ypd(:,1),'-k','LineWidth',2,'DisplayName',strd1);
hold on
plot(Xpd,Ypd(:,2),'-.r','LineWidth',2,'DisplayName',strd2);
plot(Xpd,Ypd(:,3),'--b','LineWidth',2,'DisplayName',strd3);
xlabel('Years since lease signed'); xticks(xaxisticks);
ylabel('Expected drilling hazard (quarterly)');
set(gca, 'YGrid', 'on', 'XGrid', 'off')
legend('Location','northeast')
lgd = legend;
lgd.FontSize = 24;
set(gca,'fontsize',24)
set(gca, 'FontName', 'Times New Roman')
h = gcf;
set(h,'PaperOrientation','landscape');
set(h,'PaperUnits','normalized');
set(h,'PaperPosition', [0 0 1 1]);
saveas(h,[dirs.figfinaldir,'Edrillinghaz_priterm_multwells.pdf'])

% Beamer version
set(gca, 'FontName', 'Helvetica')
saveas(h,[dirs.figbeamerdir,'Edrillinghaz_priterm_multwells.pdf'])

clf

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Output csv of key results
% Table row headers
strvarnames = strcat('Initial P,','InitialDR,','Optimal primary term,','Total value social opt,',...
    'Total value royalty only,','Total value opt pri term,','Lessor value royalty only,',...
    'Lessor value opt pri term,','Bonus royalty only,','Bonus optimal primary term,',...
    'Prod Social Opt,','Prod royalty only,','Prod opt pri term,',...
    'Water Social Opt,','Water royalty only,','Water opt pri term \n');
    
% Get best primary term for each initial price
maxval = max(plotEVLessor);
ind = zeros(1,3);           % initialize
optpt = zeros(1,3);         % initialize
for i = 1:3
    ind(i) = find(plotEVLessor(:,i)==maxval(i));
    optpt(i) = Tvec(ind(i));
end
% Matrix to write. Low, medium, high price.
csvout = [[P0L P0 P0H]; repmat(DR0,1,3); optpt; plotEVSocialOpt; plotEVTotal(NLT,:);...
    [plotEVTotal(ind(1),1) plotEVTotal(ind(2),2) plotEVTotal(ind(3),3)];...
    plotEVLessor(NLT,:); [plotEVLessor(ind(1),1) plotEVLessor(ind(2),2) plotEVLessor(ind(3),3)];...
    plotEVBonus(NLT,:); [plotEVBonus(ind(1),1) plotEVBonus(ind(2),2) plotEVBonus(ind(3),3)];...
    plotEProdSocialOpt; plotEProdB(NLT,:);...
    [plotEProdB(ind(1),1) plotEProdB(ind(2),2) plotEProdB(ind(3),3)];...
    plotEWaterSocialOpt; plotEWaterB(NLT,:);...
    [plotEWaterB(ind(1),1) plotEWaterB(ind(2),2) plotEWaterB(ind(3),3)]];
filenameo = strcat(dirs.figfinaldir,'varPriTerm_multwells.csv');
fileid = fopen(char(filenameo),'w');
fprintf(fileid,strvarnames);
fprintf(fileid,'%2.2f, %5.0f, %2.2f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f \n', csvout);
fclose('all');
        
        

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Save workspace
outfile = [dirs.outputdir,'varyPriTerm_multwells_SimResults'];   
save(outfile);
        
        
        
        
        
        
