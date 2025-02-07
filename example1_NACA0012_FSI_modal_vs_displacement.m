
%%%%%%%%%%
%
%% This test code runs a NACA0012 steady FSI and compares a modal vs. displacement FE model 
% 
%
%  Urban Fasel, 2021
%
%%%%%%%%%%

clear; close all; clc

addpath(genpath('code'))

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% WING DESIGN & SIMULATION PARAMETERS
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

generateWing = true;        % generate or load wing design parameters and FSI model
storeAllData = false;       % store all data: needed for runTestSteady

airfoil = 'NACA_0012';      % choose airfoil: coordinates are generated with createNACA4.m  
morphingWing = false;       % set true for wing design with compliant ribs -> morphing for roll and load control
plt = true;                 % plot results of test cases


% define the main wing design and simulation parameters
if generateWing
    [wingDesign, simParam] = wingDesignAndSimParameters(morphingWing, airfoil, plt);
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% generate finite element and aerodynamic model
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if generateWing
    % generate wing structure model 
    wingModelStructure = generateWingModelStructure(wingDesign,simParam);

    % generate wing aero model
    wingModelAero = generateWingModelAero(wingDesign,simParam,wingModelStructure);

    % plot finite element mesh, and vibration and morphing deformation modes
    if plt
        plotModel(wingDesign, simParam, wingModelAero, wingModelStructure)
    end
    
    % save parameters that are used in FSI
    paramFSI = saveParamFSI(wingDesign,simParam,wingModelStructure,wingModelAero,storeAllData);
else

    parameters = load(['data', filesep, 'parsim_FSI_', airfoil, '.mat']);
    paramFSI = parameters.paramFSI;
end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%% run test case:
% 
%   - comparing modal vs. full FE model with steady panel method
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

paramFSI.plt = true;

SteadyTestCases = runSteadyFSItestcases(paramFSI, simParam, wingModelStructure, wingDesign, wingModelAero);

liftError = SteadyTestCases.liftError_steady
rollError = SteadyTestCases.rollError_steady


