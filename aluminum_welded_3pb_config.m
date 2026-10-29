function c = aluminum_welded_3pb_config()
% Editable example, units N, mm, MPa. Replace material curves with test data.
c.name = 'Aluminum_Welded_I_3PB';
c.outputDir = fullfile(pwd,'Aluminum_3PB_output');
c.geometry = struct('length',2400,'height',300,'topWidth',150, ...
    'bottomWidth',150,'topThickness',10,'bottomThickness',10,'webThickness',6);
c.meshSize = 20;
c.haz = struct('flangeWidth',20,'webWidth',20,'stiffenerWidth',15);
% Transverse plates: y is along the member; side = -1 or +1 from web.
% width measured from web mid-plane, with an ideal shared-node weld.
s = struct('position',0,'side',1,'width',65,'thickness',8);
c.stiffeners = repmat(s,6,1);
k = 0;
for y = [0 c.geometry.length/2 c.geometry.length]
    for side = [-1 1]
        k = k+1;
        c.stiffeners(k) = struct('position',y,'side',side,'width',65,'thickness',8);
    end
end
% Remove all plates with: c.stiffeners = c.stiffeners([]);
% Each material: [true stress, equivalent plastic strain], first strain = 0.
% Illustrative curves ONLY; not an alloy/temper calibration or design data.
base = [240 0; 255 .005; 275 .02; 290 .05; 300 .10];
haz  = [110 0; 125 .005; 145 .02; 165 .05; 180 .10];
names = {'WEB_BASE','WEB_HAZ','TOP_BASE','TOP_HAZ', ...
    'BOTTOM_BASE','BOTTOM_HAZ','STIFFENER_BASE','STIFFENER_HAZ'};
for k = 1:numel(names)
    c.materials(k) = struct('name',names{k},'E',70000,'nu',.33,'plastic',base);
    if mod(k,2)==0, c.materials(k).plastic = haz; end
end
% Optional custom material regions, selected by element centroid.
% component: 0=all, 1=web, 2=top flange, 3=bottom flange, 4=stiffeners.
% bounds: [xmin xmax; ymin ymax; zmin zmax], material=index in c.materials.
% Later regions override earlier ones. Finite box boundaries enter the mesh.
c.regions = struct('component',{},'bounds',{},'material',{});
c.analysis = struct('displacement',40,'initialIncrement',.01, ...
    'minimumIncrement',1e-7,'maximumIncrement',.05,'maximumIncrements',1000);
% Optional lateral crookedness: x(y)=amplitude*sin(pi*y/L).
c.imperfection = 0;
c.lateralGuideAtLoad = true;
c.preview = true;
end
