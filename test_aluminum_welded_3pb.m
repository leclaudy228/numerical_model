function test_aluminum_welded_3pb()
% MATLAB smoke checks. Generates temporary decks; does not run Abaqus.
folder=tempname; mkdir(folder);
cleanup=onCleanup(@() rmdir(folder,'s')); %#ok<NASGU>
c=aluminum_welded_3pb_config(); c.preview=false; c.outputDir=folder;
m=Aluminum_Welded_I_section_3PB(c);
assert(all(ismember(1:8,unique(m.material))),'Missing base/HAZ material zones.');
assert(max(m.plate)==9,'Expected three beam plates plus six stiffeners.');
assert(numel(unique(m.elements(:)))==size(m.nodes,1),'Unused shell nodes.');
deck=fileread(m.inputFile);
assert(contains(deck,'RP_LOAD, 3, 3, -40'),'Wrong load displacement.');
assert(contains(deck,'RP_RIGHT, 3, 3'),'Missing roller vertical restraint.');
% No stiffeners, unequal flanges and a user-defined additional material zone.
c.stiffeners=c.stiffeners([]); c.name='Unstiffened';
c.geometry.bottomWidth=180; c.geometry.bottomThickness=12;
c.materials(9)=c.materials(1); c.materials(9).name='CUSTOM_HAZ';
c.regions=struct('component',1,'bounds',[-inf inf; 300 400; 80 120],'material',9);
m=Aluminum_Welded_I_section_3PB(c);
assert(~any(m.component==4),'Unexpected stiffeners.');
ids=find(m.material==9); assert(~isempty(ids),'Custom area was not assigned.');
for axis=2:3
    v=m.nodes(m.elements(ids,:),axis);
    assert(all(v(:)>=c.regions.bounds(axis,1)-1e-8) && ...
        all(v(:)<=c.regions.bounds(axis,2)+1e-8),'Elements cross custom boundaries.');
end
% One-sided, nonuniform stiffeners and nonzero crookedness.
c.regions=c.regions([]); c.name='Variable_Stiffeners'; c.imperfection=2;
c.stiffeners=struct('position',{450,1600},'side',{1,-1}, ...
    'width',{50,60},'thickness',{5,9});
m=Aluminum_Welded_I_section_3PB(c);
assert(all(m.thickness(m.plate==4)==5) && all(m.thickness(m.plate==5)==9));
% Invalid geometry and plastic data must fail before writing.
bad=c; bad.geometry.height=1; mustFail(@() Aluminum_Welded_I_section_3PB(bad));
bad=c; bad.materials(1).plastic=[200 .01;220 0]; mustFail(@() Aluminum_Welded_I_section_3PB(bad));
fprintf('Aluminum three-point bending generator smoke checks passed.\n');
end
function mustFail(f)
failed=false;
try, f(); catch, failed=true; end
assert(failed,'Invalid configuration was accepted.');
end
