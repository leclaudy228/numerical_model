function model = run_aluminum_3pb_excel(filename)
% Edit and save the Excel workbook, then run this function in MATLAB.
if nargin==0
    filename=fullfile(fileparts(mfilename('fullpath')),'Aluminum_3PB_Input.xlsx');
end
c=read_aluminum_3pb_excel(filename);
model=Aluminum_Welded_I_section_3PB(c);
end
