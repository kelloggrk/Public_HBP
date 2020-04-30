% Function to compute lifetime production based on decline curve
function [totProd, discProd] = LifetimeProd(param)

% Pull parameters
d1       = param.d1;
d2       = param.d2;
tau     = param.tau;
delta   = param.delta;
Mvec    = param.M;
T       = param.T;

% Construct T month time series
t       = repmat((1:T)',numel(Mvec),1);
M       = kron(Mvec, ones(T,1));

prod1 = M .* (min(t ./ tau, 1)) .^ d1;
prod2 = M ./ (2 .* tau .* d2);
prod3 = 1 - exp( -d2 .* (t - tau) );

cumProd = prod1 + prod2 .* prod3 .* (t > tau);

% Get monthly production
monthProd = [cumProd(1); diff(cumProd,[],1)];
monthProd(t==1) = cumProd(t==1);

% Discount and sum
discount = delta.^(1/12).^t;
discProd = sum(reshape(monthProd .* discount,T,numel(Mvec)),1);
totProd  = sum(reshape(monthProd,T,numel(Mvec)),1);
