%% run parallel simulation

function wingModelAero = generateWingModelAero(wingDesign,simParam,wingModelStructure)

%%
%
%  By Giulio Molinari
%
%  Modified by Urban Fasel
%
%


FE_Grid = wingModelStructure.FE_Grid;

xMeshTol = .5e-3;
zMeshTol = .5e-3;
num_airfoil_nodes_panel = simParam.num_airfoil_nodes_panel;

% Init aerodynamic properties
b = wingDesign.span;
n_seg_LLT = simParam.n_seg_LLT; % number of segments per half span, eLLT
n_seg_PM = simParam.n_seg_PM; % number of segments per half span, Panel Method

SkinNodeListU = unique(wingModelStructure.SkinNodeListU);  % up
SkinNodeListD = unique(wingModelStructure.SkinNodeListD);  % down

y_segLimit = cosspace(-b/2, b/2, 2*n_seg_LLT + 1);
y_segMidpoint = 0.5*(y_segLimit(2:end) + y_segLimit(1:end-1)); % midpoint of each segment

wingModelAero.y_segLimit = y_segLimit;
wingModelAero.y_segMidpoint = y_segMidpoint;

% Init structural model parameters
FE_Grid_rev = sparse([FE_Grid.ID], ones(length(FE_Grid.ID),1), (1:length(FE_Grid.ID)), max(FE_Grid.ID), 1, length(FE_Grid.ID));


%% Define aerodynamic model

% cosine distributed panels
relaxation_cosine = 0.5;
zMesh_norm2Cos = cosspace(-1, 1, 2*(n_seg_PM+1)-1,relaxation_cosine);
[xMesh_norm, zMesh_norm] = meshgrid(fliplr(cosspace(xMeshTol, 1, num_airfoil_nodes_panel,relaxation_cosine)), [0, zMesh_norm2Cos(n_seg_PM+2:end)]);
zMesh_norm_S2Cos = cosspace(-1+zMeshTol, 1-zMeshTol, 2*(n_seg_PM+1)-1,relaxation_cosine);
[xMesh_norm_S, zMesh_norm_S] = meshgrid(fliplr(cosspace(xMeshTol, 1-xMeshTol, num_airfoil_nodes_panel,relaxation_cosine)), [0, zMesh_norm_S2Cos(n_seg_PM+2:end)]);

xMesh = zeros(size(xMesh_norm));
for j = 1:size(xMesh_norm,1)
	%%%% ####### works only when the panels are aligned along the x axis. #######
	xMesh(j,:) = xMesh_norm(j,:)*wingDesign.chord;
end

zMesh = zMesh_norm*(b/2);

% SkinNodeList Left and Right
dID = 1000000;

FE_Grid_double = find(FE_Grid.Z == 0);
FE_Grid_SKIN_doubleU = [];
FE_Grid_SKIN_doubleD = [];
for iDouble = 1:length(FE_Grid_double)
    FE_Grid_SKIN_doubleU = [FE_Grid_SKIN_doubleU; SkinNodeListU(find(SkinNodeListU == FE_Grid.ID(FE_Grid_double(iDouble))))];
    FE_Grid_SKIN_doubleD = [FE_Grid_SKIN_doubleD; SkinNodeListD(find(SkinNodeListD == FE_Grid.ID(FE_Grid_double(iDouble))))];
end
SkinNodeListUL = SkinNodeListU(SkinNodeListU < dID);
SkinNodeListDL = SkinNodeListD(SkinNodeListD < dID);
SkinNodeListUR = [SkinNodeListU(SkinNodeListU >= dID); FE_Grid_SKIN_doubleU];
SkinNodeListDR = [SkinNodeListD(SkinNodeListD >= dID); FE_Grid_SKIN_doubleD]; 

% create triscatteredinterp on SkinNodeListU, SkinNodeListD L
skinNodesX_UL = FE_Grid.X(FE_Grid_rev(SkinNodeListUL));
skinNodesZ_UL = FE_Grid.Z(FE_Grid_rev(SkinNodeListUL));
skinNodesY_UL = FE_Grid.Y(FE_Grid_rev(SkinNodeListUL));
skinNodesX_DL = FE_Grid.X(FE_Grid_rev(SkinNodeListDL));
skinNodesZ_DL = FE_Grid.Z(FE_Grid_rev(SkinNodeListDL));
skinNodesY_DL = FE_Grid.Y(FE_Grid_rev(SkinNodeListDL));
TSI_Str2Aer_PM_UpL = scatteredInterpolant(skinNodesX_UL/wingDesign.chord, skinNodesZ_UL./(b/2), skinNodesY_UL);
TSI_Str2Aer_PM_DnL = scatteredInterpolant(skinNodesX_DL/wingDesign.chord, skinNodesZ_DL./(b/2), skinNodesY_DL);
% create triscatteredinterp on SkinNodeListU, SkinNodeListD R
skinNodesX_UR = FE_Grid.X(FE_Grid_rev(SkinNodeListUR));
skinNodesZ_UR = -FE_Grid.Z(FE_Grid_rev(SkinNodeListUR));
skinNodesY_UR = FE_Grid.Y(FE_Grid_rev(SkinNodeListUR));
skinNodesX_DR = FE_Grid.X(FE_Grid_rev(SkinNodeListDR));
skinNodesZ_DR = -FE_Grid.Z(FE_Grid_rev(SkinNodeListDR));
skinNodesY_DR = FE_Grid.Y(FE_Grid_rev(SkinNodeListDR));
TSI_Str2Aer_PM_UpR = scatteredInterpolant(skinNodesX_UR/wingDesign.chord, skinNodesZ_UR./(b/2), skinNodesY_UR);
TSI_Str2Aer_PM_DnR = scatteredInterpolant(skinNodesX_DR/wingDesign.chord, skinNodesZ_DR./(b/2), skinNodesY_DR);

yMeshUndef_UpL = TSI_Str2Aer_PM_UpL(xMesh_norm_S, zMesh_norm_S);
yMeshUndef_DnL = TSI_Str2Aer_PM_DnL(xMesh_norm_S, zMesh_norm_S);
yMeshUndef_UpR = TSI_Str2Aer_PM_UpR(xMesh_norm_S, zMesh_norm_S);
yMeshUndef_DnR = TSI_Str2Aer_PM_DnR(xMesh_norm_S, zMesh_norm_S);

yMesh_Up_L = yMeshUndef_UpL;
yMesh_Dn_L = yMeshUndef_DnL;

yMesh_Up_R = yMeshUndef_UpR;
yMesh_Dn_R = yMeshUndef_DnR;

% the leading edge of yMesh_Dn conicides with the leading edge of yMesh_Up, and it can contain NaNs. Replace it with the leading edge of yMesh_Up
yMesh_Dn_L(:,end) = yMesh_Up_L(:,end);
yMesh_Dn_R(:,end) = yMesh_Up_R(:,end);

% Close the profile on the WINGTIP
yMesh_sidesClosed_L = 0.5*(yMesh_Up_L(end,:) + yMesh_Dn_L(end,:));
yMesh_sidesClosed_R = 0.5*(yMesh_Up_R(end,:) + yMesh_Dn_R(end,:));

% Join the two wings in the MIDDLE
yMesh_middle_Up = .5*yMesh_Up_L(1,:) + .5*yMesh_Up_R(1,:);
yMesh_middle_Dn = .5*yMesh_Dn_L(1,:) + .5*yMesh_Dn_R(1,:);

yMesh_sidesClosedUp = [yMesh_sidesClosed_L; yMesh_Up_L(end:-1:2, :); yMesh_middle_Up; yMesh_Up_R(2:end, :); yMesh_sidesClosed_R];
yMesh_sidesClosedDn = [yMesh_sidesClosed_L; yMesh_Dn_L(end:-1:2, :); yMesh_middle_Dn; yMesh_Dn_R(2:end, :); yMesh_sidesClosed_R];

%Add wake panels for trailing edge Kutta condition. Wake panels end up being last array column
wakelength = 50*wingDesign.chord; % number of chordlengths to extend wake panels downstrem of t.e. 


%% precalculate panel method mesh parameters
% the leading edge of yMesh_Dn conicides with the leading edge of yMesh_Up, and it can contain NaNs. Replace it with the leading edge of yMesh_Up
xMesh_sidesClosed = [xMesh([end:-1:2], :); xMesh([1:end], :)];
zMesh_sidesClosed = [-zMesh([end:-1:2], :); zMesh([1:end], :)];
xMesh_loop = xMesh_sidesClosed(:, [1:end, end-1:-1:2]);
zMesh_loop = zMesh_sidesClosed(:, [1:end, end-1:-1:2]);

wingModelAero.xMesh_loop = xMesh_loop;
wingModelAero.zMesh_loop = zMesh_loop;


%% Thin plate spline interpolation
pInterU = FE_Grid_rev(SkinNodeListU);
pInterD = FE_Grid_rev(SkinNodeListD);
skinNodesXU_tps = FE_Grid.X(pInterU);
skinNodesYU_tps = FE_Grid.Y(pInterU);
skinNodesZU_tps = FE_Grid.Z(pInterU);
skinNodesXD_tps = FE_Grid.X(pInterD);
skinNodesYD_tps = FE_Grid.Y(pInterD);
skinNodesZD_tps = FE_Grid.Z(pInterD);

xMesh_loopU = xMesh_sidesClosed(:, end:-1:1);
yMesh_loopU = fliplr(yMesh_sidesClosedUp(2:end-1,:));
zMesh_loopU = zMesh_sidesClosed(:, end:-1:1);
xMesh_loopD = xMesh_sidesClosed(:, 1:end);
yMesh_loopD = yMesh_sidesClosedDn(2:end-1,1:end);
zMesh_loopD = zMesh_sidesClosed(:, 1:end);

% get thin plate spline interpolation matrix
[GtpsU,GtpsSU] = TPS(skinNodesXU_tps,skinNodesYU_tps,skinNodesZU_tps,xMesh_loopU(:),yMesh_loopU(:),zMesh_loopU(:));
[GtpsD,GtpsSD] = TPS(skinNodesXD_tps,skinNodesYD_tps,skinNodesZD_tps,xMesh_loopD(:),yMesh_loopD(:),zMesh_loopD(:));

wingModelAeroFullK.pInterU = pInterU;
wingModelAeroFullK.pInterD = pInterD;
wingModelAeroFullK.GtpsSU = GtpsSU;
wingModelAeroFullK.GtpsSD = GtpsSD;


%% Inverse Distance Weighting interpolation matrix
yMesh_Dn_L_2 = yMeshUndef_DnL;
yMesh_Dn_R_2 = yMeshUndef_DnR;
yMesh_Dn_L_2(:,end) = yMeshUndef_UpL(:,end);
yMesh_Dn_R_2(:,end) = yMeshUndef_UpR(:,end);
yMesh_middle_Up_2 = .5*yMeshUndef_UpL(1,:) + .5*yMeshUndef_UpR(1,:);
yMesh_middle_Dn_2 = .5*yMesh_Dn_L_2(1,:) + .5*yMesh_Dn_R_2(1,:);
yMesh_sidesClosedUp_2 = [yMeshUndef_UpL(end:-1:2, :); yMesh_middle_Up_2; yMeshUndef_UpR(2:end, :)];
yMesh_sidesClosedDn_2 = [yMesh_Dn_L_2(end:-1:2, :); yMesh_middle_Dn_2; yMesh_Dn_R_2(2:end, :)];
yMesh_loop = [yMesh_sidesClosedUp_2(:,1:end-1), fliplr(yMesh_sidesClosedDn_2(:,2:end))];

wingModelAero.yMesh_loop = yMesh_loop;

aer_x = xMesh_loop;
aer_y = -zMesh_loop;
aer_z = yMesh_loop;

[M1,N1] = size(aer_x);
wingModelAero.M1 = M1;
wingModelAero.N1 = N1;

x = [];
y = [];
z = [];
x(1:N1,1:M1) = aer_x';
y(1:N1,1:M1) = aer_y';
z(1:N1,1:M1) = aer_z';

% close trailing edge
N1 = N1+1;
x = [x;x(1,:)];
y = [y;y(1,:)];
z = [z;z(1,:)];

M = M1-1;
N = N1-1;     
N2 = N+2;
farpoint = 1000;

for j = 1:M1
    x(N2,j) = x(N1,j)+farpoint;
    y(N2,j) = y(N1,j);
    z(N2,j) = z(N1,j);
end

cx = (x(1:N1,1:M) + x(1:N1,2:M+1) + x(2:N1+1,1:M) + x(2:N1+1,2:M+1))/4;
cy = (y(1:N1,1:M) + y(1:N1,2:M+1) + y(2:N1+1,1:M) + y(2:N1+1,2:M+1))/4;
cz = (z(1:N1,1:M) + z(1:N1,2:M+1) + z(2:N1+1,1:M) + z(2:N1+1,2:M+1))/4;

% calculate interpolation matrix from collocation point to structure
skinNodesXU = FE_Grid.X(pInterU);
skinNodesYU = FE_Grid.Y(pInterU);
skinNodesZU = FE_Grid.Z(pInterU);
skinNodesXD = FE_Grid.X(pInterD);
skinNodesYD = FE_Grid.Y(pInterD);
skinNodesZD = FE_Grid.Z(pInterD);

cxU = cx(1:(size(cx,1)-1)/2+1,:); % to avoid extrapolation of force: overlap trailing edge nodes
cyU = cy(1:(size(cx,1)-1)/2+1,:);
czU = cz(1:(size(cx,1)-1)/2+1,:);
cxD = cx((size(cx,1)-1)/2:end-1,:);
cyD = cy((size(cx,1)-1)/2:end-1,:);
czD = cz((size(cx,1)-1)/2:end-1,:);

% get inverse distance weighting interpolation matrix
IDWu = IDW(skinNodesXU,skinNodesYU,skinNodesZU,cxU(:),czU(:),cyU(:));
IDWd = IDW(skinNodesXD,skinNodesYD,skinNodesZD,cxD(:),czD(:),cyD(:));

wingModelAeroFullK.IDWu = IDWu;
wingModelAeroFullK.IDWd = IDWd;

    
%% precalculate lifting line parameters for induced drag calculation
yMesh_Up_L = yMeshUndef_UpL;
yMesh_Dn_L = yMeshUndef_DnL;
yMesh_Up_R = yMeshUndef_UpR;
yMesh_Dn_R = yMeshUndef_DnR;
yMesh_sidesClosedUp = [yMesh_Up_L(end:-1:2, :); yMesh_middle_Up; yMesh_Up_R(2:end, :)];
yMesh_sidesClosedDn = [yMesh_Dn_L(end:-1:2, :); yMesh_middle_Dn; yMesh_Dn_R(2:end, :)];
yMesh_loop = [yMesh_sidesClosedUp(:,1:end-1), fliplr(yMesh_sidesClosedDn(:,2:end))];
aer_x = (xMesh_loop);
aer_y = -(zMesh_loop);
aer_z = (yMesh_loop);
aer_x(:,end+1)=aer_x(:,end)+wakelength; %Extend wake panels downstream in the plane of the root chord 
aer_y(:,end+1)=aer_y(:,end); %(but with any side slip of the free stream)
aer_z(:,end+1)=aer_z(:,end);
        
ri = reshape(1:numel(aer_x), size(aer_x)); %index of vertices

se=ri(1:end-1,1:end-2);sw=ri(2:end,1:end-2); %indices of upper left and lower left corners EXCEPT WAKE
ne=ri(1:end-1,2:end-1);nw=ri(2:end,2:end-1); %indices of upper right and lower right corners EXCEPT WAKE

iColLE = (size(ne,2)-1)/2+1;

% order of nodes defining panels must be counter clockwise
aer_quad_wing(:,:,1) = [se ne(:,end)];
aer_quad_wing(:,:,2) = [ne se(:,1)];
aer_quad_wing(:,:,3) = [nw sw(:,1)];
aer_quad_wing(:,:,4) = [sw nw(:,end)];
aer_quad_wing_ID = reshape(1:numel(aer_quad_wing)/4, size(aer_quad_wing,1), size(aer_quad_wing,2));

% rectangular panels closing the profile on the edges
aer_quad_sides(:,:,1) = [se(1,2:(iColLE-1));      sw(end,2:(iColLE-1))];
aer_quad_sides(:,:,2) = [ne(1,end:-1:(iColLE+2)); nw(end,2:(iColLE-1))];
aer_quad_sides(:,:,3) = [se(1,end:-1:(iColLE+2)); sw(end,end:-1:(iColLE+2))];
aer_quad_sides(:,:,4) = [ne(1,2:(iColLE-1));      nw(end,end:-1:(iColLE+2))];
aer_quad_sides_ID = max(aer_quad_wing_ID(:)) + reshape(1:numel(aer_quad_sides)/4, size(aer_quad_sides,1), size(aer_quad_sides,2));

% triangular panels closing the profile on the edges
aer_tria_sides(:,:,1) = [se(1,1)   ne(1,iColLE);   sw(end,1)   nw(end,iColLE)];
aer_tria_sides(:,:,2) = [ne(1,end) se(1,iColLE);   nw(end,1)   nw(end,iColLE+1)];
aer_tria_sides(:,:,3) = [ne(1,1)   ne(1,iColLE+1); nw(end,end) sw(end,iColLE)];
aer_tria_sides_ID = max(aer_quad_sides_ID(:)) + reshape(1:numel(aer_tria_sides)/3, size(aer_tria_sides,1), size(aer_tria_sides,2));

aer_edgeR_faces = [aer_tria_sides_ID(1,1), aer_quad_sides_ID(1,:), aer_tria_sides_ID(1,2)];
aer_edgeR_faces = [aer_edgeR_faces fliplr(aer_edgeR_faces)];
aer_edgeL_faces = [aer_tria_sides_ID(2,1), aer_quad_sides_ID(2,:), aer_tria_sides_ID(2,2)];
aer_edgeL_faces = [aer_edgeL_faces fliplr(aer_edgeL_faces)];

aer_quad_wing_neighbour = zeros(size(aer_quad_wing));
aer_quad_wing_neighbour(:,:,1) = [aer_quad_wing_ID(:, 2:end) zeros(size(aer_quad_wing, 1), 1)]; % north
aer_quad_wing_neighbour(:,:,2) = [aer_edgeR_faces; aer_quad_wing_ID(1:end-1, :)]; % east
aer_quad_wing_neighbour(:,:,3) = [zeros(size(aer_quad_wing, 1), 1) aer_quad_wing_ID(:, 1:end-1)]; % south
aer_quad_wing_neighbour(:,:,4) = [aer_quad_wing_ID(2:end, :); aer_edgeL_faces]; % west

cLdistr_yPos = zeros(size(aer_quad_wing, 1), 1);
for i = 1:numel(aer_quad_wing)/4
    [j, k] = ind2sub([size(aer_quad_wing_neighbour,1), size(aer_quad_wing_neighbour,2)], i);
    fourNodesID = [aer_quad_wing(j,k,1), aer_quad_wing(j,k,2), aer_quad_wing(j,k,3), aer_quad_wing(j,k,4)];
    fourNodesPos = [aer_x(fourNodesID); aer_y(fourNodesID); aer_z(fourNodesID)];
    cLdistr_yPos(j) = .25*sum(fourNodesPos(2,:));
end

wingModelAero.cLdistr_yPos = cLdistr_yPos;

% precalculate AIC matrix for lifting line method that is used for induced drag calculation
colnorm = @(X,P) sum(abs(X).^P,1).^(1/P);

n_seg = length(y_segLimit)-1;
y_segMidpoint = 0.5*(y_segLimit(2:end) + y_segLimit(1:end-1));

c = wingDesign.chord * ones(size(y_segMidpoint));

% Calculate HorseShoe Vortices coordinates, HorseShoe Vortices Normals and Control Points
c_HSV = interp1(y_segMidpoint, c, y_segLimit, 'linear', 'extrap');
HSV = [	(-c_HSV(:)*0.25)'; ...
		y_segLimit(:)'; ...
		zeros(1,numel(y_segLimit))];
CP = [	-c(1:end)*0.75; ...
		.5*(y_segLimit(1:end-1) + y_segLimit(2:end)); ...
		zeros(1,numel(y_segLimit)-1)];
% HSVN = crossC((HSV(:,2:end) - HSV(:,1:end-1)), repmat([-1; 0; 0], 1, length(y_segMidpoint)));
HSVN = cross((HSV(:,2:end) - HSV(:,1:end-1)), repmat([-1; 0; 0], 1, length(y_segMidpoint)));
HSVN = HSVN./repmat(colnorm(HSVN, 2), 3, 1);

K_alpha_ind_out = zeros(n_seg);

for i = 1:n_seg
	for j = 1:n_seg/2
% 		K_alpha_ind_out(i,j) = dotC(vortex_semiinf(CP(:,i), HSV(:,j), [-1; 0; 0]) - vortex_semiinf(CP(:,i), HSV(:,j+1), [-1; 0; 0]), HSVN(:,i));
		K_alpha_ind_out(i,j) = dot(vortex_semiinf(CP(:,i), HSV(:,j), [-1; 0; 0]) - vortex_semiinf(CP(:,i), HSV(:,j+1), [-1; 0; 0]), HSVN(:,i));
		% NB: matrix is *not* symmetric around principal diagonal!
	end
	K_alpha_ind_out(end-i+1,:) = fliplr(K_alpha_ind_out(i,:));
end

wingModelAero.K_alpha_ind_ELLT = K_alpha_ind_out;


%% Precalculate interpolation matrices in modal coordinates

nModes = simParam.nmodes + 2;
nDOF = 6*size(FE_Grid.ID, 1);

phi_GLOB = zeros(nDOF, nModes);
phi_GLOB(wingModelStructure.DOF_ASET,:) = wingModelStructure.phi_ASET;

phi_GLOB2 = zeros(nDOF/6, 6, nModes);

phi_GLOB_X = zeros(nDOF/6, nModes);
phi_GLOB_Y = zeros(nDOF/6, nModes);
phi_GLOB_Z = zeros(nDOF/6, nModes);

phi_GLOB_X_U = zeros(size(pInterU, 1), nModes);
phi_GLOB_Y_U = zeros(size(pInterU, 1), nModes);
phi_GLOB_Z_U = zeros(size(pInterU, 1), nModes);

phi_GLOB_X_D = zeros(size(pInterD, 1), nModes);
phi_GLOB_Y_D = zeros(size(pInterD, 1), nModes);
phi_GLOB_Z_D = zeros(size(pInterD, 1), nModes);

pInterU2 = zeros(size(pInterU));
k = 1;
for i = 1:length(pInterU)
    if ~(pInterD == pInterU(i))
        pInterU2(k) = pInterU(i);
        k = k+1;
    end
end
pInterU2 = pInterU2(1:k-1);
phi_GLOB_X_U2 = zeros(size(pInterU2, 1), nModes);
phi_GLOB_Y_U2 = zeros(size(pInterU2, 1), nModes);
phi_GLOB_Z_U2 = zeros(size(pInterU2, 1), nModes);

for i = 1:nModes
    phi_GLOB2(:,:,i) = reshape(phi_GLOB(:,i)', 6, nDOF/6)';
    
    phi_GLOB_X(:,i) = phi_GLOB2(:,1,i);
    phi_GLOB_Y(:,i) = phi_GLOB2(:,2,i);
    phi_GLOB_Z(:,i) = phi_GLOB2(:,3,i);
    
    phi_GLOB_X_U(:,i) = phi_GLOB_X(pInterU,i);
    phi_GLOB_Y_U(:,i) = phi_GLOB_Y(pInterU,i);
    phi_GLOB_Z_U(:,i) = phi_GLOB_Z(pInterU,i);
    
    phi_GLOB_X_D(:,i) = phi_GLOB_X(pInterD,i);
    phi_GLOB_Y_D(:,i) = phi_GLOB_Y(pInterD,i);
    phi_GLOB_Z_D(:,i) = phi_GLOB_Z(pInterD,i);

    phi_GLOB_X_U2(:,i) = phi_GLOB_X(pInterU2,i);
    phi_GLOB_Y_U2(:,i) = phi_GLOB_Y(pInterU2,i);
    phi_GLOB_Z_U2(:,i) = phi_GLOB_Z(pInterU2,i);
end

% Precalculate TPS Thin Plate Spline interpolation in modal coordinates
TPSU_X = GtpsSU*phi_GLOB_X_U;
TPSU_Y = GtpsSU*phi_GLOB_Y_U;
TPSU_Z = GtpsSU*phi_GLOB_Z_U;

TPSD_X = GtpsSD*phi_GLOB_X_D;
TPSD_Y = GtpsSD*phi_GLOB_Y_D;
TPSD_Z = GtpsSD*phi_GLOB_Z_D;


wingModelAero.TPSU_X = TPSU_X;
wingModelAero.TPSU_Y = TPSU_Y;
wingModelAero.TPSU_Z = TPSU_Z;

wingModelAero.TPSD_X = TPSD_X;
wingModelAero.TPSD_Y = TPSD_Y;
wingModelAero.TPSD_Z = TPSD_Z;

% Precalculate IDW inverse distance weighting interpolation in modal coordinates

wingModelAero.IDWuX = phi_GLOB_X_U'*IDWu;
wingModelAero.IDWuY = phi_GLOB_Y_U'*IDWu;
wingModelAero.IDWuZ = phi_GLOB_Z_U'*IDWu;

wingModelAero.IDWdX = phi_GLOB_X_D'*IDWd;
wingModelAero.IDWdY = phi_GLOB_Y_D'*IDWd;
wingModelAero.IDWdZ = phi_GLOB_Z_D'*IDWd;


%% precalculate actuation forces in modal coordinatesactuators

actForce = simParam.actForce;

% unsymmetric actuation for roll control
forceACTinp.L = -actForce;
forceACTinp.R = actForce;

ACTparam = wingModelStructure.ACTparam;
ActFront_ID = ACTparam.ActFront_ID;
ActRear_ID = ACTparam.ActRear_ID;
ActFront_IDR = ACTparam.ActFront_IDR;
ActRear_IDR = ACTparam.ActRear_IDR;
nV = ACTparam.nV;
nVR = ACTparam.nVR;

forces_ACT = zeros(nDOF/6, 6);
% left wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_ID(iAct),1:3) = -nV(iAct,:)*forceACTinp.L;
    forces_ACT(ActRear_ID(iAct),1:3) = nV(iAct,:)*forceACTinp.L;
end
% right wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_IDR(iAct),1:3) = -nVR(iAct,:)*forceACTinp.R;
    forces_ACT(ActRear_IDR(iAct),1:3) = nVR(iAct,:)*forceACTinp.R;
end

forces_ACT_transp = forces_ACT';
forces_ACT_L = forces_ACT_transp(:);
forces_ACT_L(wingModelStructure.DOF_RSET) = [];

wingModelAero.fiACTMax = wingModelStructure.phi_ASET.'*forces_ACT_L;

% in case left and right roll actuation is unsymmetric
forceACTinp.L = actForce;
forceACTinp.R = -actForce;

forces_ACT = zeros(nDOF/6, 6);
% left wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_ID(iAct),1:3) = -nV(iAct,:)*forceACTinp.L;
    forces_ACT(ActRear_ID(iAct),1:3) = nV(iAct,:)*forceACTinp.L;
end
% right wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_IDR(iAct),1:3) = -nVR(iAct,:)*forceACTinp.R;
    forces_ACT(ActRear_IDR(iAct),1:3) = nVR(iAct,:)*forceACTinp.R;
end

forces_ACT_transp = forces_ACT';
forces_ACT_L = forces_ACT_transp(:);
forces_ACT_L(wingModelStructure.DOF_RSET) = [];

wingModelAero.fiACTMin = wingModelStructure.phi_ASET.'*forces_ACT_L;
 

% symmetric actuation for load control
forceACTinp.LA = actForce;

forces_ACT = zeros(nDOF/6, 6);
% left wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_ID(iAct),1:3) = -nV(iAct,:)*forceACTinp.LA;
    forces_ACT(ActRear_ID(iAct),1:3) = nV(iAct,:)*forceACTinp.LA;
end
% right wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_IDR(iAct),1:3) = -nVR(iAct,:)*forceACTinp.LA;
    forces_ACT(ActRear_IDR(iAct),1:3) = nVR(iAct,:)*forceACTinp.LA;
end

forces_ACT_transp = forces_ACT';
forces_ACT_L = forces_ACT_transp(:);
forces_ACT_L(wingModelStructure.DOF_RSET) = [];

wingModelAero.fiACT_LAMax = wingModelStructure.phi_ASET.'*forces_ACT_L;

forceACTinp.LA = -actForce;

forces_ACT = zeros(nDOF/6, 6);
% left wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_ID(iAct),1:3) = -nV(iAct,:)*forceACTinp.LA;
    forces_ACT(ActRear_ID(iAct),1:3) = nV(iAct,:)*forceACTinp.LA;
end
% right wing
for iAct = 2*wingDesign.nRibs:-2:2*wingDesign.nRibs-2*wingDesign.nRibsC+2 
    forces_ACT(ActFront_IDR(iAct),1:3) = -nVR(iAct,:)*forceACTinp.LA;
    forces_ACT(ActRear_IDR(iAct),1:3) = nVR(iAct,:)*forceACTinp.LA;
end

forces_ACT_transp = forces_ACT';
forces_ACT_L = forces_ACT_transp(:);
forces_ACT_L(wingModelStructure.DOF_RSET) = [];

wingModelAero.fiACT_LAMin = wingModelStructure.phi_ASET.'*forces_ACT_L;


%% Precalculate viscous drag and maximum cL using xfoil
% XFOIL only runs on Windows, therefore we load the data for NACA0012 and NACA6418 if the code is run on Linux

if ispc
    viscPre = preCalcVisc(wingDesign.airfoil,wingDesign.chord);
else
    viscPreLoad = load(['data',filesep,'PrecalculateXFOIL',filesep,'viscPre_',wingDesign.airfoil,'.mat']);
    viscPre = viscPreLoad.viscPre;
end
wingModelAero.viscPre = viscPre;


%% output parameters for fullK steady FSI
wingModelAero.wingModelAeroFullK = wingModelAeroFullK;
