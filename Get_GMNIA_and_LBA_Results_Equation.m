        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %-------------------------For py. and dat. files--------------------------%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %-------------------------------By Liya Li--------------------------------%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Objective
%Obtain LBA, MNA and GMNIA results from ABAQUS
clc;
clear all;
close all;

DataFolder='Crtical load_LBA';  %%%%%%%%%% Need to be modifided
NID = fopen(strcat(pwd,'\',DataFolder,'\','Filename.dat'),'r');
Content=textscan(NID,'%s%s%s%s%s%s');
fclose(NID);
NID = fopen(strcat(pwd,'\',DataFolder,'\','Filename.dat'),'r');
FileNum = 0;
%DataFolder='PARAMETRIC STUDY';  %%%%%%%%%% Need to be modifided
while ~feof(NID) %while the end of the  "fileend of file" has not been reached
    fgetl(NID);% used to read a line from file identified by NID
    FileNum = FileNum +1;
end % This loop reads all the lines from NID file
Name=cell(FileNum,1); % Creates cell array with 41 rows and 1 column
Analysis=cell(FileNum,1);
%Loading=cell(FileNum,1);
N_0=cell(FileNum,1);
My_0=cell(FileNum,1);
Mz_0=cell(FileNum,1);
for i=1:FileNum
    Name{i}=Content{1,1}{i,1};
    Analysis{i}=Content{1,2}{i,1};
    %Loading{i}=Content{1,3}{i,1};   
    N_0{i}=Content{1,4}{i,1};  
    My_0{i}=Content{1,5}{i,1};  
    Mz_0{i}=Content{1,6}{i,1};  
end
fclose(NID);

FileNum_LBA=0;
FileNum_GMNIA=0;
Name_GMNIA=cell(FileNum,1);
Name_LBA=cell(FileNum,1);
for i=1:FileNum
     if strcmpi(Analysis{i},'LBA')  
        FileNum_LBA=FileNum_LBA+1;
        Name_LBA{FileNum_LBA}=Name{i};
        %Loading_LBA{FileNum_LBA}=Loading{i};
        N_0_LBA{FileNum_LBA}=N_0{i};   
        My_0_LBA{FileNum_LBA}=My_0{i};          
        Mz_0_LBA{FileNum_LBA}=Mz_0{i};          
     elseif strcmpi(Analysis{i},'GMNIA') || strcmpi(Analysis{i},'MNA') % or logical operator
        FileNum_GMNIA=FileNum_GMNIA+1;
        Name_GMNIA{FileNum_GMNIA}=Name{i};
        %Loading_GMNIA{FileNum_GMNIA}=Loading{i};
        N_0_GMNIA{FileNum_GMNIA}=N_0{i};       
        My_0_GMNIA{FileNum_GMNIA}=My_0{i};          
        Mz_0_GMNIA{FileNum_GMNIA}=Mz_0{i};          
    end
end

%% Obtain GMNIA Results
if FileNum_GMNIA~=0 % If there is atleast one case (out of 41) that needs to be analysed
OutputName_GMNIA=strcat('Results_GMNIA - ',DataFolder,'.xlsx');    % Generates a name for excel file
  
AllDataCell = cell(1,FileNum_GMNIA);
AllRowCount = zeros(1,FileNum_GMNIA);
for i = 1:FileNum_GMNIA %Iteration over each GMNIA file
    % open file
    FileName = [Name_GMNIA{i} '.txt'];% constructs file name with txt extension

 try % executes if no error occurrs
    fid = fopen(strcat(pwd,'\',DataFolder,'\',FileName),'r');
    % read empty lines
    fgetl(fid); fgetl(fid); fgetl(fid); %  escapes first three lines of the file (reads the line and moves the pointer to next line)
    % extract information
    %Displacement_Data_1 = [];  
    Force_Data = []; % Extracting information from file and storing it in Force_Data
    while true 
        LineInfo = fgetl(fid);% read line from fid file
        if ~isempty(LineInfo)
            LineInfo = cell2mat(textscan(LineInfo,'%f%f'));  %How many parameters in the txt
        else
            break;
        end
        AllRowCount(i) = AllRowCount(i)+1;
        %Displacement_Data_1 = [Displacement_Data_1; LineInfo(:,3)];   %%% Data reading from txt. file             
        Force_Data = [Force_Data; LineInfo(:,2)]; %%%%%%%%%%%% SHOULD BE 2 or second column
    end
    fclose(fid); 
    %Displacement_DataCell_1{i} = Displacement_Data_1;   
    Force_DataCell{i} = Force_Data;
    for j=2:AllRowCount(i) %This loop processes force data row by row,  and locates maximum force
        if Force_Data(j,1)>Force_Data(j-1,1)
            Max_LPF=Force_Data(j,1);
        else
            break
        end
    end
    
    

    
    if str2num(N_0_GMNIA{i})~=0 % converting string to a number and checks if its not equal to zero
        R_b=Max_LPF*str2num(N_0_GMNIA{i})/1000; % calculates ultimate load by multiplying LPF to initial load I guess
    elseif str2num(My_0_GMNIA{i})~=0
        R_b=Max_LPF*str2num(My_0_GMNIA{i})/1000000;
    else
        R_b=Max_LPF*str2num(Mz_0_GMNIA{i})/1000000;
    end
    
 catch % handles any error that may occurr in try block
     R_b=0; % If error occurrs, R_b is assigned a value zero
 end
 
    fid1 = fopen(strcat(pwd,'\','Results_GMNIA-',DataFolder, '.txt'),'a+');% Creates file txt format I think
    fprintf(fid1,'%f\r\n',R_b);  % Writes the value of R_b 
    fclose(fid1); 
end 



MaxRowNum = max(AllRowCount)+2;
OutMatrix = zeros(max(MaxRowNum,2+FileNum_GMNIA),FileNum_GMNIA); 
for i = 1:FileNum_GMNIA
    OutMatrix(3:AllRowCount(i)+2,i+4) = Force_DataCell{i};   
    for j=4:AllRowCount(i)+2
        if OutMatrix(j,i+4)>OutMatrix(j-1,i+4)
            Max_LPF=OutMatrix(j,i+4);
        else
            break
        end
    end
    OutMatrix(1,i+4) = Max_LPF;
    OutMatrix(i,2) = Max_LPF*str2num(N_0_GMNIA{i})/1000;     
    OutMatrix(i,3) = Max_LPF*str2num(My_0_GMNIA{i})/1000000;           
    OutMatrix(i,4) = Max_LPF*str2num(Mz_0_GMNIA{i})/1000000;    
end

OutMatrix_new=num2cell(OutMatrix);
for i = 1:FileNum_GMNIA
    OutMatrix_new(i,1) = {Name_GMNIA{i}};    
    OutMatrix_new(2,i+4) = {' '};      
end

if MaxRowNum > 2+FileNum_GMNIA
    for i = 1+FileNum_GMNIA : MaxRowNum
        OutMatrix_new(i,1:4) = {' '};     
    end
end
OutMatrix_new(:,FileNum_GMNIA+1+1) = {' '};
OutMatrix_new(1:2,1) = {' '};

NameTitle={};Vacant={};
for i = 1:FileNum_GMNIA
    NameTitle=[NameTitle, {Name_GMNIA{i}}];
    Vacant=[Vacant,{' '}];
end

NameTitle=[{'No.'},{'N_Ed'},{'My_Ed'},{'Mz_Ed'},NameTitle];
Vacant=[{' '},{'KN'},{'KN.m'},{'KN.m'},Vacant];

OutMatrix_new1=[NameTitle;Vacant;OutMatrix_new(1:2,:);OutMatrix_new(3:max(MaxRowNum,2+FileNum_GMNIA),:)];
xlswrite(OutputName_GMNIA,OutMatrix_new1);






end

%% Obtain LBA Results
if FileNum_LBA~=0
Stamp = ' MODE NO      EIGENVALUE';
OutputName_LBA=strcat('Results_LBA - ',DataFolder,'.xlsx');  

AllDataCell = cell(1,FileNum_LBA);
AllRowCount = zeros(1,FileNum_LBA);
      
for  i = 1:FileNum_LBA
        FileName = [Name_LBA{i} '.dat'];

        fid = fopen(strcat(pwd,'\',DataFolder,'\',FileName),'r');
        LineInfo = 0;
        while ~feof(fid)
            LineInfo = fgetl(fid); 
            if ~ischar(LineInfo)                % if eigenvalue cannot be obtained from the file
                LineInfo(1,2)=0;
                break
            else if strcmp(Stamp,LineInfo)
                fgetl(fid); fgetl(fid);             % read two empty lines
                LineInfo = fgetl(fid);           % read the info line
                LineInfo = cell2mat(textscan(LineInfo,'%f%f')); 
                break
                end
            end
        end                
    fclose(fid);
    AllDataCell{1,i} =abs(LineInfo(1,2))*str2num(N_0_LBA{i})/1000;   
    AllDataCell{2,i} =abs(LineInfo(1,2))*str2num(My_0_LBA{i})/1000000;   
    AllDataCell{3,i} =abs(LineInfo(1,2))*str2num(Mz_0_LBA{i})/1000000; 
    
    
    
    if str2num(N_0_LBA{i})~=0
        R_b=AllDataCell{1,i};
    elseif str2num(My_0_LBA{i})~=0
        R_b=AllDataCell{2,i};
    else
        R_b=AllDataCell{3,i};
    end
    
    fid1 = fopen(strcat(pwd,'\','Results_LBA-',DataFolder, '.txt'),'a+');
    fprintf(fid1,'%f\r\n',R_b);  
    fclose(fid1); 
end
    OutMatrix = {FileNum_LBA,2}; 
for p = 1:FileNum_LBA
    OutMatrix{p,1} = Name_LBA{p,1};  
    OutMatrix{p,2} = AllDataCell{1,p};  
    OutMatrix{p,3} = AllDataCell{2,p};  
    OutMatrix{p,4} = AllDataCell{3,p};  
end
xlswrite(OutputName_LBA,OutMatrix);    
end
