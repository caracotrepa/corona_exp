% local_init; % comment out for public repo
clc; clear; close all;
%% Figure environment setup
set(0,'DefaultFigureWindowStyle','docked');
set(0,'defaultfigurecolor',[1 1 1]);
set(0,'defaulttextinterpreter','latex');  
set(0, 'defaultAxesTickLabelInterpreter','latex');  
set(0, 'defaultLegendInterpreter','latex');
set(0, 'defaultColorbarTickLabelInterpreter','latex');
set(0, 'DefaultAxesFontWeight', 'normal','DefaultAxesFontSize', 14);
visFlag = true;
%% Load daily data 
% Data taken from https://ourworldindata.org/coronavirus
o = weboptions('CertificateFilename','');                                   % remove certificate - to stop linux from barking
fileCases = websave('newcases.csv','https://covid.ourworldindata.org/data/ecdc/new_cases.csv',o);
fileDeaths = websave('newdeaths.csv','https://covid.ourworldindata.org/data/ecdc/new_deaths.csv',o); 
prompt = 'Country name (without spaces, case sensitive): ';
countryName = input(prompt,'s');
tableCases = readtable('newcases.csv');
tableDeaths = readtable('newdeaths.csv');
Countries = tableCases.Properties.VariableNames;
[tf, iColumn] = ismember(countryName, Countries);                           % get country column
 if ~tf
     error('Country not in the list.')
 end
 formatOut = 'dd/mm/yy';
 cases  = table2array(tableCases(:,iColumn));
 deaths = table2array(tableDeaths(:,iColumn));
 times  = find(~isnan(cases));
 cases_real     = cases(times,1);
 deaths_real    = deaths(times,1);
 deaths_real(isnan(deaths_real)) = 0;
 %% Dates for labelling
 lastdate   = datestr(tableCases{times(end),1});
 weekly     = find( mod((times - times(1)),7)==0);
 if weekly(end) ~= length(times)                                            % add latest date
     weekly = [weekly; length(times)];
 end
 weeks  = datestr(tableCases{times(weekly),1},formatOut);
 str    = convertCharsToStrings(weeks'); clear weeks
 weeks  =  cellstr(reshape(str{1},8,[])');
 foName = [countryName,'/',lastdate];
 if ~exist(foName, 'dir')
     mkdir(foName)
 end
%% Preliminaries
x_train = cases(times,1);
t_train = [1:length(x_train)]'-1;
y_train = cumsum(x_train);
total_deaths = cumsum(deaths_real);

figure('Name',countryName,'NumberTitle','off','visible',visFlag);
subplot(3,1,1);
plot(x_train,'Linewidth',2);
xticks(t_train(weekly)); xticklabels(weeks); xtickangle(45);
% xlabel('days from patient zero'); 
ylabel('new cases');
subplot(3,1,2);
plot(y_train,'Linewidth',2);
xticks(t_train(weekly)); xticklabels(weeks); xtickangle(45);
ylabel('total cases');
subplot(3,1,3);
plot(total_deaths,'Linewidth',2);
xticks(t_train(weekly)); xticklabels(weeks); xtickangle(45);
% xlabel('days from patient zero'); 
ylabel('total deaths');
tikzName = [foName,'/training_data.tikz'];
figName = [foName,'/training_data'];
try
    cleanfigure;
    matlab2tikz(tikzName, 'showInfo', false,'parseStrings',false,'standalone', ...
            false, 'height', '10cm', 'width','10cm','checkForUpdates',false);
catch
    warning('Tikz libraries are missing. Saving as an imagee.');
    print(figName,'-dpng')
end
%% Fit the curve to data
prompt = 'Exponential or logistic curve? ';
curveType = input(prompt,'s');
switch curveType
    case 'exponential'
        f       = fit(t_train,y_train,'exp1')
        func = @(x) f.a*exp(f.b*x);
    case 'logistic'
%         f = fit(t_train,y_train,'a./(1+b*exp(b+c*x))','start',[10000 -1 1]) %
%         func = @(x) f.a./(1+exp(f.b+f.c*x));
        funcfit = @(h,x) h(1)./(1+exp(h(2)+h(3)*x));
        h = lsqcurvefit(funcfit,[y_train(end) 0 0],t_train,y_train)
        func =@(x) h(1)./(1+exp(h(2)+h(3)*x));
end
%% Reality check
t_real = [1:length(cases_real)]'-1;
y_real = cumsum(cases_real);
y_model = round(func(t_real));
pe      = y_model - y_real;
figure('Name','Validation','NumberTitle','off','visible',visFlag);
subplot(2,1,1)
plot(t_real,y_model,'-'); hold on;
scatter(t_real,y_real,'filled'); hold on;
for t = 1:length(t_real)
    line([t_real(t) t_real(t)],[y_real(t) y_model(t)]); hold on;
end
xticks(t_real(weekly)); xticklabels(weeks); xtickangle(45);
% xlabel('days from patient zero'); 
ylabel('total cases');
legend('Modelled data','True data','Location','northwest');
subplot(2,1,2)
plot(t_real,pe,'--'); hold on;
plot([t_real(1) t_real(t)],[0 0],'--k');
xticks(t_real(weekly)); xticklabels(weeks); xtickangle(45);
% xlabel('days from patient zero'); 
ylabel('fit bias');
tikzName = [foName,'/fit_error_',curveType,'.tikz'];
figName = [foName,'/fit_error_',curveType];
try
    cleanfigure;
    matlab2tikz(tikzName, 'showInfo', false,'parseStrings',false,'standalone', ...
            false, 'height', '10cm', 'width','10cm','checkForUpdates',false);
catch
    warning('Tikz libraries are missing. Saving as an imagee.');
    print(figName,'-dpng')
end
%% Predicttion
nweeks = 2;
ndays  = nweeks*7;
for iweek = 1:nweeks
    weekly = [weekly; weekly(end) + 7];
    weeks{end+1} = ['+ ',num2str(iweek),' weeks'];
end
t2      = [t_train(end):t_train(end)+ndays]';
y2      = func(t2);
y2      = round(y2);
y_old   = func(t_train);
t_all   = [t_train; t2];
figure('Name','Prediction','NumberTitle','off','visible',visFlag);
plot(t_train,y_old,'Linewidth',2); hold on;
plot(t2,y2,'-o','Linewidth',2); hold on;
plot(t_train(end),y_train(end),'*','Linewidth',8); hold on;
xticks(t_all(weekly)); xticklabels(weeks); xtickangle(45);
legend('Fitted curve','Prediction',lastdate,'Location','northwest');
% xlabel('days from patient zero'); 
ylabel('total cases');
tikzName = [foName,'/prediction_',curveType,'.tikz'];
figName = [foName,'/prediction_',curveType];
try
    cleanfigure;
    matlab2tikz(tikzName, 'showInfo', false,'parseStrings',false,'standalone', ...
            false, 'height', '10cm', 'width','10cm','checkForUpdates',false);
catch
    warning('Tikz libraries are missing. Saving as an imagee.');
end
print(figName,'-dpng')
%% Save selected results
fiName = [foName,'/results.mat'];
save(fiName,'lastdate','nweeks','y2','t2','func');
