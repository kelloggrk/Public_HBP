% Function to compute difference between candidate decline curve predictions and data
% Estimate the value of d1 based on best fit

function [diff, jacob, prodComp] = DeclineFcn_EstD1(param,data,tau,wellIDX,scaleVec)
    %% Compute Function
    cumProd = data.cumProd;
    t       = data.t;

    param = param .* scaleVec;
    
    d1   = param(1);
    d2   = param(2);
    Mvec = param(3:end);

    M   = Mvec(wellIDX);

    % Use log production and OLS to get M
    % Then evaluate moments
    % Then do it again
    
    prod1 = M .* (min(t ./ tau, 1)) .^ d1;
    prod2 = M .* d1 ./ (tau .* d2);
    prod3 = 1 - exp( -d2 .* (t - tau) );

    prodComp        = prod1;
    prodComp(t>tau) = prod1(t>tau) + prod2(t>tau) .* prod3(t>tau);
    diff            = (log(prodComp) - log(cumProd));

    %% Compute Jacobian
    if nargout > 1
        jacobM   = zeros(numel(t),1);
        jacobD1   = zeros(numel(t),1);
        jacobD2   = zeros(numel(t),1);

        stage1 = t < tau;
        jacobM(stage1,:)      = (t(stage1) ./ tau) .^ d1;
        jacobD1(stage1,:)     = M(stage1) .* log(t(stage1) ./ tau) .* (t(stage1) ./ tau) .^ d1;
        jacobD2(stage1,:)     = 0;
        
        jacobM(~stage1,:)     = (1 + d1 ./ (tau .* d2) .* prod3(~stage1));
        jacobD1(~stage1,:)    = M(~stage1) ./ (tau .* d2) .* prod3(~stage1);
        jacobD2(~stage1,:)    = -prod2(~stage1) .* (1 ./ d2 .* prod3 (~stage1) - ...
                                (t(~stage1) - tau) .* exp( -d2 .* (t(~stage1) - tau) ));

        jacobMmat = zeros(numel(t),numel(Mvec));
        idx = sub2ind([numel(t), numel(Mvec)],(1:numel(t))',wellIDX);
        jacobMmat(idx) = jacobM;

        % Adjust jacobian to reflect scaling and log
        jacob = [jacobD1 jacobD2 jacobMmat] .* scaleVec';
        jacob = jacob ./ repmat(prodComp,1,size(jacob,2));

        
    end

end
