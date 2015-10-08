function [settings, priorsARMA, settings.proposalsARMA] = getSettings()
%Returns structure containing the settings, the prior function handel, the proposal function handle, as
%well as the Likelihood function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   General Settings                                                      %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Number of draws from the posterior
settings.draws = 1500000;

%Import data. You may supply a function taking care of this. The data
%format must be compatible with the likelihood function.
settings.data = 'data.mat';

%Maximum AR Order
settings.pMax = 10;
%Maximum MA Order
settings.qMax = 10;

%Set Burn In
settings.burnIn = 500000;

%Save proposals? Useful for analyzing performance
settings.saveProposals = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Likelihood                                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Provide Handle to Likelihood
settings.likelihoodFunction = @evaluateLikelihood;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Priors                                                                %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Function handles for prior distributions, autoregressive (moving average)
%(inverse) partial autocorrelations

%IMPORTANT: IT IS ASSUMED THAT THE PARAMETERS ARE A PRIOR INDEPENDENT! THE
%VALUE OF THE PRIOR IS THUS THE SUM OF THE LOG PRIOR VALUE FOR EACH PAC
%INDIVIDUALLY!!!!!
settings.priorsARMA.priorARParam1 = -1 + eps;
settings.priorsARMA.priorARParam2 = 1 - eps;
settings.priorsARMA.priorAR = @(x) unifpdf(x,settings.priorsARMA.priorARParam1,settings.priorsARMA.priorARParam2);

settings.priorsARMA.priorMAParam1 = -1 + eps;
settings.priorsARMA.priorMAParam2 = 1 - eps;
settings.priorsARMA.priorMA = @(x) unifpdf(x,settings.priorsARMA.priorMAParam1,settings.priorsARMA.priorMAParam2);

settings.priorsARMA.priorSigmaEParam1 = 1;
settings.priorsARMA.priorSigmaEParam2 = 1;
settings.priorsARMA.priorSigmaE = ...
    @(x) (x>0)*(settings.priorsARMA.priorSigmaEParam2^settings.priorsARMA.priorSigmaEParam1...
    / gamma(settings.priorsARMA.priorSigmaEParam1) * x^(-settings.priorsARMA.priorSigmaEParam1 - 1)...
    * exp(-settings.priorsARMA.priorSigmaEParam2/x));

settings.priorsARMA.priorPParam1 = settings.pMax;
settings.priorsARMA.priorP = @(x) unidpdf(x + 1,settings.priorsARMA.priorPParam1 + 1);

settings.priorsARMA.priorQParam1 = settings.qMax;
settings.priorsARMA.priorQ = @(x) unidpdf(x + 1,settings.priorsARMA.priorQParam1 + 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Proposals                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Setup proposal distributions for ARMA Coefficients and respective standard
%deviation. 

%Proposals are always centered around the current value of the respective
%parameters (PAC). Proposals have to be supplied in two ways: Firstly, the
%actual proposal, i.e. a function returning the sampled value for the
%parameters. Secondly, the evaluation of the PDF at the proposed value
%with the distribution centered around the current state.
%There can be as many parameters of the functions as you like. Only the
%handles are being used.
%Between Model Moves (If model changes)
settings.proposalsARMA.proposalARParam1Between = 0.045;
settings.proposalsARMA.proposalARBetween = @(mu) vectorizedRTNorm(-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalARParam1Between);
settings.proposalsARMA.evaluateProposalARBetween = @(x, mu) evaluateTruncatedNormalPDF(x,-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalARParam1Between);

settings.proposalsARMA.proposalMAParam1Between = 0.045;
settings.proposalsARMA.proposalMABetween = @(mu) vectorizedRTNorm(-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalARParam1Between);
settings.proposalsARMA.evaluateProposalMABetween = @(x, mu) evaluateTruncatedNormalPDF(x,-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalMAParam1Between);


%Within Model Moves (Model remains the same)
settings.proposalsARMA.proposalARParam1 = 0.02;
settings.proposalsARMA.proposalARParam2 = 0/0;
settings.proposalsARMA.proposalAR = @(mu) vectorizedRTNorm(-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalARParam1);
settings.proposalsARMA.evaluateProposalAR = @(x, mu) evaluateTruncatedNormalPDF(x,-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalARParam1);

settings.proposalsARMA.proposalMAParam1 = 0.02;
settings.proposalsARMA.proposalMAParam2 = 0/0;
settings.proposalsARMA.proposalMA = @(mu) vectorizedRTNorm(-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalARParam1);
settings.proposalsARMA.evaluateProposalMA = @(x, mu) evaluateTruncatedNormalPDF(x,-1,1,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalMAParam1);

settings.proposalsARMA.proposalSigmaEParam1 = 0.04;
settings.proposalsARMA.proposalSigmaEParam2 = 0/0;
settings.proposalsARMA.proposalSigmaE = @(mu) vectorizedRTNorm(0,1000,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalSigmaEParam1);
settings.proposalsARMA.evaluateProposalSigmaE = @(x, mu) evaluateTruncatedNormalPDF(x,0,1000,mu,ones(size(mu,1),1)*settings.proposalsARMA.proposalSigmaEParam1);

%Proposals AR-Order
settings.proposalsARMA.proposalPParam1 = settings.pMax;
settings.proposalsARMA.proposalPParam2 = 2.2;

%Discretized Laplace (Troughton Goodsill, Ehler Brooks 2004)
%Initialize Discrete Laplace CDF
settings.proposalsARMA.laplaceCDFP = discreteLaplaceCDF(settings.proposalsARMA.proposalPParam1, settings.proposalsARMA.proposalPParam2);
settings.proposalsARMA.laplacePDFP = discreteLaplacePDF(settings.proposalsARMA.proposalPParam1, settings.proposalsARMA.proposalPParam2);
settings.proposalsARMA.proposalP = @(x) sampleDiscreteLaplace(x, settings.proposalsARMA.laplaceCDFP);
settings.proposalsARMA.evaluateProposalP = @(x) evaluateDiscreteLaplacePDF(x(1),x(2),settings.proposalsARMA.laplacePDFP);


%Proposals MA-Order
settings.proposalsARMA.proposalQParam1 = settings.qMax;
settings.proposalsARMA.proposalQParam2 = 2.2;
settings.proposalsARMA.proposalQParam3 = 0/0;
settings.proposalsARMA.proposalQParam4 = 0/0;
%Uniform Proposal: 
% settings.proposalsARMA.proposalQ =  @(x) unidrnd(settings.proposalsARMA.proposalQParam1 + 1) - 1;

%Discretized Laplace (Troughton Goodsill, Ehler Brooks 2004)
settings.proposalsARMA.laplaceCDFQ = discreteLaplaceCDF(settings.proposalsARMA.proposalQParam1, settings.proposalsARMA.proposalQParam2);
settings.proposalsARMA.laplacePDFQ = discreteLaplacePDF(settings.proposalsARMA.proposalQParam1, settings.proposalsARMA.proposalQParam2);
settings.proposalsARMA.proposalQ = @(x) sampleDiscreteLaplace(x, settings.proposalsARMA.laplaceCDFQ);
settings.proposalsARMA.evaluateProposalQ = @(x) evaluateDiscreteLaplacePDF(x(1),x(2),settings.proposalsARMA.laplacePDFQ);

end