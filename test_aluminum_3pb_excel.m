function test_aluminum_3pb_excel()
% Run in MATLAB to check workbook parsing and workbook-to-deck generation.
root=fileparts(mfilename('fullpath'));
source=fullfile(root,'Aluminum_3PB_Input.xlsx');
c=read_aluminum_3pb_excel(source); expected=aluminum_welded_3pb_config();
assert(isequal(c.geometry,expected.geometry));
assert(isequal(c.haz,expected.haz));
assert(isequal(c.analysis,expected.analysis));
assert(isequal(c.stiffeners(:),expected.stiffeners(:)));
assert(isequal(c.materials,expected.materials));
assert(isempty(c.regions),'The example custom region must remain disabled.');
folder=tempname; mkdir(folder);
cleanup=onCleanup(@() rmdir(folder,'s')); %#ok<NASGU>
file=fullfile(folder,'inputs.xlsx'); copyfile(source,file);
% Disable every stiffener, change span and activate the sample region.
writematrix(zeros(6,1),file,'Sheet','Stiffeners','Range','A2');
writematrix(3000,file,'Sheet','Geometry','Range','B2');
writematrix(1,file,'Sheet','Regions','Range','A2');
writematrix(0,file,'Sheet','Control','Range','B7');
c=read_aluminum_3pb_excel(file);
assert(c.geometry.length==3000 && isempty(c.stiffeners));
assert(isequal(c.regions.bounds,[-inf inf;900 1500;30 80]));
assert(strcmp(c.outputDir,fullfile(folder,'Aluminum_3PB_output')));
m=run_aluminum_3pb_excel(file); assert(isfile(m.inputFile));
% Reject a mistyped boolean instead of silently enabling it.
writematrix(2,file,'Sheet','Control','Range','B7');
failed=false;
try, read_aluminum_3pb_excel(file); catch, failed=true; end
assert(failed,'Invalid boolean was accepted.');
fprintf('Excel input smoke checks passed.\n');
end
