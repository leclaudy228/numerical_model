cd('C:\Kokou\Kokou_Case_study_1_Steel_Column\Numerical model_validation');
test_aluminum_welded_3pb();
test_aluminum_3pb_excel();
c = aluminum_welded_3pb_config();
c.name = 'Al3PB_L1800_H250';
c.outputDir = fullfile(pwd,'Aluminum_3PB_output','Al3PB_L1800_H250');
c.geometry = struct('length',1800,'height',250,'topWidth',120, ...
    'bottomWidth',120,'topThickness',8,'bottomThickness',8,'webThickness',5);
c.meshSize = 15;
c.haz = struct('flangeWidth',25,'webWidth',25,'stiffenerWidth',20);
k = 0; c.stiffeners = c.stiffeners([]);
for y = [0 900 1800]
    for side = [-1 1]
        k = k+1;
        c.stiffeners(k) = struct('position',y,'side',side,'width',55,'thickness',8);
    end
end
c.analysis.displacement = 30;
c.imperfection = 1.8;   % L/1000
c.preview = true;
m = Aluminum_Welded_I_section_3PB(c);
view(35,25); exportgraphics(gcf, fullfile(c.outputDir,'regions.png'), 'Resolution',150);
