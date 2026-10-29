        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %-------------------------------For ABAQUS--------------------------------%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %----------------------------Hot-rolled I section ------------------------%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Objective
%Creation of an ABAQUS shell model (S4R) of a hot-rolled I-section from a
%2D strip model of the mid-surface cross-section, built directly in MATLAB.

%% Assumptions
%(1)ABAQUS S4/S4R shell elements are used for the plates.
%(2)Linear elastic material for eigenvalue analyses; elastic-plastic
%material for collapse analyses.
%(3)Loads are applied at the reference nodes (RP1/RP2) directly.
%(4)Should use an even number of FE elements along the length so that the
%midle section actually falls in the midle.

%% 2D cross-section model
% prop: [matnum Ex Ey vx vy G] 3 x nmats (100 web, 200 upper flange, 300 lower flange)
% node: [node# x z dofx dofz dofy dofrot stress] nnodes x 8 (only columns 1-3 are used)
% elem: [elem# nodei nodej t matnum] nelems x 5

%clear the workspace (optional)
clear all
close all
clc
format compact;
%% Parameters need to be modifided

fileID=fopen('1. Name.dat');
Name=textscan(fileID,'%s');
fclose(fileID);

elemtype='S4R';
First_headname_original = Name{1}{2};  
Foldername=Name{1}{1};
%%
% Dossier parent du répertoire courant
parentDir = fileparts(pwd);

% Dossier "Validations_results" dans le dossier parent
validationDir = fullfile(parentDir, 'H_R_Validations_results');

% Crée "H_R_Validations_results" s'il n'existe pas
if ~exist(validationDir, 'dir')
    mkdir(validationDir);
end

% Crée Foldername à l'intérieur de "Validations_results"
newFolderPath = fullfile(validationDir, Foldername);
if ~exist(newFolderPath, 'dir')
    mkdir(newFolderPath);
end

% Chemin complet vers le dossier de travail
Path2 = [newFolderPath filesep];
%%


% if ~exist(Foldername,'dir')==1
%     mkdir(Foldername);
% end
% 
% Path2 = strcat(pwd,'\',Foldername,'\');

if  exist(strcat(Path2,'Filename.dat'),'var')==0
    delete(strcat(Path2,'Filename.dat'));
end

if  exist(strcat(Path2,'Batch for inp and py.bat'),'var')==0
    delete(strcat(Path2,'Batch for inp and py.bat'));
end

 fid = fopen(strcat(Path2,'Batch for inp and py.bat'),'at');
    %fprintf(fid,'%s \n','path=%path%;C:\ABAQUS\SIMULIA\Abaqus product\Commands');   
    fprintf(fid,'%s\r\n',['path=%path%;C:\ABAQUS\SIMULIA\Abaqus product\Commands']);  
    fprintf(fid,'%s \r\n',[ ]);     
    fclose(fid);

%% Dimensions and properties
parameters=dlmread('3. Parameters.dat');
sequence=parameters(:,1);
nb=size(sequence); 
% [41] 1:1:96    57 65 73 81 89 o=[53 61 69 77 85 93]
parameters_section = [];

%% Mesh and Riks parameters (formerly '2. General_parameters.dat')
nwH = 13;             % number of elements in the web, H sections (h/b < 1.2)
nwI = 13;             % number of elements in the web, I sections (h/b >= 1.2)
Initial_inc = 0.5;    % initial arc-length increment
Scale_fact  = 1;      % total arc-length scale factor
Min_inc     = 0.001;  % minimum arc-length increment

%% Run options
reduced_output = 1;  % 1 = field output only for the nodes read by the .py (+ full field every 25 inc.) ; 0 = full PRESELECT field output every increment
keep_odb       = 0;   % 1 = keep the .odb after extraction (visualisation) ; 0 = delete it in the batch
lambda_switch  = 1.2; % major-axis slenderness above which the long-column Riks settings are used
riks_short     = [0.5 100];  % [max arc-length increment, max number of increments] for lambda <= lambda_switch
riks_long      = [5   150];  % idem for lambda >  lambda_switch (tested: same peak within 0.02%)

% for o=[1] o=1:1:nb(1) o=[54 55 56 62 63 64 70 71 72 78 79 80 86 87 88 94 95 96]

for o=1:1:288
Number=parameters(o,1);                      %The number of the parameter studies
B1=parameters(o,2);                          %Full width of upper flange input by user
B2=parameters(o,3);                          %Full width of lower flange input by user
H=parameters(o,4);                           %Full height of section input by user 
tf1=parameters(o,5);                         %Thickness of upper flange input by user 
tf2=parameters(o,6);                         %Thickness of lower flange input by user 
tw=parameters(o,7);                          %Thickness of web input by user 
r1=parameters(o,8);                          %upper radius
r2=parameters(o,9);                          %lLoad_Nower radius
L=parameters(o,10);
%L=B1;
% L= 5*B1;% if L=0, thus L=3*periodicity
periodicity_input=parameters(o,11);          %Periodicity adopted in this model (1,2,3 ou else)
magnitudeB1_input=parameters(o,12);          %Magnitude of the upper flange (0,1,2,3 ou else
magnitudeB2_input=parameters(o,13);          %Magnitude of the lower flange 
magnitudeH_input=parameters(o,14);           %Magnitude of the web
percentage=parameters(o,15);                 %Percentage of the imperfection
% mjglobalampli=parameters(o,16);              %Amplitude of global imperfection (major axis)
% miglobalampli=parameters(o,17);              %Amplitude of global imperfection (minor axis)
torsionalampli=parameters(o,18);             %Amplitude of torsional imperfection (minor axis)
analysis=parameters(o,19);                   %1--LBA; 2--Eig+GMNIA; 3--GMNIA
Loading=parameters(o,20);                    %1--N; 2--My; 3--Mz; 4--N+My; 5--N+Mz; 6--My+Mz; 7--N+My+Mz
Load_N=parameters(o,21)*1000;                     %Initial load (Compression-kN)---N
Load_My=parameters(o,22);                    %Initial load (Bending-kNm)
Load_Mz=parameters(o,23);                    %Initial load (Bending-kNm)

Temperature=parameters(o,24);
Fy=parameters(o,25);                         % Fy at ambiant temperature
ME=parameters(o,26);                         % Young's Modulus at ambiant temperature
mjglobalampli=parameters(o,29);
miglobalampli=0;
                             
% localampli=parameters(o,30)*1;
localampli=0;
% ecc=parameters(o,31); % set excentricity
ecc=0;

%% 
%Match section designation
fileID=fopen('4. Designation.dat');
Sectiontype=textscan(fileID,'%s');
fclose(fileID);

Designation=Sectiontype{1}{o};


%Change headname

headname_original = strcat(First_headname_original,'_',num2str(Fy),'_',Designation,'_',num2str(Temperature));


%nw=parameters(o,20);  
if (H/(0.5*(B1+B2)))<1.2  % <1.2 H section; >1.2 I section
    nw=nwH;
    %nw=15
else
    nw=nwI;
    %nw=30
end

if analysis==2
    caculation_number=2;
    analysis=1;
else
    caculation_number=1;
end

Loop=1;
while Loop<=caculation_number  
    
if Loading==1
    if analysis==1
        headname = strcat(headname_original,'_LBA','_N');
    elseif analysis==2||analysis==3
        headname = strcat(headname_original,'_GMNIA','_N');
    end
elseif Loading==2 
    if analysis==1
        headname = strcat(headname_original,'_LBA','_My');
    elseif analysis==2||analysis==3
        headname = strcat(headname_original,'_GMNIA','_My');
    end
elseif Loading==3 
    if analysis==1
        headname = strcat(headname_original,'_LBA','_Mz');
    elseif analysis==2||analysis==3
        headname = strcat(headname_original,'_GMNIA','_Mz');
    end  
elseif Loading==4 
    if analysis==1
        headname = strcat(headname_original,'_LBA','_N_',num2str(n),'_My');
    elseif analysis==2||analysis==3
        headname = strcat(headname_original,'_GMNIA','_N_',num2str(n),'_My');
    end  
elseif Loading==5
    if analysis==1
        headname = strcat(headname_original,'_LBA','_N_',num2str(n),'_Mz');
    elseif analysis==2||analysis==3
        headname = strcat(headname_original,'_GMNIA','_N_',num2str(n),'_Mz');
    end 
elseif Loading==6
    if analysis==1
        headname = strcat(headname_original,'_LBA','_My','_Mz_',num2str(teta));
    elseif analysis==2||analysis==3
        headname = strcat(headname_original,'_GMNIA','_My','_Mz_',num2str(teta));
    end 
elseif Loading==7
    if analysis==1
        headname = strcat(headname_original,'_LBA','_N_',num2str(n),'_My','_Mz_',num2str(teta));
    elseif analysis==2||analysis==3
        headname = strcat(headname_original,'_GMNIA','_N_',num2str(n),'_My','_Mz_',num2str(teta));
    end 
end

%% The profile properties 
h=H-tf1/2-tf2/2;                                        %Mid-surface height of section
dcen1=1/2*tf1+r1*(10-3*pi())/(12-3*pi());               %Center of the upper fillet
dcen2=1/2*tf2+r2*(10-3*pi())/(12-3*pi());               %Center of the upper fillet
springstiff=2000000;                                    %Spring stiffness


fprintf('Ligne: %.2f%%\n', o);
%% Periodicity and magnitude (******* need to be modifided)
period_B1=B1-2*r1-tw; %af1
period_B2=B2-2*r2-tw; %af2
period_H=H-tf1-tf2-r1-r2; %aw    
wB1=period_B1/(period_B1+period_B2+period_H);           %Weight of upper flange
wB2=period_B2/(period_B1+period_B2+period_H);           %Weight of lower flange
wH=period_H/(period_B1+period_B2+period_H);             %Weight of web

if periodicity_input==1
    periodicity=period_H;
elseif periodicity_input==2
        periodicity=period_B1;
elseif periodicity_input==3
        periodicity=period_B2;    
else
    periodicity=(period_H+period_B1)/2;
   %periodicity=(wB1*period_B1+wB2*period_B2+wH*period_H)/(wB1+wB2+wH);    %Weighted arithmetic mean
end

if L==0
L=3*periodicity;
end

if magnitudeB1_input==10
    magnitudeB1=0;
elseif magnitudeB1_input==100
    magnitudeB1=period_B1/percentage;
elseif magnitudeB1_input==200
        magnitudeB1=period_B2/percentage;
elseif magnitudeB1_input==300
        magnitudeB1=period_H/percentage;
    else
        % magnitudeB1=(wB1*period_B1+wB2*period_B2+wH*period_H)/(wB1+wB2+wH)/percentage; 
        magnitudeB1=localampli;
end

if magnitudeB2_input==10
    magnitudeB2=0;
elseif magnitudeB2_input==100
    magnitudeB2=period_B1/percentage;
elseif magnitudeB2_input==200
        magnitudeB2=period_B2/percentage;
elseif magnitudeB2_input==300
        magnitudeB2=period_H/percentage;
    else
        % magnitudeB2=(wB1*period_B1+wB2*period_B2+wH*period_H)/(wB1+wB2+wH)/percentage; 
        magnitudeB2=localampli;
end

if magnitudeH_input==10
    magnitudeH=0;
elseif magnitudeH_input==100
    magnitudeH=period_B1/percentage;
elseif magnitudeH_input==200
        magnitudeH=period_B2/percentage;
elseif magnitudeH_input==300
        magnitudeH=period_H/percentage;
     else
        % magnitudeH=(wB1*period_B1+wB2*period_B2+wH*period_H)/(wB1+wB2+wH)/percentage;  
        magnitudeH=localampli;
end

  %%Write .dat files with material law

%% ecentricity load
delta_u = 0; %310/2;180/2
ex = 0;
ey = 0;
xr1 = ex; yr1=ey; zr1= -delta_u;
xr2 = ex; yr2=ey; zr2= L+delta_u;
%% Material properties

prop=[100 ME ME 0.30 0.30 ME/2/(1+0.3);200 ME ME 0.30 0.30 ME/2/(1+0.3);300 ME ME 0.30 0.30 ME/2/(1+0.3)];   
  
%% Material law (true stress - plastic strain for ABAQUS *PLASTIC)
% Yun & Gardner (2017), "Stress-strain curves for hot-rolled steels",
% Journal of Constructional Steel Research 133, 36-46. https://doi.org/10.1016/j.jcsr.2017.01.024
% Generated from E and fy only; fu is the nominal value of the grade (EN 1993-1-1 Table 3.1).
% The same law is used for the web and both flanges.

material_model = 1;        % 1 = quad-linear, Eq.(3) ; 2 = bilinear + nonlinear hardening, Eq.(14)

if Temperature~=20
    warning('Yun & Gardner material law is for ambient temperature (Temperature = %g C).',Temperature);
end

fu = fu_nominal(Fy);
[sigma_true_mat,epsilon_pl_mat,mat_info] = yun_gardner_material(ME,Fy,fu,material_model);
fprintf('Material (Yun & Gardner, model %d): fy=%g  fu=%g MPa  eps_sh=%.4f  eps_u=%.4f  Esh=%.0f MPa  |  %d points\n', ...
    material_model,Fy,fu,mat_info.eps_sh,mat_info.eps_u,mat_info.Esh,numel(sigma_true_mat));

sigma_pl_upperflange=sigma_true_mat;
epsilon_pl_upperflange=epsilon_pl_mat;
sigma_pl_lowerflange=sigma_true_mat;
epsilon_pl_lowerflange=epsilon_pl_mat;
sigma_pl_web=sigma_true_mat;
epsilon_pl_web=epsilon_pl_mat;

f_1=size(sigma_pl_upperflange);
f_2=size(sigma_pl_lowerflange);
w_0=size(sigma_pl_web);

%% Element numbers in the plate
%nw=max(20,ceil((H-tf1-tf2-r1-r2)/meshsize));


if L>8*(H+B1+B2)
    nw=ceil(max(10,nw/(L/(H+B1+B2))));
end

if mod(nw,2)==0
else
    nw=nw+1;
end

nf1=ceil((B1-2*r1-tw)/2/(H-tf1-tf2-r1-r2)*nw);
nf2=ceil((B2-2*r2-tw)/2/(H-tf1-tf2-r1-r2)*nw);
nfr1=max(2,ceil((r1+tw/2)/(H-tf1-tf2-r1-r2)*nw));
nfr2=max(2,ceil((r2+tw/2)/(H-tf1-tf2-r1-r2)*nw));
nwd1=max(1,ceil(dcen1/(H-tf1-tf2-r1-r2)*nw));
nwd2=max(1,ceil(dcen2/(H-tf1-tf2-r1-r2)*nw));
nwr1=max(1,ceil((r1+tf1/2-dcen1)/(H-tf1-tf2-r1-r2)*nw));
nwr2=max(1,ceil((r2+tf2/2-dcen2)/(H-tf1-tf2-r1-r2)*nw));



%% Keynodes
node_1=1;
node_2=nwd1+1;
node_3=nwd1+nwr1+1;
node_4=nwd1+nwr1+nw+1;
node_5=nwd1+nwr1+nw+nwr2+1;
node_6=nwd1+nwr1+nw+nwr2+nwd2+1;
node_7=nwd1+nwr1+nw+nwr2+nwd2+2;
node_8=nwd1+nwr1+nw+nwr2+nwd2+nf1+2;
node_9=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1;
node_10=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+2;
node_11=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+1;
node_12=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+1;
node_13=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+2;
node_14=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+2;
node_15=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1;
node_16=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+2;
node_17=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+nfr2+1;
node_18=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+nfr2+nf2+1;

%% strainght-line model
node=zeros(node_18,8);
%nodes in the web - part 1
for i=1:(nwd1+1)
    node(i,1)=i;
    node(i,2)=0;
    node(i,3)=h-dcen1/nwd1*(i-1);
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the web - part 2
for i=(nwd1+2):(nwd1+nwr1+1)
    node(i,1)=i;
    node(i,2)=0;
    node(i,3)=h-dcen1-(r1+tf1/2-dcen1)/nwr1*(i-(nwd1+1));
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the web - part 3
for i=(nwd1+nwr1+2):(nwd1+nwr1+nw+1)
    node(i,1)=i;
    node(i,2)=0;
    node(i,3)=h-r1-tf1/2-(h-tf1/2-tf2/2-r1-r2)/nw*(i-(nwd1+nwr1+1));
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the web - part 4
for i=(nwd1+nwr1+nw+2):(nwd1+nwr1+nw+nwr2+1)
    node(i,1)=i;
    node(i,2)=0;
    node(i,3)=r2+tf2/2-(r2+tf2/2-dcen2)/nwr2*(i-(nwd1+nwr1+nw+1));
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the web - part 5
for i=(nwd1+nwr1+nw+nwr2+2):(nwd1+nwr1+nw+nwr2+nwd2+1)
    node(i,1)=i;
    node(i,2)=0;
    node(i,3)=dcen2-dcen2/nwd2*(i-(nwd1+nwr1+nw+nwr2+1));
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the upper flange - part 6 
for i=(nwd1+nwr1+nw+nwr2+nwd2+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1+1)
    node(i,1)=i;
    node(i,2)=-B1/2+(B1/2-r1-tw/2)/nf1*(i-(nwd1+nwr1+nw+nwr2+nwd2+2));
    node(i,3)=h;
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the upper flange - part 7 (cut the last node)
for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1)
    node(i,1)=i;
    node(i,2)=-r1-tw/2+(r1+tw/2)/nfr1*(i-(nwd1+nwr1+nw+nwr2+nwd2+nf1+2));
    node(i,3)=h;
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the upper flange - part 8 (cut the first node)
for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+1)
    node(i,1)=i;
    node(i,2)=(r1+tw/2)/nfr1*(i-(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1));
    node(i,3)=h;
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the upper flange - part 9
for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+nf1+1)
    node(i,1)=i;
    node(i,2)=tw/2+r1+(B1/2-r1-tw/2)/nf1*(i-(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+1));
    node(i,3)=h;
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the lower flange - part 10
for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+nf1+nf2+1)
    node(i,1)=i;
    node(i,2)=-B2/2+(B2/2-r2-tw/2)/nf2*(i-(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+nf1+2));
    node(i,3)=0;
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the lower flange - part 11
for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+nf1+nf2+nfr2+1)
    node(i,1)=i;
    node(i,2)=-r2-tw/2+(r2+tw/2)/nfr2*(i-(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+2));
    node(i,3)=0;
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the lower flange - part 12
for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+nf1+nf2+nfr2+nfr2+1)
    node(i,1)=i;
    node(i,2)=(r2+tw/2)/nfr2*(i-(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1));
    node(i,3)=0;
    node(i,4:8)=[1 1 1 1 0];
end

%nodes in the lower flange - part 13
for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+nfr2+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+nf1+nf2+nfr2+nfr2+nf2+1)
    node(i,1)=i;
    node(i,2)=tw/2+r2+(B2/2-r2-tw/2)/nf2*(i-(nwd1+nwr1+nw+nwr2+nwd2+nf1++nfr1+nfr1+nf1+nf2+nfr2+nfr2+1));
    node(i,3)=0;
    node(i,4:8)=[1 1 1 1 0];
end

%% element connectivity
elem=zeros(node_18-1,5);
for i=1:(nwd1+nwr1+nw+nwr2+nwd2)   %for part 1 to 5 
    elem(i,1)=i;
    elem(i,2:3)=[i i+1];
    elem(i,4)=tw;
    elem(i,5)=100;
end

for i=(nwd1+nwr1+nw+nwr2+nwd2+1):(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1-1) %for part 6 and 7
    elem(i,1)=i;
    elem(i,2:3)=[i+1 i+2];
    elem(i,4)=tf1;
    elem(i,5)=200;
end

elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1,1) = nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1,2:3) = [nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1 1];
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1,4) = tf1;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1,5) = 200;

elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1,1)=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1,2:3)=[1 nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+2];
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1,4)=tf1;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+1,5)=200;

for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1) %for part 8 and 9
    elem(i,1)=i;
    elem(i,2:3)=[i i+1];
    elem(i,4)=tf1;
    elem(i,5)=200;
end

for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+1):(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2-1) %for part 10 and 11
    elem(i,1)=i;
    elem(i,2:3)=[i+1 i+2];
    elem(i,4)=tf2;
    elem(i,5)=300;
end

elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2,1)=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2,2:3)=[nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1 nwd1+nwr1+nw+nwr2+nwd2+1];
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2,4)=tf2;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2,5)=300;

elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1,1)=nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1,2:3)=[nwd1+nwr1+nw+nwr2+nwd2+1 nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+2];
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1,4)=tf2;
elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1,5)=300;

for i=(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+2):(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+nfr2+nf2)  %for part 12 and 13
    elem(i,1)=i;
    elem(i,2:3)=[i i+1];
    elem(i,4)=tf2;
    elem(i,5)=300;
end



%% Maximum element length in the cross-section
Mw=0;%Maximum element length
for i=1:length(elem(1:(nwd1+nwr1+nw+nwr2+nwd2),1))
    hh1=abs(sqrt((node(elem(i,2),2)-node(elem(i,3),2))^2+(node(elem(i,2),3)-node(elem(i,3),3))^2));
    if hh1>Mw
        Mw=hh1;
    end
end

for i=1:length(elem((nwd1+nwr1+nw+nwr2+nwd2+1):(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1),1))
    hh1=abs(sqrt((node(elem(i,2),2)-node(elem(i,3),2))^2+(node(elem(i,2),3)-node(elem(i,3),3))^2));
    if hh1>Mw
        Mw=hh1;
    end
end

for i=1:length(elem((nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+1):(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2),1))
    hh1=abs(sqrt((node(elem(i,2),2)-node(elem(i,3),2))^2+(node(elem(i,2),3)-node(elem(i,3),3))^2));
    if hh1>Mw
        Mw=hh1;
    end
end

%% Section properties of the strip model (centroid, inertia, shear centre)
[A,xcg,zcg,Ixx,Izz,Zs] = section_props(node(:,2:3),elem(:,2:4));
parameters_section = [parameters_section; o, A, Ixx, Izz];


%% Renew the nodes and elements
% Add extra 2 nodes in the joints
%    node=[node;zeros(2,8)];
%    node(node_18+1,1)=node_18+1;
%    node(node_18+1,2:8)=node(node_1,2:8);
%    node(node_18+2,1)=node_18+2;
%    node(node_18+2,2:8)=node(node_6,2:8);
    
% New elements
%elem(node_10-2,3)=node_18+1;
%elem(node_10-1,2)=node_18+1;
%elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2,3)=node_18+2;
%elem(nwd1+nwr1+nw+nwr2+nwd2+nf1+nfr1+nfr1+nf1+nf2+nfr2+1,2)=node_18+2;

%% Element numbers and check the elements
Elm_section=(node_18-1);               %total number of elements in each section

nele_f=floor(L(1)/Mw);
if nele_f<2
    nele=1;
else
    nele=floor(nele_f);
end


%% PRELIMINARIES
%Count FSM nodes and modes
nnodes=length(node(:,1));  %Number of FSM cross-section nodes

%Determine FE number of nodes and increment 

if mod(nele,2)==0
else
    nele=nele+1;
end
nL=nele+1;   %Number of FE nodes along the length

%Determine the node numbering increment along the length
if nnodes<5000
    FEsection_increment=10000; %so along the length the numbering goes up by 100's
else
    FEsection_increment=nnodes+1;
end
  
%% NODAL COORDINATES
%Build up the imperfect nodal coordiantes
%Begin with the undeformed geometry
shapex=zeros(nnodes,nL);
shapez=zeros(nnodes,nL);
shapey=zeros(nnodes,nL);
shapex_change=zeros(nnodes,nL);  
shapez_change=zeros(nnodes,nL);   
Theta=zeros(1,nL);
if analysis==3
    for i=1:nL    %i---towards the direction of y   
        shapex(:,i)=node(:,2);  
	    shapez(:,i)=node(:,3);
	    shapey(:,i)=ones(nnodes,1)*(i-1)/(nL-1)*L;    
        
%Local imperfection  
%nodes in the web - part 3
        for j=node_3:node_4  %j---for the plane of x-z
            shapex(j,i)=shapex(j,i)+magnitudeH*sin((i-1)*L/(nL-1)*pi()/periodicity)*sin(period_H/nw*(j-node_3)/period_H*pi());  %Local imperfection
        end
%nodes in the upper flange - part 6 
        for j=node_7:node_8
            shapez(j,i)=shapez(j,i)-magnitudeB1*sin((i-1)*L/(nL-1)*pi()/periodicity)*(1-sin(period_B1/2/nf1*(j-node_7)/(period_B1/2)*pi()/2));
        end
%nodes in the upper flange - part 9
        for j=node_11:node_12
            shapez(j,i)=shapez(j,i)+magnitudeB1*sin((i-1)*L/(nL-1)*pi()/periodicity)*(1-sin((period_B1/2-(period_B1/2)/nf1*(j-node_11))/(period_B1/2)*pi()/2));
        end
%nodes in the lower flange - part 10
        for j=node_13:node_14
            shapez(j,i)=shapez(j,i)+magnitudeB2*sin((i-1)*L/(nL-1)*pi()/periodicity)*(1-sin(period_B2/2/nf2*(j-node_13)/(period_B2/2)*pi()/2));
        end
%nodes in the lower flange - part 13
        for j=node_17:node_18
            shapez(j,i)=shapez(j,i)-magnitudeB2*sin((i-1)*L/(nL-1)*pi()/periodicity)*(1-sin((period_B2/2-(period_B2/2)/nf2*(j-node_17))/(period_B2/2)*pi()/2));
        end
    end

else
    for i=1:nL    %without imperfection if analysis==1 
        shapex(:,i)=node(:,2); 
	    shapez(:,i)=node(:,3);
	    shapey(:,i)=ones(nnodes,1)*(i-1)/(nL-1)*L;   
    end
end

%You can make a quick dirty plot of the nodal coordinates in the perturbed
%geometry if you want to see them. This was used in debugging.
%plot3(shapex,shapey,shapez)

%% Residual stress pattern  


referenceresidual= 235;
% referenceresidual= Fy;

% Choice of the residual stress pattern
residual_pattern = 3;      % 1 = Parabolic ; 2 = Triangular ; 3 = Lahiru (Dissanayake et al. 2026)
Lahiru_equilibrium = 1;    % Lahiru only - web centre stress: 1 = Eq.(9) with fillets (paper)
                           % 2 = Eq.(10) without fillets ; 3 = exact equilibrium of the FE model


residual=zeros(Elm_section,1);
location=zeros(Elm_section,1);

if residual_pattern==1 % Parabolic
    
    if H/(0.5*(B1+B2))<1.2
        a=5/3;
    else
        a=1;
    end
    
%nodes in the web - part 1, 2, 3-1
%Location
for i=node_1:node_2-1
    location(i)=dcen1/nwd1/2+dcen1/nwd1*(i-node_1);  %The residual stress is applided in the middle of each element, that's why location(1)=dcen1/nwd1/2. 
end
for i=node_2:node_3-1
    location(i)=dcen1+(r1+tf1/2-dcen1)/nwr1/2+(r1+tf1/2-dcen1)/nwr1*(i-node_2);
end
for i=node_3:1:node_3-1+nw/2
    location(i)=r1+tf1/2+(h/2-(r1+tf1/2))/(nw/2)/2+(h/2-(r1+tf1/2))/(nw/2)*(i-node_3);
end
%residual
for i=node_1:node_3-1+nw/2
%    residual(i)=referenceresidual/2-referenceresidual/(h/2)*location(i);  %triangular only
    residual(i)=a*referenceresidual*(9/10/h^2*( location(i)-location(node_3-1+nw/2) )^2-0.075); %parabolic only
end

%nodes in the web - part 3-2, 4, 5
%Location
for i=node_3+nw/2:1:node_4-1
    location(i)=(h/2-(r2+tf2/2))/(nw/2)/2+(h/2-(r2+tf2/2))/(nw/2)*(i-(node_3+nw/2));
end
for i=node_4:node_5-1
    location(i)=h/2-(r2+tf2/2)+((r2+tf2/2)-dcen2)/nwr2/2+((r2+tf2/2)-dcen2)/nwr2*(i-node_4);
end
for i=node_5:node_6-1
    location(i)=h/2-dcen2+dcen2/nwd2/2+dcen2/nwd2*(i-node_5);
end
%residual
for i=node_3+nw/2:node_6-1
%    residual(i)=-referenceresidual/2+referenceresidual/(h/2)*location(i); %triangular only
    residual(i)=a*referenceresidual*(9/10/h^2*location(i)*location(i)-0.075); %parabolic only
end

for i=node_1:node_3-1+nw/2
    residual(i)=residual(2*(node_3+nw/2)-i-1); %parabolic only
end

%nodes in the upper flange - part 6, 7
%Location
for i=node_6:node_8-2
    location(i)=(period_B1/2)/nf1/2+(period_B1/2)/nf1*(i-node_6);
end
for i=node_8-1:node_9-1
    location(i)=(period_B1/2)+(r1+tw/2)/nfr1/2+(r1+tw/2)/nfr1*(i-(node_8-1));
end
%residual
%residual(node_6)=-a*0.3*referenceresidual; %parabolic only


for i=node_6:node_9-1
%    residual(i-1)=-referenceresidual/2+referenceresidual/(B1/2)*location(i);%triangular only
    residual(i)=a*(-9/5/B1^2*(location(i)-B1/2)^2+0.15)*referenceresidual; %parabolic only
end


%nodes in the upper flange - part 8, 9
%Location
for i=node_9:node_11-1
    location(i)=(r1+tw/2)/nfr1/2+(r1+tw/2)/nfr1*(i-node_9);
end
for i=node_11:node_12-1
    location(i)=(r1+tw/2)+(period_B1/2)/nf1/2+(period_B1/2)/nf1*(i-node_11);
end
%residual
for i=node_9:node_12-1
%    residual(i)=referenceresidual/2-referenceresidual/(B1/2)*location(i); %triangular only
    residual(i)=a*referenceresidual*(-9/5/B1^2*(location(i))^2+0.15); %parabolic only
end

%nodes in the lower flange - part 10, 11
%Location
for i=node_12:node_14-2
    location(i)=(period_B2/2)/nf2/2+(period_B2/2)/nf2*(i-node_12);
end
for i=node_14-1:node_15-1
    location(i)=(period_B2/2)+(r2+tw/2)/nfr2/2+(r2+tw/2)/nfr2*(i-(node_14-1));
end
%residual

for i=node_12:node_15-1
%    residual(i-1)=-referenceresidual/2+referenceresidual/(B2/2)*location(i); %triangular only
    residual(i)=a*referenceresidual*(-9/5/B2^2*(location(i)-B2/2 )^2+0.15);%parabolic only
end


%nodes in the lower flange - part 12, 13
%Location
for i=node_15:node_17-1
    location(i)=(r2+tw/2)/nfr2/2+(r2+tw/2)/nfr2*(i-node_15);
end
for i=node_17:node_18-1
    location(i)=(r2+tw/2)+(period_B2/2)/nf2/2+(period_B2/2)/nf2*(i-node_17);   
end
%residual
for i=node_15:node_18-1
%    residual(i)=referenceresidual/2-referenceresidual/(B2/2)*location(i); %triangular only
    residual(i)=a*referenceresidual*(-9/5/B2^2*(location(i))^2+0.15); %parabolic only
end

end

if residual_pattern==2  %Triangular
%nodes in the web - part 1, 2, 3-1
%Location
for i=node_1:node_2-1
    location(i)=dcen1/nwd1/2+dcen1/nwd1*(i-node_1);  %The residual stress is applided in the middle of each element, that's why location(1)=dcen1/nwd1/2. 
end
for i=node_2:node_3-1
    location(i)=dcen1+(r1+tf1/2-dcen1)/nwr1/2+(r1+tf1/2-dcen1)/nwr1*(i-node_2);
end
for i=node_3:1:node_3-1+nw/2
    location(i)=r1+tf1/2+(h/2-(r1+tf1/2))/(nw/2)/2+(h/2-(r1+tf1/2))/(nw/2)*(i-node_3);
end
%residual
for i=node_1:node_3-1+nw/2
    residual(i)=referenceresidual/2-referenceresidual/(h/2)*location(i);  %triangular only
%    residual(i)=5/3*referenceresidual*(9/10/h^2*( location(i)-location(node_3-1+nw/2) )^2-0.075); %parabolic only
end

%nodes in the web - part 3-2, 4, 5
%Location
for i=node_3+nw/2:1:node_4-1
    location(i)=(h/2-(r2+tf2/2))/(nw/2)/2+(h/2-(r2+tf2/2))/(nw/2)*(i-(node_3+nw/2));
end
for i=node_4:node_5-1
    location(i)=h/2-(r2+tf2/2)+((r2+tf2/2)-dcen2)/nwr2/2+((r2+tf2/2)-dcen2)/nwr2*(i-node_4);
end
for i=node_5:node_6-1
    location(i)=h/2-dcen2+dcen2/nwd2/2+dcen2/nwd2*(i-node_5);
end
%residual
for i=node_3+nw/2:node_6-1
    residual(i)=-referenceresidual/2+referenceresidual/(h/2)*location(i); %triangular only
%    residual(i)=5/3*referenceresidual*(9/10/h^2*location(i)*location(i)-0.075); %parabolic only
end

%for i=node_1:node_3-1+nw/2
%    residual(i)=residual(2*(node_3+nw/2)-i-1); %parabolic only
%end

%nodes in the upper flange - part 6, 7
%Location
for i=node_7:node_8-1
    location(i)=(period_B1/2)/nf1/2+(period_B1/2)/nf1*(i-node_7);
end
for i=node_8:node_9-1
    location(i)=(period_B1/2)+(r1+tw/2)/nfr1/2+(r1+tw/2)/nfr1*(i-node_8);
end
%residual
%residual(node_6)=-5/3*0.3*referenceresidual; %parabolic only

for i=node_7:node_9-1
    residual(i-1)=-referenceresidual/2+referenceresidual/(B1/2)*location(i);%triangular only
%    residual(i)=5/3*(-9/5/B1^2*(location(i)-B1/2)^2+0.15)*referenceresidual; %parabolic only
end

residual(node_9-1)=residual(node_9-2)+referenceresidual/(B1/2)*(r1+tw/2)/nfr1;%triangular only
%residual(node_9-1)=5/3*(-9/5/B1^2*( (r1+tw/2)/nfr1 )^2+0.15)*referenceresidual; %parabolic only
residual(node_9)=residual(node_9-1);

%nodes in the upper flange - part 8, 9
%Location
for i=node_10:node_11-1
    location(i)=(r1+tw/2)/nfr1/2+(r1+tw/2)/nfr1*(i-node_10+1);
end
for i=node_11:node_12-1
    location(i)=(r1+tw/2)+(period_B1/2)/nf1/2+(period_B1/2)/nf1*(i-node_11);
end
%residual
for i=node_10:node_12-1
    residual(i)=referenceresidual/2-referenceresidual/(B1/2)*location(i); %triangular only
%    residual(i)=5/3*referenceresidual*(-9/5/B1^2*(location(i)+(r1+tw/2)/nfr1)^2+0.15); %parabolic only
end
%residual(node_12-1)=-5/3*0.3*referenceresidual; %parabolic only

%for i=node_7:node_9-1%parabolic only
%    residual(i)=residual(2*node_9-i-1);%parabolic only
%end

%nodes in the lower flange - part 10, 11
%Location
for i=node_13:node_14-1
    location(i)=(period_B2/2)/nf2/2+(period_B2/2)/nf2*(i-node_13);
end
for i=node_14:node_15-1
    location(i)=(period_B2/2)+(r2+tw/2)/nfr2/2+(r2+tw/2)/nfr2*(i-node_14);
end
%residual
%residual(node_12)=-5/3*0.3*referenceresidual; %parabolic
for i=node_13:node_15-1
    residual(i-1)=-referenceresidual/2+referenceresidual/(B2/2)*location(i); %triangular only
%    residual(i)=5/3*referenceresidual*(-9/5/B2^2*( location(i)-B2/2 )^2+0.15);%parabolic only
end

residual(node_15-1)=residual(node_15-2)+referenceresidual/(B2/2)*(r2+tw/2)/nfr2; %triangular only
%residual(node_15-1)=5/3*(-9/5/B2^2*( (r2+tw/2)/nfr2 )^2+0.15)*referenceresidual; %parabolic only
residual(node_15)=residual(node_15-1);

%nodes in the lower flange - part 12, 13
%Location
for i=node_16:node_17-1
    location(i)=(r2+tw/2)/nfr2/2+(r2+tw/2)/nfr2*(i-node_16+1);
end
for i=node_17:node_18-1
    location(i)=(r2+tw/2)+(period_B2/2)/nf2/2+(period_B2/2)/nf2*(i-node_17);   
end
%residual
for i=node_16:node_18-1
    residual(i)=referenceresidual/2-referenceresidual/(B2/2)*location(i); %triangular only
%    residual(i)=5/3*referenceresidual*(-9/5/B2^2*(location(i)+(r2+tw/2)/nfr2)^2+0.15); %parabolic only
end

end


if residual_pattern==3  % Lahiru: Dissanayake, Yang, Walport & Gardner (2026)
% "Residual stress model for hot-rolled steel I-sections",
% Engineering Structures 366, 123378. https://doi.org/10.1016/j.engstruct.2026.123378
% - Flanges: bi-linear distribution, Eq.(5): sigma = 2(sigma_ft - sigma_fw)|x| + sigma_fw
% - Web    : parabolic distribution,  Eq.(6): sigma = 4(sigma_fw - sigma_wc)x^2 + sigma_wc
% - sigma_ft and sigma_fw from h/b (Table 7), sigma_wc from self-equilibrium (Table 8)
% - x is normalised by the flange width b (flanges) or the web depth hw = h-2tf (web);
%   x = 0 at the web centre, |x| = 0.5 at the flange tip / flange-web intersection
% - Amplitudes in MPa, independent of fy. Tension > 0, compression < 0.
% - Calibrated for tf <= 40 mm. For unequal flanges, mean values of B, tf and r are used.

    % Real section properties (actual dimensions, not mid-surface)
    b_Lah  = (B1+B2)/2;                         % flange width b
    hb_Lah = H/b_Lah;                           % aspect ratio h/b
    r_Lah  = (r1+r2)/2;                         % root radius r
    hw_Lah = H-tf1-tf2;                         % web depth hw = h - 2tf
    Af_Lah = (B1*tf1+B2*tf2)/2;                 % area of one flange Af
    Aw_Lah = hw_Lah*tw;                         % area of the web Aw = hw*tw
    Ar_Lah = (4-pi)*r_Lah^2;                    % area of the 4 fillets Ar = (4-pi)r^2
    zc_Lah = hw_Lah/2-(10-3*pi)/(3*(4-pi))*r_Lah; % fillet centroid from web centre, Eq.(7)

    % Table 7: stresses at the flange tip and at the flange-web intersection (MPa)
    if hb_Lah<=1.2
        sig_ft_Lah = -70;
        sig_fw_Lah = 80;
    elseif hb_Lah<=1.8
        sig_ft_Lah = 200*hb_Lah/3-150;
        sig_fw_Lah = 250*hb_Lah/3-20;
    else
        sig_ft_Lah = -30;
        sig_fw_Lah = 130;
    end

    if max(tf1,tf2)>40
        warning('Lahiru residual stress model is calibrated for tf <= 40 mm (tf = %.1f mm).',max(tf1,tf2));
    end

    % Element mid-points, lengths and areas of the FE strip model
    xmid_Lah = (node(elem(:,2),2)+node(elem(:,3),2))/2;
    zmid_Lah = (node(elem(:,2),3)+node(elem(:,3),3))/2;
    Ael_Lah  = sqrt((node(elem(:,2),2)-node(elem(:,3),2)).^2+(node(elem(:,2),3)-node(elem(:,3),3)).^2).*elem(:,4);
    iweb_Lah = (node_1:node_6-1)';              % web elements (parts 1 to 5)
    iuf_Lah  = (node_6:node_12-1)';             % upper flange elements (parts 6 to 9)
    ilf_Lah  = (node_12:node_18-1)';            % lower flange elements (parts 10 to 13)

    % Normalised positions (|x| limited to 0.5: the web elements located inside the
    % flange thickness take the flange-web intersection stress)
    zweb_Lah = (tf2/2+h-tf1/2)/2;               % mid-depth of the clear web (model coordinates)
    xw_Lah   = min(abs(zmid_Lah(iweb_Lah)-zweb_Lah)/hw_Lah,0.5);
    xuf_Lah  = min(abs(xmid_Lah(iuf_Lah))/B1,0.5);
    xlf_Lah  = min(abs(xmid_Lah(ilf_Lah))/B2,0.5);

    % Flanges, Eq.(5)
    sig_uf_Lah = 2*(sig_ft_Lah-sig_fw_Lah)*xuf_Lah+sig_fw_Lah;
    sig_lf_Lah = 2*(sig_ft_Lah-sig_fw_Lah)*xlf_Lah+sig_fw_Lah;

    % Web centre stress sigma_wc (Table 8)
    if Lahiru_equilibrium==1      % with fillets, Eq.(9)
        sig_wc_Lah = -( Af_Lah*(sig_fw_Lah+sig_ft_Lah) + sig_fw_Lah*(Aw_Lah/3+Ar_Lah*(2*zc_Lah/hw_Lah)^2) ) ...
                     /( 2*Aw_Lah/3 + Ar_Lah*(1-(2*zc_Lah/hw_Lah)^2) );
    elseif Lahiru_equilibrium==2  % without fillets, Eq.(10)
        sig_wc_Lah = -(3*Af_Lah*(sig_fw_Lah+sig_ft_Lah)+sig_fw_Lah*Aw_Lah)/(2*Aw_Lah);
    else                          % exact self-equilibrium of the FE strip model
        F_known_Lah = sum(sig_uf_Lah.*Ael_Lah(iuf_Lah)) + sum(sig_lf_Lah.*Ael_Lah(ilf_Lah)) ...
                      + sum(sig_fw_Lah*4*xw_Lah.^2.*Ael_Lah(iweb_Lah));
        sig_wc_Lah = -F_known_Lah/sum((1-4*xw_Lah.^2).*Ael_Lah(iweb_Lah));
    end

    % Web, Eq.(6)
    residual(iweb_Lah) = 4*(sig_fw_Lah-sig_wc_Lah)*xw_Lah.^2+sig_wc_Lah;
    residual(iuf_Lah)  = sig_uf_Lah;
    residual(ilf_Lah)  = sig_lf_Lah;

    % Check of the self-equilibrium in the FE model
    Fnet_Lah = sum(residual.*Ael_Lah);
    fprintf('Lahiru RS: h/b=%.3f  sig_ft=%.1f  sig_fw=%.1f  sig_wc=%.1f MPa  |  net force in FE model = %.2f kN (%.2f%% of A*sig_fw)\n', ...
        hb_Lah,sig_ft_Lah,sig_fw_Lah,sig_wc_Lah,Fnet_Lah/1000,100*Fnet_Lah/(sum(Ael_Lah)*sig_fw_Lah));
end

%% NODAL COORDINATES IN FE FORM FOR ABAQUS.
%FEnode=[node# x y z] y is along the length
FEnode=zeros(nnodes*nL,4);
for i=1:nL
    FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,1)=node(:,1)+FEsection_increment*(i-1);
    %x in finite elements coordinate system
    FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,2)=shapex(:,i);%shapey(:,i);original
    %y in finite elements coordinate system
    FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,3)=shapey(:,i);%shapex(:,i);original
    %z in finite elements coordinate system
    FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,4)=shapez(:,i);
end


FEnode_ref_1 = FEnode(end, 1)+1;
FEnode_ref_2 = FEnode(end, 1)+2;

% % % % 
kk=0;
FEnode_centroid(1,:)=FEnode(1,:);
for i=2:node_6
    if abs(FEnode(i,4)-zcg)<abs(FEnode_centroid(1,4)-zcg)
        FEnode_centroid(1,:)=FEnode(i,:);
        FEnode_centroid(2,:)=FEnode(i+(nL-1)*nnodes,:);
        FEnode_centroid(3,:)=FEnode(i+(round(nL/2)-1)*nnodes,:);
        kk=i;
    end
end

Original_node_Centroid=FEnode(kk,4);
for j=1:nL
    FEnode(kk+(j-1)*nnodes,4)=FEnode(kk+(j-1)*nnodes,4)-(Original_node_Centroid-zcg);    
end

FEnode_centroid(1,:)=FEnode(kk,:);
FEnode_centroid(2,:)=FEnode(kk+(nL-1)*nnodes,:);
FEnode_centroid(3,:)=FEnode(kk+(round(nL/2)-1)*nnodes,:);


% % % 
kk=0;
FEnode_shear(1,:)=FEnode(1,:);   
for i=2:nwd1+nwr1+nw+nwr2+nwd2+1
    if abs(FEnode(i,4)-Zs)<abs(FEnode_shear(1,4)-Zs)
        FEnode_shear(1,:)=FEnode(i,:);
        FEnode_shear(2,:)=FEnode(i+(nL-1)*nnodes,:);
        kk=i;
    end
end

Original_node_ShearCentre=FEnode(kk,4);
for j=1:nL
    FEnode(kk+(j-1)*nnodes,4)=FEnode(kk+(j-1)*nnodes,4)-(Original_node_ShearCentre-Zs);   
end

FEnode_shear(1,:)=FEnode(kk,:);
FEnode_shear(2,:)=FEnode(kk+(nL-1)*nnodes,:);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if B1>=B2
    masternode_1=0;
    Slavenode(1,:)=FEnode(1,:);   
    for i=node_7:node_9
        if abs(FEnode(i,2)-FEnode(node_13,2))<abs(Slavenode(1,2)-FEnode(node_13,2))
            Slavenode(1,:)=FEnode(i,:);
            Slavenode(2,:)=FEnode(i+(nL-1)*nnodes,:);
            masternode_1=i;
        end
    end
    masternode_2=node_7+node_12-masternode_1;   
    
    Original_masternode_1=FEnode(masternode_1,2);
    Original_masternode_2=FEnode(masternode_2,2);
    for j=1:nL
        FEnode(masternode_1+(j-1)*nnodes,2)=FEnode(masternode_1+(j-1)*nnodes,2)-(Original_masternode_1-FEnode(node_13,2));  
        FEnode(masternode_2+(j-1)*nnodes,2)=FEnode(masternode_2+(j-1)*nnodes,2)-(Original_masternode_2-FEnode(node_18,2));      
    end
    
    masternode_3=node_13;
    masternode_4=node_18;
else
    masternode_3=0;
    Slavenode(1,:)=FEnode(1,:);   
    for i=node_13:node_15
        if abs(FEnode(i,2)-FEnode(node_7,2))<abs(Slavenode(1,2)-FEnode(node_7,2))
            Slavenode(1,:)=FEnode(i,:);
            Slavenode(2,:)=FEnode(i+(nL-1)*nnodes,:);
            masternode_3=i;
        end
    end
    masternode_4=node_13+node_18-masternode_3;
    
    Original_masternode_3=FEnode(masternode_3,2);
    Original_masternode_4=FEnode(masternode_4,2);    
    for j=1:nL
        FEnode(masternode_3+(j-1)*nnodes,2)=FEnode(node_7,2)-(Original_masternode_3-FEnode(masternode_3+(j-1)*nnodes,2));  
        FEnode(masternode_4+(j-1)*nnodes,2)=FEnode(node_12,2)-(Original_masternode_4-FEnode(masternode_4+(j-1)*nnodes,2));      
    end
    
    masternode_1=node_7;
    masternode_2=node_12;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if analysis==3
    for i=1:nL
%Torsional imperfection
        % Theta(1,i)=torsionalampli*sin((i-1)/(nL-1)*pi());             
        % shapex_change(:,i)=FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,2);  
        % shapez_change(:,i)=FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,4);                    
        % FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,2)=(shapex_change(:,i)- Xs)*cos(Theta(1,i))-(shapez_change(:,i)-Zs)*sin(Theta(1,i))+ Xs;
        % FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,4)=(shapex_change(:,i)- Xs)*sin(Theta(1,i))+(shapez_change(:,i)-Zs)*cos(Theta(1,i))+ Zs;
%Global imperfection    
        % FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,2)=FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,2)-sin(((i-1)/(nL-1))*pi())*miglobalampli;  
        FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,4)=FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,4)-sin(((i-1)/(nL-1))*pi())*mjglobalampli;     
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i=1:nL
    FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,4)=FEnode((i-1)*nnodes+1:(i-1)*nnodes+nnodes,4)-zcg;
end

FEyznode=zeros(nnodes*nL,1);
for i=1:nnodes*nL
FEnode(i,2)=FEnode(i,2);
FEyznode=FEnode(i,3);
FEnode(i,3)=FEnode(i,4);
FEnode(i,4)=FEyznode;
end

%% Element definition for ABAQUS 

if strcmp(elemtype,'S4') || strcmp(elemtype, 'S4R')
    %For S4, S4R
    %Element Connectivity
    %ABAQUS S4 or S4R for example
    %       face3
    %      4----3
    %face4 |    |face2
    %      1----2
    %      face1
    %
  
    k=1; %counter for strip, i.e., strip along the length
    elemnum=1;

FEelem=zeros((nL-1),5,length(elem(:,1)));
    for i=1:1:length(elem(:,1))
        for j=1:(nL-1)
            n1=elem(i,2);
            n2=elem(i,3);
            n3=elem(i,3) + FEsection_increment;
            n4=elem(i,2) + FEsection_increment;
            nnum=[n1 n2 n3 n4]+(j-1)*FEsection_increment;
            enum= elemnum;
            if strcmp(elemtype,'S4') || strcmp(elemtype, 'S4R')
                FEelem(j,:,k)=[enum nnum];
            end
            elemnum=elemnum+1;
        end
        k=k+1;
    end

    %ELEMENT THICKNESS AND MATERIAL NUMBER
    k=1;
    for i=1:1:length(elem(:,1))
        t(k)=elem(i,4);
        matnum(k)=elem(i,5); %elastic material
        k=k+1;
    end
end
%End of element definition

%%%%%%%%%%%%  Beam h_web %%%%%%%%%%%%
Ffy = Fy*10;
c_w = H-2*tf1;
t_web_class1 = c_w/(33*(235/Ffy)^0.5);
I_web = (10*t_web_class1^3)/(12*(1-0.3^2));
h_web = (12*I_web)^0.33;

%%%%%%%%%%%%  Beam h_flange %%%%%%%%%%%%
c_f = B1/2;
t_flange_class1 = (0.7*c_f)/(9*(235/Ffy)^0.5);
I_flange = (10*t_flange_class1^3)/(12*(1-0.3^2));
h_flange = (12*I_flange)^0.33;


%%%%%%%%%%%%  Beam element web %%%%%%%%%%%%
% % 
total_elems_web = (nL-3) * (node_6 - 1); % nL-1
FEelem_Beam_web = zeros(total_elems_web,3);

idx = 1;  % indice MATLAB pour remplir la matrice

for i = 1:node_6 - 1
    for j = 2:(nL-1)
        n1 = elem(i,2);
        n2 = elem(i,3);
        nnum = [n1 n2] + (j-1)*FEsection_increment;

        % Remplissage : idx pour la matrice, elemnum pour le numéro réel
        FEelem_Beam_web(idx,:) = [elemnum nnum];

        % Incréments
        elemnum = elemnum + 1;  % numéro réel pour Abaqus
        idx = idx + 1;           % ligne suivante dans la matrice
    end
end

%%%%%%%%%%%%  Beam element flange %%%%%%%%%%%%
% % % 
total_elems_flange = (nL-3) * (size(elem,1)-(node_6 - 1));
FEelem_Beam_flange = zeros(total_elems_flange,3);

idx = 1;  % indice MATLAB pour remplir la matrice

for i = node_6:1:size(elem,1)
    for j = 2:(nL-1)
        n1 = elem(i,2);
        n2 = elem(i,3);
        nnum = [n1 n2] + (j-1)*FEsection_increment;

        % Remplissage : idx pour la matrice, elemnum pour le numéro réel
        FEelem_Beam_flange(idx,:) = [elemnum nnum];

        % Incréments
        elemnum = elemnum + 1;  % numéro réel pour Abaqus
        idx = idx + 1;           % ligne suivante dans la matrice
    end
end




%% MATERIAL DEFINITION (ELASTIC ONLY)
for i=1:length(prop(:,1))
    mat(i,:)=[prop(i,1) prop(i,2) prop(i,4)];
end

%% BOUNDARY CONDITIONS
end1=[1:1:nnodes];
end2=end1 + (nL-1)*FEsection_increment;
middle=FEnode_centroid(1,1) + (nL-1)/2*FEsection_increment;



web_nodes1=[1:node_6];
upperflange_nodes1=[node_7:node_12];
lowerflange_nodes1=[node_13:node_18];

web_nodes2=web_nodes1+(nL-1)*FEsection_increment;
upperflange_nodes2=upperflange_nodes1+(nL-1)*FEsection_increment;
lowerflange_nodes2=lowerflange_nodes1+(nL-1)*FEsection_increment;
masternodes_1=[masternode_1 masternode_2 masternode_3 masternode_4];
masternodes_2=[masternode_1+(nL-1)*FEsection_increment masternode_2+(nL-1)*FEsection_increment masternode_3+(nL-1)*FEsection_increment masternode_4+(nL-1)*FEsection_increment];

% lateral support
step = 10000;
V = 1:step:(floor((max(FEnode(:,1))-1)/step)*step + 1);
Set_nodes_BC = V(2:end-1);

% valeur de départ
V2 = node_6:step:(floor((max(FEnode(:,1))-1)/step)*step + 1);
Set_nodes_BC2 = V2(2:end-1);

%% Linear Constrains


%% Generate Filename file
    fid = fopen(strcat(Path2,'Filename.dat'),'at');
    if analysis==1&&caculation_number==1
        if Loading==1
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['LBA']);   
            fprintf(fid,'%s \t',['N']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);      
        elseif Loading==2
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['LBA']);   
            fprintf(fid,'%s \t',['My']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);  
        elseif Loading==3
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['LBA']);   
            fprintf(fid,'%s \t',['Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]); 
        elseif Loading==4
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['LBA']);   
            fprintf(fid,'%s \t',['N+My']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]); 
         elseif Loading==5
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['LBA']);   
            fprintf(fid,'%s \t',['N+Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]); 
         elseif Loading==6
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['LBA']);   
            fprintf(fid,'%s \t',['My+Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);
         elseif Loading==7
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['LBA']);   
            fprintf(fid,'%s \t',['N+My+Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);
        end
    elseif analysis==2||analysis==3
        if Loading==1
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['GMNIA']);   
            fprintf(fid,'%s \t',['N']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);              
        elseif Loading==2
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['GMNIA']);   
            fprintf(fid,'%s \t',['My']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);               
        elseif Loading==3
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['GMNIA']);   
            fprintf(fid,'%s \t',['Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);   
        elseif Loading==4
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['GMNIA']);   
            fprintf(fid,'%s \t',['N+My']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]); 
        elseif Loading==5
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['GMNIA']);   
            fprintf(fid,'%s \t',['N+Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);
        elseif Loading==6
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['GMNIA']);   
            fprintf(fid,'%s \t',['My+Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]); 
        elseif Loading==7
            fprintf(fid,'%s \t',[headname '__' num2str(Number)]);   
            fprintf(fid,'%s \t',['GMNIA']);   
            fprintf(fid,'%s \t',['N+My+Mz']);   
            fprintf(fid,'%s \n',[num2str(H-tf1/2-tf2/2)]);             
        end
    end
     fclose(fid);   
     
%% Generate Batch for inp and python file 
    fid = fopen(strcat(Path2,'Batch for inp and py.bat'),'at');
    % fprintf(fid,'%s \n',['cmd/c abaqus job=' headname '__' num2str(Number) '  interactive']);   
    fprintf(fid,'%s \n',['cmd/c abaqus job=' headname '__' num2str(Number) ' cpus=20  interactive']);   
    fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.prt']);
    fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.res']);
    fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.sim']);
    % fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.sta']);
    fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.stt']);
    % fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.msg']);
    fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.mdl']);
    fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.com']);

    if analysis==2||analysis==3
        %fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.dat']);
        %fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.txt']);
        fprintf(fid,'%s \n',['cmd/c abaqus cae noGUI=' headname '__' num2str(Number) '.py']);
        if ~keep_odb
            fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.odb']);
        end
    end
   
    % fprintf(fid,'%s \n',['del ' headname '__' num2str(Number) '.dat']);  

    fprintf(fid,'%s \r\n',[ ]);     
    fprintf(fid,'%s \r\n',[ ]);  
    fclose(fid);
    
%% Generate Python file for extracting the data from ABAQUS 
if analysis==2||analysis==3
    fid = fopen(strcat(Path2,[headname '__' num2str(Number)],'.py'),'w+');
    fprintf(fid,'%s \r\n','# -* - coding:UTF-8 -*-loding diformation data');
    fprintf(fid,'%s \r\n','import odbAccess');
    fprintf(fid,'%s \r\n','from abaqus import *');
    fprintf(fid,'%s \r\n','from abaqusConstants import *');
    fprintf(fid,'%s \r\n\n','import visualization');
    fprintf(fid,'%s \r\n',[ ]);  
    fprintf(fid,'%s \r\n',['n=' num2str(Number)]);  
    fprintf(fid,'%s \r\n',['vp = session.openOdb(name=''' headname '__''+str(' 'n' ')+''.odb'')']);
    fprintf(fid,'%s \r\n\n',['session.viewports[''Viewport: 1''].setValues(displayedObject=vp)']);
    fprintf(fid,'%s \r\n',[ ]);  
    fprintf(fid,'%s \r\n',['odb = session.odbs[''' headname '__''+str(' 'n' ')+''.odb'']']);
    fprintf(fid,'%s \r\n',['odbName=session.viewports[session.currentViewportName].odbDisplay.name']);
    fprintf(fid,'%s \r\n\n',['session.odbData[odbName].setValues(activeFrames=((''STEP1'', (''0:-1'', )), ))']);
    fprintf(fid,'%s \r\n',[ ]);

    fprintf(fid,'%s \r\n',[ ]);     
    fprintf(fid,'%s \r\n',['session.XYDataFromHistory(name=''LPF'', odb=odb, outputVariableName=''Load proportionality factor: LPF for Whole Model'', steps=(''STEP1'', ), )']);  


if Loading==1
    % fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''U'', NODAL, ((COMPONENT, ''U3''), )), ), nodeSets=(''PART-1-1.END1'', ))']);
    % fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''U:U3 PI: PART-1-1 N: ' num2str(FEnode_centroid(1,1)) ''',toName=''U''+str(' 'n' ')+''__' num2str(Number) ''')']);
    % lateral deflection at mid-length in the direction of the global imperfection (major axis -> U2)
    if mjglobalampli==0 && miglobalampli~=0, Ucomp='U1'; else, Ucomp='U2'; end
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''U'', NODAL, ((COMPONENT, ''' Ucomp '''), )), ), nodeLabels=((''PART-1-1'', (''' num2str(FEnode_centroid(3,1)) ''' ,)), ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''U:' Ucomp ' PI: PART-1-1 N: ' num2str(FEnode_centroid(3,1)) ''', toName=''U_''+str(' 'n' ')+''__' num2str(Number) ''')']);
    fprintf(fid,'%s \r\n',[ ]);
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''RF'', NODAL, ((COMPONENT, ''RF3''), )), ), nodeSets=(''PART-1-1.RP2'', ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''RF:RF3 PI: PART-1-1 N: ' num2str(FEnode_ref_2) ''', toName=''RF_''+str(' 'n' ')+''__' num2str(Number) ''')']);

elseif Loading==2
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''UR'', NODAL, ((COMPONENT, ''UR1''), )), ), nodeSets=(''PART-1-1.END1'', ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''UR:UR1 PI: PART-1-1 N: ' num2str(FEnode_centroid(1,1)) ''',toName=''UR''+str(' 'n' ')+''__' num2str(Number) ''')']);    
elseif Loading==3
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''UR'', NODAL, ((COMPONENT, ''UR2''), )), ), nodeSets=(''PART-1-1.END1'', ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''UR:UR2 PI: PART-1-1 N: ' num2str(FEnode_centroid(1,1)) ''',toName=''UR''+str(' 'n' ')+''__' num2str(Number) ''')']);    
elseif Loading==4
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''U'', NODAL, ((COMPONENT, ''U3''), )), ), nodeSets=(''PART-1-1.END1'', ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''U:U3 PI: PART-1-1 N: ' num2str(FEnode_centroid(1,1)) ''',toName=''U''+str(' 'n' ')+''__' num2str(Number) ''')']);
elseif Loading==5
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''U'', NODAL, ((COMPONENT, ''U3''), )), ), nodeSets=(''PART-1-1.END1'', ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''U:U3 PI: PART-1-1 N: ' num2str(FEnode_centroid(1,1)) ''',toName=''U''+str(' 'n' ')+''__' num2str(Number) ''')']);
elseif Loading==6
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''UR'', NODAL, ((COMPONENT, ''UR1''), )), ), nodeSets=(''PART-1-1.END1'', ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''UR:UR1 PI: PART-1-1 N: ' num2str(FEnode_centroid(1,1)) ''',toName=''UR''+str(' 'n' ')+''__' num2str(Number) ''')']);    
elseif Loading==7
    fprintf(fid,'%s \r\n',['session.xyDataListFromField(odb=odb, outputPosition=NODAL, variable=((''U'', NODAL, ((COMPONENT, ''U3''), )), ), nodeSets=(''PART-1-1.END1'', ))']);
    fprintf(fid,'%s \r\n',['session.xyDataObjects.changeKey(fromName=''U:U3 PI: PART-1-1 N: ' num2str(FEnode_centroid(1,1)) ''',toName=''U''+str(' 'n' ')+''__' num2str(Number) ''')']);
end
    fprintf(fid,'%s \r\n',[ ]);  
    fprintf(fid,'%s \r\n',['LPF = session.xyDataObjects[''LPF'']']);    
    % fprintf(fid,'%s \r\n',[ ]);    
    
if Loading==1
    % fprintf(fid,'%s \r\n',[ ]);  
    % fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''U''+str(' 'n' ')+''__' num2str(Number) ''']']);   
    fprintf(fid,'%s \r\n',[ ]);  
    fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''U_''+str(' 'n' ')+''__' num2str(Number) ''']']); 
    fprintf(fid,'%s \r\n',['y' num2str(1) ' = session.xyDataObjects[''RF_''+str(' 'n' ')+''__' num2str(Number) ''']']); 

elseif Loading==2
    fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''UR''+str(' 'n' ')+''__' num2str(Number) ''']']); 
elseif Loading==3
    fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''UR''+str(' 'n' ')+''__' num2str(Number) ''']']);
elseif Loading==4
    fprintf(fid,'%s \r\n',[ ]);  
    fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''U''+str(' 'n' ')+''__' num2str(Number) ''']']);   
elseif Loading==5
    fprintf(fid,'%s \r\n',[ ]);  
    fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''U''+str(' 'n' ')+''__' num2str(Number) ''']']);   
elseif Loading==6  
    fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''UR''+str(' 'n' ')+''__' num2str(Number) ''']']); 
elseif Loading==7
    fprintf(fid,'%s \r\n',[ ]);  
    fprintf(fid,'%s \r\n',['y' num2str(0) ' = session.xyDataObjects[''U''+str(' 'n' ')+''__' num2str(Number) ''']']);   
end
    
    fprintf(fid,'%s \r\n',[ ]); 
    fprintf(fid,'%s \r\n','session.xyReportOptions.setValues(numberFormat=AUTOMATIC)');
    fprintf(fid,'%s',['session.writeXYReport(fileName=''' headname '__''+str(' 'n' ')+''.txt'', xyData=(']); 
    fprintf(fid,'%s',['LPF ,']); 
    fprintf(fid,'%s',['y' num2str(0) ', ']);
    fprintf(fid,'%s',['y' num2str(1) ', ']);
 
    fprintf(fid,'%s \n',[')) ']);
    fclose(fid);
end  

%% Generate ABAQUS input files
    savename = [headname '__' num2str(Number)];
    fid=fopen([Path2,savename,'.inp'],'w+');
    fprintf(fid,'*HEADING \n');
    fprintf(fid,'%s \r\n','All units are in N & mm');
    fprintf(fid,'%s %d %s \r\n','Total column length =',L,'mm');
    fprintf(fid,'%s \r\n',[savename,' ',datestr(now)]);
    % no *RESTART, WRITE: restart files were never read and cost up to 19 GB per job

    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'%s \r\n','**Node set for end boundary conditions');
    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'*NODE,NSET=ALL  \r\n');
    fprintf(fid,'%d\t\t\t,   %f\t\t\t,   %f\t\t\t,   %f\t\t\t  \r\n',FEnode');
        
    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'%s \r\n','****Element type and Generation of elements');
    fprintf(fid,'%s \r\n','*****************************');

    for k=1:size(FEelem,3)
        fprintf(fid,'*ELEMENT,TYPE=%s,ELSET=STRIP%d  \r\n',elemtype,k);  %which strip
        if strcmp(elemtype,'S9R5')
            fprintf(fid,'%d, %d, %d, %d, %d, %d, %d, %d, %d, %d  \r\n',FEelem(:,:,k)');
        elseif strcmp(elemtype,'S4') || strcmp(elemtype, 'S4R')
            fprintf(fid,'%d, %d, %d, %d, %d  \r\n',FEelem(:,:,k)');
        end       

        fprintf(fid,'%s \r\n','*****************************');
        fprintf(fid,'*SHELL SECTION, ELSET=STRIP%d, MATERIAL=MAT%d \n',[k matnum(k)]);
        fprintf(fid,'%f  \r\n',t(k));
        fprintf(fid,'%s \r\n','*****************************');    
    end
    

    %%%%%% Web_BEAM %%%%%%
    
    fprintf(fid,'*ELEMENT, TYPE=B31, ELSET=Web_BEAM\n');
    for n = 1:size(FEelem_Beam_web,1)
        fprintf(fid, '%d, %d, %d\n', FEelem_Beam_web(n,:));
    end
    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'*BEAM SECTION, SECTION=RECT, ELSET=Web_BEAM, MATERIAL=MAT1\n');
    fprintf(fid,'%f, %f\n', 1, 0.5*h_web);
    %fprintf(fid,'%f, %f\n', epaisseur, hauteur);
    fprintf(fid,'0., 0., -1.\n');
    fprintf(fid,'%s \r\n','*****************************');

    %%%%%% Flange_BEAM %%%%%%
    
    fprintf(fid,'*ELEMENT, TYPE=B31, ELSET=Flange_BEAM\n');
    for n = 1:size(FEelem_Beam_flange,1)
        fprintf(fid, '%d, %d, %d\n', FEelem_Beam_flange(n,:));
    end
    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'*BEAM SECTION, SECTION=RECT, ELSET=Flange_BEAM, MATERIAL=MAT2\n');
    fprintf(fid,'%f, %f\n', 1, 0.5*h_flange);
    %fprintf(fid,'%f, %f\n', epaisseur, hauteur);
    fprintf(fid,'0., 0., -1.\n');
    fprintf(fid,'%s \r\n','*****************************');
    
    %%%%%% Material 1 %%%%%%
    fprintf(fid,'*MATERIAL, NAME=MAT1\n');
    fprintf(fid,'*ELASTIC\n');
    fprintf(fid,'210000., 0.3\n');
    fprintf(fid,'*****************************\n');

    %%%%%% Material 2 %%%%%%
    fprintf(fid,'*MATERIAL, NAME=MAT2\n');
    fprintf(fid,'*ELASTIC\n');
    fprintf(fid,'210000., 0.3\n');
    fprintf(fid,'*****************************\n');

    %%%%%% Material for section %%%%%%
    for i=1:size(mat,1)
        if analysis==1
            fprintf(fid,'*MATERIAL, NAME=MAT%d  \r\n',mat(i,1));
            fprintf(fid,'*ELASTIC, TYPE=ISOTROPIC  \r\n');
            fprintf(fid,'%f,  %f  \r\n',[mat(i,2:3)]);
            fprintf(fid,'%s \r\n','*****************************');
        else
            fprintf(fid,'*MATERIAL, NAME=MAT%d  \r\n',mat(i,1));
            fprintf(fid,'*ELASTIC, TYPE=ISOTROPIC  \r\n');
            fprintf(fid,'%f,  %f  \r\n',[mat(i,2:3)]);
            fprintf(fid,'%s \r\n','*****************************');
            
            if analysis==2||analysis==3    % Include material nonlinearity right now.
                fprintf(fid,'%s \r\n','*PLASTIC');    
                % 100 is for the web material, 200 is for the upper flange meterial, 300 is for the lower flange meterial.
                if mat(i,1)==100
                    for g=1:1:w_0(1);
                        fprintf(fid,'%10.9f\t\t,  %10.9f\t\t\r\n',sigma_pl_web(g),epsilon_pl_web(g));  
                    end
                    fprintf(fid,'%s \r\n','*****************************');
                elseif mat(i,1)==200
                    for g=1:1:f_1(1);
                        fprintf(fid,'%10.9f\t\t, %10.9f\t\t\r\n',sigma_pl_upperflange(g),epsilon_pl_upperflange(g));  
                    end
                    fprintf(fid,'%s \r\n','*****************************');
                elseif mat(i,1)==300
                    for g=1:1:f_2(1);
                        fprintf(fid,'%10.9f\t\t, %10.9f\t\t\r\n',sigma_pl_lowerflange(g),epsilon_pl_lowerflange(g));  
                    end               
                    fprintf(fid,'%s \r\n','*****************************');
                end
            end
        end
    end


%% Nodes for beam element
AreaBeam1=max(0,(r1*r1-pi()*r1*r1/4)*2-tf1*tw/2);       %tf1*tw/2=the area overlapped
AreaBeam2=max(0,(r2*r2-pi()*r2*r2/4)*2-tf2*tw/2);       %tf1*tw/2=the area overlapped

It_shell_model=(B1*tf1^3+B2*tf2^3+(H-0.5*(tf1+tf2))*tw^3)/3;
It_catalogue=2/3*(0.5*(B1+B2)-0.63*0.5*(tf1+tf2))*(0.5*(tf1+tf2))^3+1/3*(H-tf1-tf2)*tw^3+2*(tw/(0.5*(tf1+tf2)))*(0.145+0.1*(0.5*(r1+r2))/(0.5*(tf1+tf2)))*(((0.5*(r1+r2)+0.5*tw)^2+(0.5*(r1+r2+tf1+tf2))^2-(0.5*(r1+r2))^2)/(r1+r2+0.5*(tf1+tf2)))^4;
It_beam=0.5*(It_catalogue-It_shell_model);

if It_beam>0
t_beam1 =(AreaBeam1^3/(64*It_beam))^0.5;
h_beam1 =AreaBeam1/(4*t_beam1)+t_beam1;
t_beam2 =(AreaBeam2^3/(64*It_beam))^0.5;
h_beam2 =AreaBeam2/(4*t_beam2)+t_beam2;

% Beam sections  
if t_beam1~=0
    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'%s \r\n','**Beam element1');
    fprintf(fid,'%s \r\n','*****************************');
    
    % Elements
    fprintf(fid,'%s \r\n','*ELEMENT, TYPE = B31');
%    for i=0:nL-2;
    for i=1:nL-3;
        fprintf(fid,'%d\t\t, %d\t\t, %d\t\t\r\n',10000000+i,node_2+i*FEsection_increment,node_2+(i+1)*FEsection_increment); 
    end
    
    fprintf(fid,'%s \r\n','*ELSET, ELSET = TOPBEAM,GENERATE');
%    fprintf(fid,'%d\t\t, %d\t\t, %d\t\t\r\n',100000,100000+(nL-2),1);
    fprintf(fid,'%d\t\t, %d\t\t, %d\t\t\r\n',10000001,10000000+(nL-3),1);
    
    fprintf(fid,'%s \r\n','*BEAM SECTION, ELSET = TOPBEAM, MATERIAL = MAT100, temperature = GRADIENTS, section=BOX');
    fprintf(fid,'%10.3f\t\t, %10.3f\t\t, %10.3f\t\t, %10.3f\t\t, %10.3f\t\t, %10.3f \r\n',h_beam1, h_beam1, t_beam1, t_beam1, t_beam1, t_beam1);
    fprintf(fid,'%3.2f\t\t, %3.2f\t\t\t, %3.2f\t\t\t \r\n',1 ,0 ,0);
end

if t_beam2~=0
    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'%s \r\n','**Beam element2');
    fprintf(fid,'%s \r\n','*****************************');
    
    % Elements
    fprintf(fid,'%s \r\n','*ELEMENT, TYPE = B31');
 %   for i=0:nL-2;
    for i=1:nL-3;
        fprintf(fid,'%d\t\t, %d\t\t, %d\t\t\r\n',20000000+i,node_5+i*FEsection_increment,node_5+(i+1)*FEsection_increment); 
    end
    
    fprintf(fid,'%s \r\n','*ELSET, ELSET = BOTTOMBEAM,GENERATE');
%    fprintf(fid,'%d\t\t, %d\t\t, %d\t\t\r\n',200000,200000+(nL-2),1);
    fprintf(fid,'%d\t\t, %d\t\t, %d\t\t\r\n',20000001,20000000+(nL-3),1);
    
    fprintf(fid,'%s \r\n','*BEAM SECTION, ELSET = BOTTOMBEAM, MATERIAL = MAT100, temperature = GRADIENTS, section=BOX');
    fprintf(fid,'%10.3f\t\t, %10.3f\t\t, %10.3f\t\t, %10.3f\t\t, %10.3f\t\t, %10.3f \r\n',h_beam2, h_beam2, t_beam2, t_beam2, t_beam2, t_beam2);
    fprintf(fid,'%3.2f\t\t, %3.2f\t\t\t, %3.2f\t\t\t \r\n',1 ,0 ,0);    
end
end

%% Generate spring element

fprintf(fid,'%s \r\n','*****************************');
fprintf(fid,'%s \r\n','**Spring element');
fprintf(fid,'%s \r\n','*****************************');
fprintf(fid,'%s \r\n','*SPRING, ELSET=Spring');
fprintf(fid,'%s \r\n','');
fprintf(fid,'%3.2f \r\n',springstiff);
fprintf(fid,'%s \r\n','*ELEMENT, Type=SpringA, elset=Spring');
for i=1:nL
    fprintf(fid,'%3.0f\t\t, %3.0f\t\t, %3.0f\r\n',100000000+i,node_8+(i-1)*FEsection_increment,node_11+(i-1)*FEsection_increment);
    fprintf(fid,'%3.0f\t\t, %3.0f\t\t, %3.0f\r\n',200000000+i,node_8+(i-1)*FEsection_increment,node_3+(i-1)*FEsection_increment);
    fprintf(fid,'%3.0f\t\t, %3.0f\t\t, %3.0f\r\n',300000000+i,node_11+(i-1)*FEsection_increment,node_3+(i-1)*FEsection_increment);
   
    fprintf(fid,'%3.0f\t\t, %3.0f\t\t, %3.0f\r\n',400000000+i,node_14+(i-1)*FEsection_increment,node_17+(i-1)*FEsection_increment);
    fprintf(fid,'%3.0f\t\t, %3.0f\t\t, %3.0f\r\n',500000000+i,node_14+(i-1)*FEsection_increment,node_4+(i-1)*FEsection_increment);
    fprintf(fid,'%3.0f\t\t, %3.0f\t\t, %3.0f\r\n',600000000+i,node_17+(i-1)*FEsection_increment,node_4+(i-1)*FEsection_increment);
end
 
%% Reference nodes    
fprintf(fid,'%s \r\n','*****************************');
fprintf(fid,'%s \r\n','**reference nodes');
fprintf(fid,'%s \r\n','*****************************');

% --- NSET END1 ---
fprintf(fid, '*NSET, NSET=END1\n');
for i = 1:length(end1)
    fprintf(fid, '%d', end1(i));
    if i ~= length(end1)
        fprintf(fid, ', ');
    end
    if mod(i,16) == 0
        fprintf(fid, '\n');
    end
end
fprintf(fid, '\n');

% --- NSET END2 ---
fprintf(fid, '*NSET, NSET=END2\n');
for i = 1:length(end2)
    fprintf(fid, '%d', end2(i));
    if i ~= length(end2)
        fprintf(fid, ', ');
    end
    if mod(i,16) == 0
        fprintf(fid, '\n');
    end
end
fprintf(fid, '\n');


% --- NSET FIX BC ---
fprintf(fid, '*NSET, NSET=SET_BC\n');
for i = 1:length(Set_nodes_BC)
    fprintf(fid, '%d', Set_nodes_BC(i));
    if i ~= length(Set_nodes_BC)
        fprintf(fid, ', ');
    end
    if mod(i,16) == 0
        fprintf(fid, '\n');
    end
end
fprintf(fid, '\n');

% --- NSET FIX BC2 ---
fprintf(fid, '*NSET, NSET=SET_BC2\n');
for i = 1:length(Set_nodes_BC2)
    fprintf(fid, '%d', Set_nodes_BC2(i));
    if i ~= length(Set_nodes_BC2)
        fprintf(fid, ', ');
    end
    if mod(i,16) == 0
        fprintf(fid, '\n');
    end
end
fprintf(fid, '\n');
% % 

fprintf(fid, '*SURFACE, NAME=END1, TYPE=NODE\n');
fprintf(fid, 'END1,\n');  

fprintf(fid, '*SURFACE, NAME=END2, TYPE=NODE\n');
fprintf(fid, 'END2,\n'); 

% RP nodes
fprintf(fid,'*NODE, NSET=RP1  \r\n');
fprintf(fid,'%d\t,   %f\t,   %f\t,   %f\t  \r\n',FEnode_ref_1, xr1, yr1,zr1);
fprintf(fid,'*NODE, NSET=RP2  \r\n');
fprintf(fid,'%d\t,   %f\t,   %f\t,   %f\t  \r\n',FEnode_ref_2, xr2, yr2,zr2);

% Nodes read by the .py (mid-length node, RP1, RP2) for the reduced field output
fprintf(fid,'*NSET, NSET=OUT_PY\r\n');
fprintf(fid,'%d, %d, %d\r\n',FEnode_centroid(3,1), FEnode_ref_1, FEnode_ref_2);


%% Kinematic Coupling
% --- Couplings (inside the same PART) ---
fprintf(fid, '*COUPLING, CONSTRAINT NAME=COUP1, REF NODE=RP1, SURFACE=END1\n');
fprintf(fid, '*KINEMATIC\n');
fprintf(fid, '*COUPLING, CONSTRAINT NAME=COUP2, REF NODE=RP2, SURFACE=END2\n');
fprintf(fid, '*KINEMATIC\n');


%% Boundary condition
fprintf(fid,'%s \r\n','*****************************');
fprintf(fid,'%s \r\n','**Definition of Boundary Conditions');
fprintf(fid,'%s \r\n','*****************************');  
fprintf(fid,'*BOUNDARY \r\n');
fprintf(fid,'RP1, 1, 2, 0.0\n');  % Ux=Uy=0
% fprintf(fid,'RP1, 4, 4, 0.0\n');     % Rx=0
% fprintf(fid,'RP1, 5, 5, 0.0\n');     % Ry=0
fprintf(fid,'RP1, 6, 6, 0.0\n');     % Rz=0

fprintf(fid,'RP2, 1, 3, 0.0\n');  % Ux=Uy=Uz=0
% fprintf(fid,'RP2, 4, 4, 0.0\n');     % Rx=0
% fprintf(fid,'RP2, 5, 5, 0.0\n');     % Ry=0
fprintf(fid,'RP2, 6, 6, 0.0\n');     % Rz=0

fprintf(fid,'SET_BC, 1, 1, 0.0\n'); % Ux=0
fprintf(fid,'SET_BC2, 1, 1, 0.0\n'); % Ux=0

%% Add Residual Stress
if 1==1
if analysis==2||analysis==3
    fprintf(fid,'%s \r\n','*****************************');
    fprintf(fid,'%s \r\n','**Adding residual stress');
    fprintf(fid,'%s \r\n','*STEP,NAME=RESIDUALSTRESSES,NLGEOM=YES,INC=100');
    fprintf(fid,'%s \r\n','*STATIC');
    fprintf(fid,'%s \r\n','*INITIAL CONDITIONS,TYPE=STRESS');
    for k=1:size(FEelem,3)
               if matnum(k)==100
            fprintf(fid,'%s%d\t\t, %10.3f\t\t\t, %10.3f\t\t\t, %10.3f\t\t\r\n','STRIP',k,residual(k),0,0); 
        else        
            fprintf(fid,'%s%d\t\t, %10.3f\t\t\t, %10.3f\t\t\t, %10.3f\t\t\r\n','STRIP',k,0,residual(k),0); 
               end
    end
    fprintf(fid,'%s \r\n','*END STEP');
end
end
%% STEP

    % Riks settings from the major-axis member slenderness:
    % short columns peak early and need small arc-length steps to catch the peak;
    % long columns reach it only after a long arc length and can take larger steps.
    lambda_y = sqrt(A*Fy/(pi^2*ME*Ixx/L(1)^2));
    if lambda_y <= lambda_switch
        Max_inc = riks_short(1);  Max_nb_inc = riks_short(2);
    else
        Max_inc = riks_long(1);   Max_nb_inc = riks_long(2);
    end

if analysis==1
   fprintf(fid,'*STEP \r\n');
   fprintf(fid,'*BUCKLE,EIGENSOLVER=LANCZOS \r\n');
   fprintf(fid,'50,4 , , , \r\n');
    % fprintf(fid,'%s\r\n','*STEP, NLGEOM');
    % fprintf(fid,'%s \r\n','*Buckle');
    % fprintf(fid,'%3.2d\t\t,%3.2d\t\t,%3.2d\t\t,%3.2d\t\t\r\n',10,[],100,100);
        
elseif analysis==2||analysis==3    % Elastic static analysis
    fprintf(fid,'*STEP, name=STEP 1, nlgeom=YES, INC= %g\r\n',Max_nb_inc);
    %fprintf(fid,'*STEP, name=STEP 1, nlgeom=YES, INC= 350\r\n');
    fprintf(fid,'*STATIC,Riks\r\n');%*STATIC,Direct,Riks
    
    if Loading==0
        %fprintf(fid,'%f\t\t,%d\t\t,%.16f\t\t,%f\t\t\r\n',0.3*L/(B1+H)/280 , 1, 0.000000000000001, L/(B1+H)/70); 
        %fprintf(fid,'0.1 , 1, 0.000000000000001, 0.5	\r\n');
        fprintf(fid,'%f\t\t,%d\t\t,%.16f\t\t,%f\t\t\r\n',Initial_inc, Scale_fact, Min_inc, Max_inc);
    else
        fprintf(fid,'%f\t\t,%d\t\t,%.16f\t\t,%f\t\t\r\n',Initial_inc, Scale_fact, Min_inc, Max_inc);
        %fprintf(fid,'0.005 , 1, 0.000000000000001, 0.08	\r\n');
        %fprintf(fid,'%f\t\t,%d\t\t,%.16f\t\t,%f\t\t\r\n',0.3*L/(B1+H)/280 , 1, 0.000000000000001, L/(B1+H)/70); 
    end   
end

%% STATIC ANALYSIS   ---- NONLINER
%For displacement control at reference nodes
fprintf(fid,'******LOADS******\r\n\n');
fprintf(fid,'%s\r\n','*CLOAD');
fprintf(fid,'%s\t\t,%d\t\t,%d\t\t\r\n','RP1',3, Load_N); 

if reduced_output && (analysis==2||analysis==3)
    fprintf(fid,'%s\r\n','*Output, field, frequency=1');
    fprintf(fid,'%s\r\n','*Node Output, nset=OUT_PY');
    fprintf(fid,'%s\r\n','U, RF');
    fprintf(fid,'%s\r\n','*Output, field, variable=PRESELECT, frequency=25');
else
    fprintf(fid,'%s \r\n','*Output, field, variable=PRESELECT ');
end
fprintf(fid,'%s \r\n','*Output, history, variable=PRESELECT ');
if analysis==1&&caculation_number==2
    fprintf(fid,'%s\r\n','*node file');
    fprintf(fid,'%s\r\n','u');
end
fprintf(fid,'*END STEP\r\n');
status=fclose(fid);
  
Loop=Loop+1;
% % analysis=analysis+1;  

end
end
% Écriture dans Excel
T = array2table(parameters_section, 'VariableNames', {'i', 'A', 'Ixx', 'Izz'});
writetable(T, 'parameters_section_All.xlsx', 'Sheet', 1);




%% ------------------------------------------------------------------------
function [A,xcg,zcg,Ixx,Izz,Zs] = section_props(coord,ends)
% Section properties of an open thin-walled strip model.
% coord: [x z] of each node; ends: [nodei nodej t] of each element.
% Same computation as CUFSM cutwp_prop2 (open sections), reduced to the
% outputs used by this script: area, centroid, inertias and shear centre Zs.

nele_new = size(ends,1);

% find the element properties
xm=zeros(1,nele_new);
ym=zeros(1,nele_new);
t_new=zeros(1,nele_new);
xd=zeros(1,nele_new);
yd=zeros(1,nele_new);
L_new=zeros(1,nele_new);

for i = 1:nele_new
    sn = ends(i,1); fn = ends(i,2);
    t_new(i) = ends(i,3);
    xm(i) = mean(coord([sn fn],1));
    ym(i) = mean(coord([sn fn],2));
    xd(i) = diff(coord([sn fn],1));
    yd(i) = diff(coord([sn fn],2));
    L_new(i) = norm([xd(i) yd(i)]);
end

% cross section area and centroid
A = sum(L_new.*t_new);
xcg = sum(L_new.*t_new.*xm)/A;
zcg = sum(L_new.*t_new.*ym)/A;

if abs(xcg/sqrt(A)) < 1e-12
    xcg = 0;
end
if abs(zcg/sqrt(A)) < 1e-12
    zcg = 0;
end

% moments of inertia
Ixx = sum((yd.^2/12+(ym-zcg).^2).*L_new.*t_new);
Izz = sum((xd.^2/12+(xm-xcg).^2).*L_new.*t_new);
Ixz = sum((xd.*yd/12+(xm-xcg).*(ym-zcg)).*L_new.*t_new);

if abs(Ixz/A^2) < 1e-12
    Ixz = 0;
end

% shear centre (sectorial coordinate built element by element from node 1)
nnode_new = size(coord,1);
w = zeros(nnode_new,2); w(ends(1,1),1) = ends(1,1);
Iwx = 0; Iwy = 0;

for j = 1:nele_new
    i = 1;
    while (any(w(:,1)==ends(i,1))&any(w(:,1)==ends(i,2)))|(~(any(w(:,1)==ends(i,1)))&(~any(w(:,1)==ends(i,2))))
        i = i+1;
    end
    sn = ends(i,1); fn = ends(i,2);
    p = ((coord(sn,1)-xcg)*(coord(fn,2)-zcg)-(coord(fn,1)-xcg)*(coord(sn,2)-zcg))/L_new(i);
    if w(sn,1)==0
        w(sn,1) = sn;
        w(sn,2) = w(fn,2)-p*L_new(i);
    elseif w(fn,1)==0
        w(fn,1) = fn;
        w(fn,2) = w(sn,2)+p*L_new(i);
    end
    Iwx = Iwx+(1/3*(w(sn,2)*(coord(sn,1)-xcg)+w(fn,2)*(coord(fn,1)-xcg))+1/6*(w(sn,2)*(coord(fn,1)-xcg)+w(fn,2)*(coord(sn,1)-xcg)))*t_new(i)* L_new(i);
    Iwy = Iwy+(1/3*(w(sn,2)*(coord(sn,2)-zcg)+w(fn,2)*(coord(fn,2)-zcg))+1/6*(w(sn,2)*(coord(fn,2)-zcg)+w(fn,2)*(coord(sn,2)-zcg)))*t_new(i)* L_new(i);
end

if (Ixx*Izz-Ixz^2)~=0
    Zs = -(Ixx*Iwx-Ixz*Iwy)/(Ixx*Izz-Ixz^2)+zcg;
else
    Zs = zcg;
end

if abs(Zs/sqrt(A)) < 1e-12
    Zs = 0;
end
end

%% ------------------------------------------------------------------------
function fu = fu_nominal(fy)
% Nominal ultimate tensile strength fu (MPa) of the steel grade, t <= 40 mm
% (EN 1993-1-1 Table 3.1 and EN 1993-1-12). Add a row for any other grade.
%         fy    fu
grades = [235   360;    % S235  (EN 10025-2)
          275   430;    % S275  (EN 10025-2)
          355   490;    % S355  (EN 10025-2)
          420   520;    % S420  (EN 10025-4)
          440   550;    % S450  (EN 10025-2, fy = 440 for t <= 40 mm)
          460   540;    % S460  (EN 10025-4)
          690   770;    % S690Q (EN 10025-6)
          960   980];   % S960Q (EN 10025-6)

k = find(abs(grades(:,1)-fy)<1e-6,1);
if isempty(k)
    error('No nominal fu for fy = %g MPa: add the grade to fu_nominal.',fy);
end
fu = grades(k,2);
end

%% ------------------------------------------------------------------------
function [sig_true,eps_pl,info] = yun_gardner_material(E,fy,fu,model)
% Engineering stress-strain curve of hot-rolled steel from Yun & Gardner (2017),
% converted to true stress / logarithmic plastic strain for ABAQUS *PLASTIC.
% model = 1: quad-linear, Eq.(3) ; model = 2: bilinear + nonlinear hardening, Eq.(14)

eps_y  = fy/E;
eps_u  = max(0.6*(1-fy/fu),0.06);                 % Eq.(8)
eps_sh = min(max(0.1*fy/fu-0.055,0.015),0.03);    % Eq.(9)
Esh    = (fu-fy)/(0.4*(eps_u-eps_sh));            % Eq.(13)

if model==1
    eps_C1 = eps_sh+0.25*(eps_u-eps_sh);          % C1*eps_u, Eq.(11)
    f_C1   = fy+Esh*(eps_C1-eps_sh);
    eps = [eps_y; eps_sh; eps_C1; eps_u];
    sig = [fy;    fy;     f_C1;   fu];
elseif model==2
    x   = linspace(0,1,51)';                      % (eps-eps_sh)/(eps_u-eps_sh), 50 hardening segments
    eps = [eps_y; eps_sh+x*(eps_u-eps_sh)];
    sig = [fy; fy+(fu-fy)*(0.4*x+2*x./(1+400*x.^5).^(1/5))];   % K1=0.4, K2=2, K3=400, K4=5
else
    error('material_model must be 1 or 2.');
end

% True stress and logarithmic plastic strain
sig_true = sig.*(1+eps);
eps_pl   = log(1+eps)-sig_true/E;
eps_pl(1) = 0;                                    % yield point (round-off of order eps_y^2)

if any(diff(eps_pl)<=0)
    error('Plastic strain of the material law is not increasing.');
end

info = struct('eps_y',eps_y,'eps_sh',eps_sh,'eps_u',eps_u,'Esh',Esh);
end
