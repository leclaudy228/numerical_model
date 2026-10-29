function model = Aluminum_Welded_I_section_3PB(c)
% Generate a welded aluminum I-section S4R Abaqus model in three-point bending.
% Based on the plate/shell approach of Welded_I_section_Equation_General_OK_beam.
% Self-contained: no CUFSM or numbered steel input files required.
% x=flange width, y=member length, z=height; downward loading is negative U3.
% Example: c=aluminum_welded_3pb_config; model=Aluminum_Welded_I_section_3PB(c);
% No arguments uses the editable example configuration.
if nargin==0, c=aluminum_welded_3pb_config(); end
if ischar(c) || (isstring(c) && isscalar(c)), c=read_aluminum_3pb_excel(c); end
validateConfig(c);
g=c.geometry; L=g.length; h=g.height;
zb=g.bottomThickness/2; zt=h-g.topThickness/2;
% Include every weld/HAZ boundary explicitly, rather than classify a coarse mesh.
xp=[0 -g.webThickness/2-c.haz.flangeWidth g.webThickness/2+c.haz.flangeWidth];
yp=[0 L/2 L];
zp=[zb zt g.bottomThickness+c.haz.webWidth h-g.topThickness-c.haz.webWidth];
for k=1:numel(c.stiffeners)
    s=c.stiffeners(k);
    xp=[xp s.side*s.width s.side*(g.webThickness/2+c.haz.stiffenerWidth)]; %#ok<AGROW>
    yp=[yp s.position s.position-s.thickness/2-c.haz.stiffenerWidth ...
        s.position+s.thickness/2+c.haz.stiffenerWidth]; %#ok<AGROW>
    zp=[zp g.bottomThickness+c.haz.stiffenerWidth h-g.topThickness-c.haz.stiffenerWidth]; %#ok<AGROW>
end
for k=1:numel(c.regions)
    b=c.regions(k).bounds;
    xp=[xp b(1,isfinite(b(1,:)))]; %#ok<AGROW>
    yp=[yp b(2,isfinite(b(2,:)))]; %#ok<AGROW>
    zp=[zp b(3,isfinite(b(3,:)))]; %#ok<AGROW>
end
ygrid=gridline(0,L,yp,c.meshSize);
zgrid=gridline(zb,zt,zp,c.meshSize);
% Raw nodes are merged exactly after all plates are meshed.
raw=zeros(0,3); conn=zeros(0,4); component=zeros(0,1); plate=zeros(0,1);
thickness=zeros(0,1); material=zeros(0,1);
addPlate(1,1,0,ygrid,zgrid,g.webThickness,1);
addPlate(2,2,zt,gridline(-g.topWidth/2,g.topWidth/2,xp,c.meshSize),ygrid,g.topThickness,2);
addPlate(3,2,zb,gridline(-g.bottomWidth/2,g.bottomWidth/2,xp,c.meshSize),ygrid,g.bottomThickness,3);
for k=1:numel(c.stiffeners)
    s=c.stiffeners(k);
    xx=gridline(min(0,s.side*s.width),max(0,s.side*s.width),xp,c.meshSize);
    addPlate(4,3,s.position,xx,zgrid,s.thickness,k+3);
end
[nodes,~,mapping]=unique(raw,'rows');
elements=reshape(mapping(conn),size(conn));
centroids=(nodes(elements(:,1),:)+nodes(elements(:,2),:)+ ...
    nodes(elements(:,3),:)+nodes(elements(:,4),:))/4;
for k=1:size(elements,1)
    p=centroids(k,:); typ=component(k);
    if typ==1
        isHaz=p(3)<=g.bottomThickness+c.haz.webWidth || p(3)>=h-g.topThickness-c.haz.webWidth;
    elseif typ==2 || typ==3
        isHaz=abs(p(1))<=g.webThickness/2+c.haz.flangeWidth;
    else
        isHaz=abs(p(1))<=g.webThickness/2+c.haz.stiffenerWidth || ...
            p(3)<=g.bottomThickness+c.haz.stiffenerWidth || p(3)>=h-g.topThickness-c.haz.stiffenerWidth;
    end
    if typ~=4
        for j=1:numel(c.stiffeners)
            s=c.stiffeners(j);
            near=abs(p(2)-s.position)<=s.thickness/2+c.haz.stiffenerWidth;
            onSide=p(1)*s.side>=0 && abs(p(1))<=s.width;
            if near && (typ==1 || onSide), isHaz=true; end
        end
    end
    material(k)=2*typ-1+isHaz;
    for j=1:numel(c.regions)
        r=c.regions(j);
        if (r.component==0 || r.component==typ) && all(p>=r.bounds(:,1)') && all(p<=r.bounds(:,2)')
            material(k)=r.material;
        end
    end
end
tol=1e-8;
left=find(abs(nodes(:,2))<tol & abs(nodes(:,3)-zb)<tol);
right=find(abs(nodes(:,2)-L)<tol & abs(nodes(:,3)-zb)<tol);
loadNodes=find(abs(nodes(:,2)-L/2)<tol & abs(nodes(:,3)-zt)<tol);
% Two lateral guides remove lateral translation/yaw; a single axial anchor
% allows the roller end to move longitudinally. Vertical bearing lines hold
% the flange level across its width, providing torsional restraint there.
anchor=find(abs(nodes(:,1))<tol & abs(nodes(:,2))<tol & abs(nodes(:,3)-zb)<tol);
guide=find(abs(nodes(:,1))<tol & abs(nodes(:,2)-L)<tol & abs(nodes(:,3)-zb)<tol);
loadGuide=find(abs(nodes(:,1))<tol & abs(nodes(:,2)-L/2)<tol & abs(nodes(:,3)-zt)<tol);
assert(numel(anchor)==1 && numel(guide)==1 && numel(loadGuide)==1,'Guide nodes missing.');
assert(all(cellfun(@numel,{left,right,loadNodes})>=3),'Bearing lines require at least three nodes.');
nodes(:,1)=nodes(:,1)+c.imperfection*sin(pi*nodes(:,2)/L);
% Reject disconnected or degenerate shells before writing an input file.
v1=nodes(elements(:,2),:)-nodes(elements(:,1),:);
v2=nodes(elements(:,4),:)-nodes(elements(:,1),:);
assert(all(vecnorm(cross(v1,v2,2),2,2)>1e-10),'Degenerate shell element.');
edges=[elements(:,[1 2]);elements(:,[2 3]);elements(:,[3 4]);elements(:,[4 1])];
G=graph(edges(:,1),edges(:,2));
assert(max(conncomp(G))==1,'Mesh contains disconnected plates.');
if ~exist(c.outputDir,'dir'), mkdir(c.outputDir); end
path=fullfile(c.outputDir,[c.name '.inp']);
fid=fopen(path,'w'); assert(fid>=0,'Cannot open output file.');
closer=onCleanup(@() fclose(fid));
fprintf(fid,'*HEADING\nWelded aluminum I-section, idealized three-point bending, N mm MPa\n');
fprintf(fid,'** Example materials must be replaced with measured alloy/HAZ data.\n');
fprintf(fid,'*NODE, NSET=BEAM_NODES\n');
fprintf(fid,'%d, %.12g, %.12g, %.12g\n',[(1:size(nodes,1))' nodes]');
rp=size(nodes,1)+(1:3);
fprintf(fid,'*NODE\n');
fprintf(fid,'%d, 0, 0, %.12g\n',rp(1),zb);
fprintf(fid,'%d, 0, %.12g, %.12g\n',rp(2),L,zb);
fprintf(fid,'%d, %.12g, %.12g, %.12g\n',rp(3),c.imperfection,L/2,zt);
fprintf(fid,'*ELEMENT, TYPE=S4R, ELSET=ALL_SHELLS\n');
fprintf(fid,'%d, %d, %d, %d, %d\n',[(1:size(elements,1))' elements]');
% One section per plate/material pair keeps different stiffener thicknesses.
groups=unique([plate material],'rows');
for k=1:size(groups,1)
    ids=find(plate==groups(k,1) & material==groups(k,2));
    setname=sprintf('PLATE_%d_MAT_%d',groups(k,1),groups(k,2));
    writeSet('ELSET',setname,ids);
    fprintf(fid,'*SHELL SECTION, ELSET=%s, MATERIAL=%s\n%.12g, 5\n', ...
        setname,c.materials(groups(k,2)).name,thickness(ids(1)));
end
for k=1:numel(c.materials)
    m=c.materials(k);
    fprintf(fid,'*MATERIAL, NAME=%s\n*ELASTIC\n%.12g, %.12g\n',m.name,m.E,m.nu);
    if ~isempty(m.plastic)
        fprintf(fid,'*PLASTIC\n'); fprintf(fid,'%.12g, %.12g\n',m.plastic');
    end
end
writeSet('NSET','LEFT_BEARING',left); writeSet('NSET','RIGHT_BEARING',right);
writeSet('NSET','LOAD_LINE',loadNodes); writeSet('NSET','RP_LEFT',rp(1));
writeSet('NSET','RP_RIGHT',rp(2)); writeSet('NSET','RP_LOAD',rp(3));
writeSet('NSET','AXIAL_ANCHOR',anchor); writeSet('NSET','LATERAL_GUIDES',[anchor;guide]);
if c.lateralGuideAtLoad, writeSet('NSET','LOAD_GUIDE',loadGuide); end
labels={'LEFT_BEARING','RIGHT_BEARING','LOAD_LINE'};
refs={'RP_LEFT','RP_RIGHT','RP_LOAD'};
for k=1:3
    fprintf(fid,'*SURFACE, TYPE=NODE, NAME=SURF_%d\n%s, 1.\n',k,labels{k});
    fprintf(fid,'*COUPLING, CONSTRAINT NAME=BEARING_%d, REF NODE=%s, SURFACE=SURF_%d\n*KINEMATIC\n3, 3\n',k,refs{k},k);
end
fprintf(fid,'*BOUNDARY\n');
for k=1:3
    % Fix inactive RP motions; U3 remains the bearing/loading degree of freedom.
    fprintf(fid,'%s, 1, 2\n%s, 4, 6\n',refs{k},refs{k});
end
fprintf(fid,'RP_LEFT, 3, 3\nRP_RIGHT, 3, 3\nAXIAL_ANCHOR, 2, 2\nLATERAL_GUIDES, 1, 1\n');
if c.lateralGuideAtLoad, fprintf(fid,'LOAD_GUIDE, 1, 1\n'); end
a=c.analysis;
fprintf(fid,'*STEP, NAME=THREE_POINT_BENDING, NLGEOM=YES, INC=%d\n*STATIC\n',a.maximumIncrements);
fprintf(fid,'%.12g, 1., %.12g, %.12g\n',a.initialIncrement,a.minimumIncrement,a.maximumIncrement);
fprintf(fid,'*BOUNDARY\nRP_LOAD, 3, 3, %.12g\n',-a.displacement);
fprintf(fid,'*OUTPUT, FIELD, FREQUENCY=1\n*NODE OUTPUT\nU, RF\n*ELEMENT OUTPUT\nS, LE, PEEQ\n');
fprintf(fid,'*OUTPUT, HISTORY, FREQUENCY=1\n');
for k=1:3, fprintf(fid,'*NODE OUTPUT, NSET=%s\nU3, RF3\n',refs{k}); end
fprintf(fid,'*END STEP\n');
clear closer;
model=struct('nodes',nodes,'elements',elements,'component',component, ...
    'plate',plate,'material',material,'thickness',thickness,'config',c,'inputFile',path);
save(fullfile(c.outputDir,[c.name '_mesh.mat']),'model');
T=table((1:size(elements,1))',plate,component,material,thickness, ...
    'VariableNames',{'Element','Plate','Component','Material','Thickness'});
writetable(T,fullfile(c.outputDir,[c.name '_regions.csv']));
fprintf('Generated %s\n%d nodes, %d shells, %d stiffener plates.\n',path,size(nodes,1),size(elements,1),numel(c.stiffeners));
fprintf('Run from output folder: abaqus job=%s input=%s.inp interactive\n',c.name,c.name);
if c.preview
    figure('Name','Aluminum 3PB material regions');
    patch('Faces',elements,'Vertices',nodes,'FaceVertexCData',material, ...
        'FaceColor','flat','EdgeColor',[.4 .4 .4]);
    axis equal; view(35,25); xlabel('x (mm)'); ylabel('y (mm)'); zlabel('z (mm)');
    colorbar; title('Material index: base / HAZ / custom regions');
end

    function addPlate(typ,orientation,fixed,u,v,t,id)
        [uu,vv]=ndgrid(u,v);
        switch orientation
            case 1, xyz=[zeros(numel(uu),1)+fixed uu(:) vv(:)];
            case 2, xyz=[uu(:) vv(:) zeros(numel(uu),1)+fixed];
            case 3, xyz=[uu(:) zeros(numel(uu),1)+fixed vv(:)];
        end
        offset=size(raw,1); raw=[raw;xyz];
        [ii,jj]=ndgrid(1:numel(u)-1,1:numel(v)-1);
        n=offset+ii(:)+(jj(:)-1)*numel(u);
        e=[n n+1 n+1+numel(u) n+numel(u)];
        conn=[conn;e]; count=size(e,1);
        component=[component;repmat(typ,count,1)];
        plate=[plate;repmat(id,count,1)]; thickness=[thickness;repmat(t,count,1)];
    end
    function writeSet(kind,name,ids)
        fprintf(fid,'*%s, %s=%s\n',kind,kind,name);
        for q=1:16:numel(ids)
            row=ids(q:min(q+15,numel(ids)));
            fprintf(fid,'%d',row(1)); fprintf(fid,', %d',row(2:end)); fprintf(fid,'\n');
        end
    end
end

function x=gridline(lo,hi,breaks,target)
breaks=unique([lo hi breaks(breaks>lo & breaks<hi)]);
x=breaks(1);
for k=1:numel(breaks)-1
    part=linspace(breaks(k),breaks(k+1),max(1,ceil((breaks(k+1)-breaks(k))/target))+1);
    x=[x part(2:end)]; %#ok<AGROW>
end
end

function validateConfig(c)
g=c.geometry; vals=struct2array(g);
assert(all(isfinite(vals)) && all(vals>0),'Geometry must be finite and positive.');
assert(g.height>g.topThickness+g.bottomThickness,'No clear web height.');
assert(min(g.topWidth,g.bottomWidth)>g.webThickness,'Flanges must be wider than web.');
assert(isscalar(c.meshSize) && isfinite(c.meshSize) && c.meshSize>0,'Invalid mesh size.');
assert(all(isfinite(struct2array(c.haz))) && all(struct2array(c.haz)>=0),'Invalid HAZ widths.');
assert(isfinite(c.imperfection) && isscalar(c.imperfection),'Invalid imperfection.');
assert(~isempty(regexp(c.name,'^[A-Za-z][A-Za-z0-9_]*$','once')),'Use an alphanumeric job name.');
assert(numel(c.materials)>=8,'Provide the eight base/HAZ component materials.');
for k=1:numel(c.materials)
    m=c.materials(k); p=m.plastic;
    assert(isfinite(m.E) && m.E>0 && isfinite(m.nu) && m.nu>-1 && m.nu<.5,'Invalid elastic constants.');
    assert(~isempty(regexp(m.name,'^[A-Za-z][A-Za-z0-9_]*$','once')),'Invalid material name.');
    assert(isempty(p) || (size(p,2)==2 && all(isfinite(p(:))) && all(p(:,1)>0) && ...
        p(1,2)==0 && all(diff(p(:,2))>0) && all(diff(p(:,1))>=0)), ...
        'Plastic data must be [true stress, plastic strain], start at zero and increase.');
end
assert(numel(unique(lower(string({c.materials.name}))))==numel(c.materials),'Material names must be unique.');
for k=1:numel(c.stiffeners)
    s=c.stiffeners(k);
    assert(all(isfinite([s.position s.side s.width s.thickness])) && ...
        s.position>=0 && s.position<=g.length && ismember(s.side,[-1 1]) && ...
        s.width>g.webThickness/2 && s.width<=min(g.topWidth,g.bottomWidth)/2 && s.thickness>0, ...
        'Invalid stiffener: check position, side, width, thickness.');
    for j=1:k-1
        t=c.stiffeners(j);
        assert(s.side~=t.side || abs(s.position-t.position)>(s.thickness+t.thickness)/2, ...
            'Same-side stiffeners overlap.');
    end
end
for k=1:numel(c.regions)
    r=c.regions(k);
    assert(isequal(size(r.bounds),[3 2]) && ~any(isnan(r.bounds(:))) && ...
        all(r.bounds(:,1)<r.bounds(:,2)) && ismember(r.component,0:4) && ...
        ismember(r.material,1:numel(c.materials)),'Invalid custom region.');
end
a=c.analysis;
assert(all(isfinite(struct2array(a))) && a.displacement>0 && a.minimumIncrement>0 && ...
    a.minimumIncrement<=a.initialIncrement && a.initialIncrement<=a.maximumIncrement && ...
    a.maximumIncrement<=1 && a.maximumIncrements>=1 && mod(a.maximumIncrements,1)==0,'Invalid analysis controls.');
end
