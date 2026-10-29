function c = read_aluminum_3pb_excel(filename)
% Read Aluminum_3PB_Input.xlsx without requiring Excel to be installed.
if nargin==0, filename=fullfile(fileparts(mfilename('fullpath')),'Aluminum_3PB_Input.xlsx'); end
assert(isfile(filename),'Input workbook not found: %s',filename);
[ok,info]=fileattrib(filename); assert(ok,'Cannot resolve workbook path.');
folder=fileparts(info.Name);
c=aluminum_welded_3pb_config();
control=keySheet('Control',{'name','outputDir','meshSize','imperfection','lateralGuideAtLoad','preview'});
c.name=asText(control{1},'Control.name');
out=asText(control{2},'Control.outputDir');
if isempty(regexp(out,'^([A-Za-z]:[\\/]|[\\/])','once')), out=fullfile(folder,out); end
c.outputDir=out;
c.meshSize=asNumber(control{3},'Control.meshSize');
c.imperfection=asNumber(control{4},'Control.imperfection');
c.lateralGuideAtLoad=asFlag(control{5},'Control.lateralGuideAtLoad');
c.preview=asFlag(control{6},'Control.preview');
c.geometry=readFields('Geometry',c.geometry);
c.haz=readFields('HAZ',c.haz);
c.analysis=readFields('Analysis',c.analysis);

r=sheet('Stiffeners',{'Enabled','Position','Side','Width','Thickness'});
c.stiffeners=c.stiffeners([]);
for i=2:size(r,1)
    if blankRow(r(i,:)), continue; end
    if ~asFlag(r{i,1},sprintf('Stiffeners row %d Enabled',i)), continue; end
    c.stiffeners(end+1)=struct('position',asNumber(r{i,2},'Stiffener Position'), ...
        'side',asNumber(r{i,3},'Stiffener Side'),'width',asNumber(r{i,4},'Stiffener Width'), ...
        'thickness',asNumber(r{i,5},'Stiffener Thickness')); %#ok<AGROW>
end
r=sheet('Materials',{'ID','Name','E','Nu','UsePlastic'});
c.materials=c.materials([]); ids=[]; usePlastic=[];
for i=2:size(r,1)
    if blankRow(r(i,:)), continue; end
    id=asNumber(r{i,1},'Material ID');
    assert(id>=1 && fix(id)==id && ~ismember(id,ids),'Material IDs must be unique positive integers.');
    ids(end+1)=id; %#ok<AGROW>
    c.materials(end+1)=struct('name',asText(r{i,2},'Material Name'), ...
        'E',asNumber(r{i,3},'Material E'),'nu',asNumber(r{i,4},'Material Nu'),'plastic',zeros(0,2)); %#ok<AGROW>
    usePlastic(end+1)=asFlag(r{i,5},'Material UsePlastic'); %#ok<AGROW>
end
assert(numel(ids)>=8 && isequal(sort(ids),1:numel(ids)),'Material IDs must be contiguous 1..N, with at least 8 materials.');
[~,order]=sort(ids); c.materials=c.materials(order); usePlastic=usePlastic(order);
r=sheet('Plastic',{'MaterialID','TrueStress','PlasticStrain'});
for i=2:size(r,1)
    if blankRow(r(i,:)), continue; end
    id=asNumber(r{i,1},'Plastic MaterialID');
    assert(ismember(id,ids),'Plastic row %d refers to unknown material ID.',i);
    point=[asNumber(r{i,2},'TrueStress') asNumber(r{i,3},'PlasticStrain')];
    if usePlastic(id), c.materials(id).plastic(end+1,:)=point; end
end
for id=1:numel(c.materials)
    assert(~usePlastic(id) || ~isempty(c.materials(id).plastic),'Material %d has UsePlastic=1 but no Plastic rows.',id);
end
r=sheet('Regions',{'Enabled','Component','Xmin','Xmax','Ymin','Ymax','Zmin','Zmax','MaterialID'});
c.regions=c.regions([]);
for i=2:size(r,1)
    if blankRow(r(i,:)), continue; end
    if ~asFlag(r{i,1},sprintf('Regions row %d Enabled',i)), continue; end
    bounds=zeros(3,2);
    for a=1:3
        bounds(a,1)=bound(r{i,2*a+1},-inf);
        bounds(a,2)=bound(r{i,2*a+2},inf);
    end
    c.regions(end+1)=struct('component',asNumber(r{i,2},'Region Component'), ...
        'bounds',bounds,'material',asNumber(r{i,9},'Region MaterialID')); %#ok<AGROW>
end

    function data=sheet(name,headers)
        data=readcell(filename,'Sheet',name,'UseExcel',false);
        assert(size(data,2)>=numel(headers),'Sheet %s has missing columns.',name);
        data=data(:,1:numel(headers));
        for j=1:numel(headers)
            assert(strcmp(asText(data{1,j},[name ' header']),headers{j}), ...
                'Sheet %s column %d must be named %s.',name,j,headers{j});
        end
    end
    function values=keySheet(name,keys)
        data=sheet(name,{'Parameter','Value'}); values=cell(size(keys)); seen=false(size(keys));
        for row=2:size(data,1)
            if blankRow(data(row,:)), continue; end
            key=asText(data{row,1},[name ' Parameter']); idx=find(strcmp(keys,key));
            assert(numel(idx)==1,'Unknown parameter %s in sheet %s.',key,name);
            assert(~seen(idx),'Duplicate parameter %s in sheet %s.',key,name);
            values{idx}=data{row,2}; seen(idx)=true;
        end
        assert(all(seen),'Sheet %s is missing required parameters.',name);
    end
    function s=readFields(name,s)
        keys=fieldnames(s); values=keySheet(name,keys);
        for j=1:numel(keys), s.(keys{j})=asNumber(values{j},[name '.' keys{j}]); end
    end
end

function yes=blank(v)
yes=isempty(v) || (isscalar(v) && ismissing(v)) || ...
    ((ischar(v) || isstring(v)) && strlength(strtrim(string(v)))==0);
end
function yes=blankRow(row)
yes=all(cellfun(@blank,row));
end
function s=asText(v,label)
assert(~blank(v) && (ischar(v) || (isstring(v) && isscalar(v))), '%s must contain text.',label);
s=char(strtrim(string(v)));
assert(~contains(s,newline) && ~contains(s,char(13)),'%s must be a single line.',label);
end
function n=asNumber(v,label)
if ischar(v) || isstring(v), v=str2double(v); end
assert((isnumeric(v) || islogical(v)) && isscalar(v) && isfinite(v),'%s must contain a finite number.',label);
n=double(v);
end
function f=asFlag(v,label)
n=asNumber(v,label); assert(ismember(n,[0 1]),'%s must be 0 or 1.',label); f=logical(n);
end
function n=bound(v,fallback)
if blank(v), n=fallback; return; end
if ischar(v) || isstring(v), v=str2double(v); end
assert(isnumeric(v) && isscalar(v) && ~isnan(v),'Region bounds must be numeric or blank.');
n=double(v);
end
