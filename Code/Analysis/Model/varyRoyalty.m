% varyPriTerm.m
% Ryan Kellogg
% Created: 15 November, 2019


%{
This is the top-level for producing results that vary the royalty,
holding the pri term fixed at the optimal royalty + pri term combo

High-level order of operations is:
1. Define key parameters to input into the model
2. Instantiate the simulation subclass of the model
3. Simulate outcomes under a socially optimal lease
4. Vary the royalty and for each royalty,
simulate outcomes
5. Save all results and generate figures
%}


clear all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Call simsetup.m to define directories and input parameters, instantiate
% the model, and simulate outcomes under a socially optimal lease
simsetup



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set up grid of royalties to simulate over and call SimLoop method to run sims
Rvec = linspace(0.1,0.9,17)';       % royalties
NLT = length(Rvec);
LEASETERMS = [Rvec zeros(NLT,1) zeros(NLT,1) repmat(optT,NLT,1)];

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

% Create x variable (here, royalty)
X = Rvec * 100;

% Rename plot vectors (helps standardize plotting code)
Xp = X; Yp = plotLessorShare;

% Create legend labels for different gas prices
formatSpec = '$%2.2f/mmBtu';
str1 = sprintf(formatSpec,P0L);
str2 = sprintf(formatSpec,P0);
str3 = sprintf(formatSpec,P0H);
% x axis ticks
xaxisticks = 10:10:max(Xp);

% Plot
clf
plot(Xp,Yp(:,1),'-k','LineWidth',2,'DisplayName',str1);
hold on
plot(Xp,Yp(:,2),'-.r','LineWidth',2,'DisplayName',str2);
plot(Xp,Yp(:,3),'--b','LineWidth',2,'DisplayName',str3);
axis([10 max(Xp) 30 100]);
xlabel('Royalty rate (%)'); xticks(xaxisticks);
ylabel('Value to owner (as % of socially optimal surplus)');
set(gca, 'YGrid', 'on', 'XGrid', 'off')
legend('Location','northwest')
lgd = legend;
lgd.FontSize = 24; lgd.Title.String = 'Initial gas price';
set(gca,'fontsize',24)
set(gca, 'FontName', 'Times New Roman')
h = gcf;
set(h,'PaperOrientation','landscape');
set(h,'PaperUnits','normalized');
set(h,'PaperPosition', [0 0 1 1]);
% Save plot
saveas(h,[dirs.figfinaldir,'EVlessorprofit_vs_royalty.pdf'])

% Beamer version
set(gca, 'FontName', 'Helvetica')
legend('Location','best')
saveas(h,[dirs.figbeamerdir,'EVlessorprofit_vs_royalty.pdf'])



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot expected total value as share of social opt value

% Calc value share (in %) for each case
plotTotalShare = plotEVTotal ./ plotEVSocialOpt * 100;

% Create x variable (here, royalty)
X = Rvec * 100;


% Rename plot vectors (helps standardize plotting code)
Xp = X; Yp = plotTotalShare;

% Create legend labels for different gas prices
formatSpec = '$%2.2f/mmBtu';
str1 = sprintf(formatSpec,P0L);
str2 = sprintf(formatSpec,P0);
str3 = sprintf(formatSpec,P0H);
% x axis ticks
xaxisticks = 10:10:max(Xp);

% Plot
clf
plot(Xp,Yp(:,1),'-k','LineWidth',2,'DisplayName',str1);
hold on
plot(Xp,Yp(:,2),'-.r','LineWidth',2,'DisplayName',str2);
plot(Xp,Yp(:,3),'--b','LineWidth',2,'DisplayName',str3);
axis([10 max(Xp) 30 100]);
xlabel('Royalty rate (%)'); xticks(xaxisticks);
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
saveas(h,[dirs.figfinaldir,'EVtotal_vs_royalty.pdf'])

% Beamer version
set(gca, 'FontName', 'Helvetica')
saveas(h,[dirs.figbeamerdir,'EVtotal_vs_royalty.pdf'])

clf



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Output csv of key results
% Table row headers
strvarnames = strcat('Initial P,','InitialDR,','Optimal royalty,','Total value social opt,',...
    'Total value opt royalty,',...
    'Lessor value opt royalty,','Bonus optimal royalty,',...
    'Prod Social Opt,','Prod opt royalty,',...
    'Water Social Opt,','Water opt royalty \n');
% Get best royalty for each initial price
maxval = max(plotEVLessor);
ind = zeros(1,3);           % initialize
optrr = zeros(1,3);         % initialize
for i = 1:3
    ind(i) = find(plotEVLessor(:,i)==maxval(i));
    optrr(i) = Rvec(ind(i));
end
% Matrix to write. Low, medium, high price.
csvout = [[P0L P0 P0H]; repmat(DR0,1,3); optrr; plotEVSocialOpt;...
    [plotEVTotal(ind(1),1) plotEVTotal(ind(2),2) plotEVTotal(ind(3),3)];...
    [plotEVLessor(ind(1),1) plotEVLessor(ind(2),2) plotEVLessor(ind(3),3)];...
    [plotEVBonus(ind(1),1) plotEVBonus(ind(2),2) plotEVBonus(ind(3),3)];...
    plotEProdSocialOpt;...
    [plotEProdB(ind(1),1) plotEProdB(ind(2),2) plotEProdB(ind(3),3)];...
    plotEWaterSocialOpt;...
    [plotEWaterB(ind(1),1) plotEWaterB(ind(2),2) plotEWaterB(ind(3),3)]];
filenameo = strcat(dirs.figfinaldir,'varRoyalty.csv');
fileid = fopen(char(filenameo),'w');
fprintf(fileid,strvarnames);
fprintf(fileid,'%2.2f, %5.0f, %2.2f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f, %2.4f \n', csvout);
fclose('all');
        
        

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Save workspace
outfile = [dirs.outputdir,'varyRoy_SimResults'];   
save(outfile);      
        
        
        
        
