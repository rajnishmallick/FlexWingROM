%  FlexWingROM test

clear; close all; clc

tol = 1e-3;

addpath(genpath('code'))

% preconditions
assert(exist('MAIN','file') == 2,'Could not find MAIN script')

%% Test 1: generate NACA6418 wing design and simulaiton parameters
try 
    load(['data', filesep, 'unitTest1data'])
catch ME
    warning('Could not load test 1 data')
    rethrow(ME)
end

try
    [wingDesign, simParam] = wingDesignAndSimParameters(1, 'NACA_6418', 1);
catch ME
    warning('Could not run wingDesignAndSimParameters')
    rethrow(ME)
end

% check if correct parameters are assigned
assert(abs(wingDesign.nRibsC - wingDesign_true.nRibsC) < tol, 'Error in defining wing parameters, check wingDesignAndSimParameters')

 
%% Test 2: generate finite element and aerodynamic model 
try 
    load(['data', filesep, 'unitTest1data'])
catch ME
    warning('Could not load wingDesign and simParam data for test 2')
    rethrow(ME)
end

try 
    load(['data', filesep, 'unitTest2data'])
catch ME
    warning('Could not load test 2 data')
    rethrow(ME)
end

% test generate wing structure model
try
    wingModelStructure = generateWingModelStructure(wingDesign,simParam);
catch ME
    warning('Could not run generateWingModelStructure')
    rethrow(ME);
end

% test generate wing aero model
try
    wingModelAero = generateWingModelAero(wingDesign,simParam,wingModelStructure);
catch ME
    warning('Could not run generateWingModelAero')
    rethrow(ME)
end

% check if correct wing model is generated
assert(mean(mean(abs(wingModelStructure.M_MODES - wingModel_true.M_MODES))) < tol,'Error in generating wing structure model, check generateWingModelStructure')
assert(mean(mean(abs(wingModelAero.viscPre.cl - wingModel_true.viscPre.cl))) < tol,'Error in generating wing aero model, check generateWingModelAero')




%% To test the FSI code and reduced order modeling methods, follow the four examples

% % test the steady FSI
% example1_NACA0012_FSI_modal_vs_displacement

% % test the unsteady FSI
% example2_NACA6418_unsteadyFSI

% % compare the unsteady panel method with Theodorsen
% example3_NACA0012_unsteadyPM_vs_Theodorsen

% % test the ROM generation
% example4_NACA6418_ROM

