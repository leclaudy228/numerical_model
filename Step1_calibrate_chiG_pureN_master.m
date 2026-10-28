%% =========================================================
%  Step1_calibrate_chiG_pureN_master.m
%
%  MASTER chi_G calibration code for pure compression
%  Reads user settings from Excel CONTROL_PANEL sheet
%
%  RAW FE DATABASE:
%     Workbook : Parametric study_Prachi_Online_Redo.xlsm
%     Sheet    : OIC-N-Prachi
%     Range    : A:T   (treated as frozen raw data)
%
%  CONTROL PANEL:
%     Sheet    : CONTROL_PANEL
%     Reads user choices from column C
%
%  OUTPUTS:
%     - .mat master result file
%     - .csv candidate tables
%     - .csv retained tables
%     - .png plots
%
%  IMPORTANT:
%     This script does NOT write back to Excel.
%% =========================================================

clear; clc; close all;

%% =========================================================
% FIXED FILE/SHEET NAMES
%% =========================================================
fileName      = 'Parametric study_Prachi_Online_Redo.xlsm';
rawSheetName  = 'OIC-N-Prachi';
controlSheet  = 'CONTROL_PANEL';   % <-- change only if your control sheet name is different
rowStart      = 4;

%% =========================================================
% READ CONTROL PANEL
%% =========================================================
settings = readControlPanel(fileName, controlSheet);

fprintf('\n=====================================================\n');
fprintf('STEP 1: chi_G CALIBRATION (PURE N MASTER)\n');
fprintf('=====================================================\n');
fprintf('Workbook      : %s\n', fileName);
fprintf('Raw FE sheet  : %s\n', rawSheetName);
fprintf('Control sheet : %s\n', controlSheet);
fprintf('Model family  : %s\n', settings.modelFamily);
fprintf('Grouping      : %s\n', settings.grouping);
fprintf('Row selection : %s\n', settings.rowSelection);
fprintf('Fit goal      : %s\n', settings.fitGoal);
fprintf('AP fit mode   : %s\n', settings.AP.fitMode);
fprintf('Delta_G       : %.4f\n', settings.deltaG);
fprintf('Lambda0 list  : %s\n', mat2str(settings.lambda0Trials));
fprintf('Practical rng : [%.3f  %.3f]\n', settings.practicalRange(1), settings.practicalRange(2));
fprintf('Weight pract. : %.3f\n', settings.weightPractical);
fprintf('=====================================================\n\n');

%% =========================================================
% READ RAW FE DATABASE (A:T ONLY)
%% =========================================================

% detect last used row from column A
colA = readcell(fileName, 'Sheet', rawSheetName, 'Range', 'A:A');
lastRow = find(~cellfun(@(x) isempty(x) || (ischar(x) && all(isspace(x))), colA), 1, 'last');

if isempty(lastRow) || lastRow < rowStart
    error('Could not detect valid data rows in column A.');
end

% read raw numeric block A:T
dataRange = sprintf('A%d:T%d', rowStart, lastRow);
numData   = readmatrix(fileName, 'Sheet', rawSheetName, 'Range', dataRange);

% read alloy text from D and row type text from T
alloyRaw = readcell(fileName, 'Sheet', rawSheetName, ...
    'Range', sprintf('D%d:D%d', rowStart, lastRow));
typeRaw = readcell(fileName, 'Sheet', rawSheetName, ...
    'Range', sprintf('T%d:T%d', rowStart, lastRow));

% trim fully empty numeric rows
isUsedRow = ~all(isnan(numData), 2);
numData   = numData(isUsedRow, :);
alloyRaw  = alloyRaw(isUsedRow, :);
typeRaw   = typeRaw(isUsedRow, :);

% column mapping inside A:T
col_caseNo   = 1;   % A
col_lambdaG  = 6;   % F
col_chiG_FE  = 8;   % H

caseNo  = numData(:, col_caseNo);
lambdaG = numData(:, col_lambdaG);
chiG_FE = numData(:, col_chiG_FE);

alloy = normalizeTextColumn(alloyRaw);
rowType = upper(normalizeTextColumn(typeRaw));

% raw mask
mask = ~isnan(caseNo) & ~isnan(lambdaG) & ~isnan(chiG_FE) & ...
       lambdaG > 0 & chiG_FE > 0 & alloy ~= "";

% row selection
switch lower(settings.rowSelection)
    case 'shell_and_beam'
        % keep both
    case 'shell_only'
        mask = mask & (rowType == "SHELL");
    case 'beam_only'
        mask = mask & (rowType == "BEAM");
    otherwise
        error('Unknown row selection: %s', settings.rowSelection);
end

caseNo   = caseNo(mask);
lambdaG  = lambdaG(mask);
chiG_FE  = chiG_FE(mask);
alloy    = alloy(mask);
rowType  = rowType(mask);

fprintf('Usable rows after masking = %d\n', numel(caseNo));
fprintf('  Shell rows = %d\n', sum(rowType == "SHELL"));
fprintf('  Beam rows  = %d\n\n', sum(rowType == "BEAM"));

%% =========================================================
% BUILD GROUPING SCENARIOS
%% =========================================================
scenarios = buildScenarios(settings.grouping);

%% =========================================================
% RUN CALIBRATION
%% =========================================================
allScenarioResults = repmat(struct( ...
    'name', "", ...
    'groupNames', [], ...
    'groupMembers', [], ...
    'candidateTable', table(), ...
    'candidateTableSorted', table(), ...
    'retainedTable', table(), ...
    'curveStore', struct([])), numel(scenarios), 1);

for s = 1:numel(scenarios)
    fprintf('\n=====================================================\n');
    fprintf('SCENARIO: %s\n', scenarios(s).name);
    fprintf('=====================================================\n');

    allScenarioResults(s) = runScenario( ...
        settings, scenarios(s), caseNo, lambdaG, chiG_FE, alloy, rowType);

    fprintf('\nSorted candidate table for %s:\n', scenarios(s).name);
    disp(allScenarioResults(s).candidateTableSorted);

    fprintf('\nRetained top candidate per group for %s:\n', scenarios(s).name);
    disp(allScenarioResults(s).retainedTable);

    baseName = sprintf('Step1_ChiG_%s_%s', ...
        regexprep(settings.outputTag, '[^\w]', '_'), ...
        regexprep(char(scenarios(s).name), '[^\w]', '_'));

    writetable(allScenarioResults(s).candidateTableSorted, [baseName '_candidates.csv']);
    writetable(allScenarioResults(s).retainedTable,        [baseName '_retained.csv']);

    figName = [baseName '.png'];
    plotScenario(allScenarioResults(s), settings, figName);
    fprintf('Saved figure to: %s\n', figName);
end

%% =========================================================
% SAVE MASTER RESULTS
%% =========================================================
results.fileName      = fileName;
results.rawSheetName  = rawSheetName;
results.controlSheet  = controlSheet;
results.settings      = settings;
results.scenarios     = allScenarioResults;

results.raw.caseNo    = caseNo;
results.raw.lambdaG   = lambdaG;
results.raw.chiG_FE   = chiG_FE;
results.raw.alloy     = alloy;
results.raw.rowType   = rowType;

matName = sprintf('Step1_ChiG_%s_results.mat', regexprep(settings.outputTag, '[^\w]', '_'));
save(matName, 'results');

fprintf('\nSaved MAT file to: %s\n', matName);

%% =========================================================
% LOCAL FUNCTIONS
%% =========================================================

function settings = readControlPanel(fileName, controlSheet)

    % -------- Section 1: chi_G calibration --------
    settings.modelFamily    = getTextCell(fileName, controlSheet, 'C2', 'ModifiedAP');
    settings.grouping       = getTextCell(fileName, controlSheet, 'C3', 'separate');
    settings.rowSelection   = getTextCell(fileName, controlSheet, 'C4', 'shell_and_beam');
    settings.fitGoal        = getTextCell(fileName, controlSheet, 'C5', 'design');
    settings.AP.fitMode     = getTextCell(fileName, controlSheet, 'C6', 'free_alpha_lambda0');

    settings.deltaG         = getNumCell(fileName, controlSheet, 'C7', 2.0);
    settings.lambda0Trials  = parseNumericList(fileName, controlSheet, 'C8', [0.08 0.10 0.12 0.15]);
    settings.practicalRange = [ ...
        getNumCell(fileName, controlSheet, 'C9', 0.30), ...
        getNumCell(fileName, controlSheet, 'C10', 1.50)];
    settings.weightPractical = getNumCell(fileName, controlSheet, 'C11', 2.0);

    % -------- Keep calibration defaults --------
    settings.chiFitLimit = 1.05;

    % AP settings
    settings.AP.alphaBounds   = [0.01 0.50];
    settings.AP.lambda0Bounds = [0.00 0.30];
    settings.AP.lambda0Fixed  = 0.00;

    settings.AP.alphaSeeds    = [0.05 0.10 0.15 0.20 0.30 0.40];
    settings.AP.lambda0Seeds  = [0.00 0.05 0.10 0.15];

    % for alpha_lambda0_fixed mode, use the control panel lambda0 trials
    settings.AP.fixedLambda0Trials = settings.lambda0Trials;

    % % Modified AP settings
    % settings.ModAP.lambda0Trials = settings.lambda0Trials;
    % settings.ModAP.alphaBounds   = [0.01 3.00];
    % settings.ModAP.betaBounds    = [0.80 1.20];
    % settings.ModAP.alphaSeeds    = [0.05 0.10 0.15 0.20 0.30 0.40];
    % settings.ModAP.betaSeeds     = [0.80 0.85 0.90 0.95 1.00 1.10];
    % settings.ModAP.useSecondCap  = true;
    % 
    % % design penalty settings
    % settings.designPenalty.wNgt100      = 15;
    % settings.designPenalty.wNgt103      = 60;
    % settings.designPenalty.wNgt110      = 300;
    % settings.designPenalty.wMaxExcess   = 400;
    % settings.designPenalty.maxRef       = 1.03;
    % settings.designPenalty.wMeanBelow   = 4000;
    % settings.designPenalty.targetMeanLo = 0.95;
    % settings.designPenalty.wMeanAbove   = 6000;
    % settings.designPenalty.targetMeanHi = 1.00;
    % settings.designPenalty.wCov         = 10;

% Modified AP settings
settings.ModAP.lambda0Trials = settings.lambda0Trials;
settings.ModAP.alphaBounds   = [0.01 3.00];

settings.ModAP.betaBounds = [ ...
    getNumCell(fileName, controlSheet, 'C12', 0.70), ...
    getNumCell(fileName, controlSheet, 'C13', 1.00)];

settings.ModAP.alphaSeeds    = [0.05 0.10 0.15 0.20 0.30 0.40];

settings.ModAP.betaSeeds = parseNumericList(fileName, controlSheet, 'C14', ...
    [0.70 0.75 0.80 0.85 0.90 0.95 1.00]);

settings.ModAP.useSecondCap  = true;

% design penalty settings
settings.designPenalty.wNgt100      = 2;
settings.designPenalty.wNgt103      = 25;
settings.designPenalty.wNgt110      = 250;
settings.designPenalty.wMaxExcess   = 150;
settings.designPenalty.maxRef       = 1.05;
settings.designPenalty.wMeanBelow   = 8000;
settings.designPenalty.targetMeanLo = 0.98;
settings.designPenalty.wMeanAbove   = 7000;
settings.designPenalty.targetMeanHi = 1.005;
settings.designPenalty.wCov         = 8;


    settings.outputTag = sprintf('pureN_%s_%s_%s', ...
        settings.modelFamily, settings.grouping, settings.fitGoal);
end

function txt = getTextCell(fileName, sheetName, cellRef, defaultVal)
    raw = readcell(fileName, 'Sheet', sheetName, 'Range', cellRef);
    if isempty(raw) || isempty(raw{1})
        txt = string(defaultVal);
    else
        txt = strip(string(raw{1}));
        if strlength(txt) == 0
            txt = string(defaultVal);
        end
    end
end

function val = getNumCell(fileName, sheetName, cellRef, defaultVal)
    raw = readcell(fileName, 'Sheet', sheetName, 'Range', cellRef);
    if isempty(raw) || isempty(raw{1})
        val = defaultVal;
        return;
    end

    x = raw{1};
    if isnumeric(x) && ~isnan(x)
        val = x;
    else
        x = strtrim(string(x));
        num = str2double(x);
        if isnan(num)
            val = defaultVal;
        else
            val = num;
        end
    end
end

function vals = parseNumericList(fileName, sheetName, cellRef, defaultVals)
    raw = readcell(fileName, 'Sheet', sheetName, 'Range', cellRef);

    if isempty(raw) || isempty(raw{1})
        vals = defaultVals;
        return;
    end

    x = raw{1};

    if isnumeric(x) && ~isnan(x)
        vals = x;
        return;
    end

    txt = strtrim(string(x));
    if strlength(txt) == 0
        vals = defaultVals;
        return;
    end

    parts = split(txt, ',');
    vals = nan(1, numel(parts));
    for i = 1:numel(parts)
        vals(i) = str2double(strtrim(parts(i)));
    end
    vals = vals(~isnan(vals));

    if isempty(vals)
        vals = defaultVals;
    end
end

function txt = normalizeTextColumn(raw)
    txt = strings(size(raw));
    for i = 1:numel(raw)
        if ischar(raw{i}) || isstring(raw{i})
            txt(i) = strip(string(raw{i}));
        elseif isnumeric(raw{i}) && ~isnan(raw{i})
            txt(i) = string(raw{i});
        else
            txt(i) = "";
        end
    end
end

function scenarios = buildScenarios(grouping)
    switch lower(grouping)
        case 'separate'
            scenarios(1).name = "Separate alloys";
            scenarios(1).groupNames   = ["6061-T6","6063-T6","6082-T6"];
            scenarios(1).groupMembers = {["6061-T6"], ["6063-T6"], ["6082-T6"]};

        case 'merge6061_6082'
            scenarios(1).name = "Merged 6061+6082";
            scenarios(1).groupNames   = ["6061-T6 + 6082-T6","6063-T6"];
            scenarios(1).groupMembers = {["6061-T6","6082-T6"], ["6063-T6"]};

        case 'both'
            scenarios(1).name = "Separate alloys";
            scenarios(1).groupNames   = ["6061-T6","6063-T6","6082-T6"];
            scenarios(1).groupMembers = {["6061-T6"], ["6063-T6"], ["6082-T6"]};

            scenarios(2).name = "Merged 6061+6082";
            scenarios(2).groupNames   = ["6061-T6 + 6082-T6","6063-T6"];
            scenarios(2).groupMembers = {["6061-T6","6082-T6"], ["6063-T6"]};

        otherwise
            error('Unknown grouping option: %s', grouping);
    end
end

function scenRes = runScenario(settings, oneScenario, caseNo, lambdaG, chiG_FE, alloy, rowType)

    groupNames   = oneScenario.groupNames;
    groupMembers = oneScenario.groupMembers;

    candidateRows = [];
    curveStore = struct([]);
    rowCounter = 0;
    curveCounter = 0;

    lambdaCurve = linspace(0.001, max([3; lambdaG])*1.02, 500).';

    for g = 1:numel(groupNames)
        idxGroup = ismember(alloy, groupMembers{g});

        lam_all  = lambdaG(idxGroup);
        chi_all  = chiG_FE(idxGroup);
        type_all = rowType(idxGroup);
        case_all = caseNo(idxGroup);

        fitMask = chi_all <= settings.chiFitLimit;
        lam_fit = lam_all(fitMask);
        chi_fit = chi_all(fitMask);

        fprintf('\n--- Group: %s ---\n', groupNames(g));
        fprintf('Total rows = %d | Shell = %d | Beam = %d\n', ...
            numel(lam_all), sum(type_all=="SHELL"), sum(type_all=="BEAM"));

        switch lower(settings.modelFamily)
            case 'ap'
                [candidateRows, curveStore, rowCounter, curveCounter] = ...
                    runAPGroup(settings, groupNames(g), lam_all, chi_all, type_all, case_all, ...
                               lam_fit, chi_fit, lambdaCurve, candidateRows, curveStore, rowCounter, curveCounter);

            case 'modifiedap'
                [candidateRows, curveStore, rowCounter, curveCounter] = ...
                    runModifiedAPGroup(settings, groupNames(g), lam_all, chi_all, type_all, case_all, ...
                                       lam_fit, chi_fit, lambdaCurve, candidateRows, curveStore, rowCounter, curveCounter);

            otherwise
                error('Unknown model family: %s', settings.modelFamily);
        end
    end

    candidateTable = struct2table(candidateRows);

    if strcmpi(settings.fitGoal, 'design')
        candidateTableSorted = sortrows(candidateTable, ...
            {'Ngt110_pr','Ngt103_pr','MaxUnsafeExcess_pr','AbsMeanShift_pr','COV_pr','ObjValue'}, ...
            {'ascend','ascend','ascend','ascend','ascend','ascend'});
    else
        candidateTableSorted = sortrows(candidateTable, ...
            {'ObjValue','COV_pr','AbsMeanShift_pr'}, ...
            {'ascend','ascend','ascend'});
    end

    % retain top candidate per group
    retainedTable = table();
    for g = 1:numel(groupNames)
        idx = find(candidateTableSorted.Group == groupNames(g), 1, 'first');
        if ~isempty(idx)
            retainedTable = [retainedTable; candidateTableSorted(idx,:)]; %#ok<AGROW>
        end
    end

    scenRes.name = oneScenario.name;
    scenRes.groupNames = groupNames;
    scenRes.groupMembers = groupMembers;
    scenRes.candidateTable = candidateTable;
    scenRes.candidateTableSorted = candidateTableSorted;
    scenRes.retainedTable = retainedTable;
    scenRes.curveStore = curveStore;
end

function [candidateRows, curveStore, rowCounter, curveCounter] = runAPGroup( ...
    settings, groupName, lam_all, chi_all, type_all, case_all, ...
    lam_fit, chi_fit, lambdaCurve, candidateRows, curveStore, rowCounter, curveCounter)

    fitMode = lower(settings.AP.fitMode);

    switch fitMode
        case 'alpha_only'
            lambda0Trials = settings.AP.lambda0Fixed;

        case 'alpha_lambda0_fixed'
            lambda0Trials = settings.AP.fixedLambda0Trials;

        case 'free_alpha_lambda0'
            lambda0Trials = NaN;

        otherwise
            error('Unknown AP fit mode: %s', settings.AP.fitMode);
    end

    if strcmpi(fitMode, 'free_alpha_lambda0')
        bestJ = inf; bestAlpha = NaN; bestLambda0 = NaN;

        lb = [settings.AP.alphaBounds(1), settings.AP.lambda0Bounds(1)];
        ub = [settings.AP.alphaBounds(2), settings.AP.lambda0Bounds(2)];

        for a0 = settings.AP.alphaSeeds
            for l0 = settings.AP.lambda0Seeds
                x0 = phys2free([a0 l0], lb, ub);
                obj = @(x) objectiveAP(x, lb, ub, settings, lam_fit, chi_fit, lam_all, chi_all);

                try
                    xOpt = fminsearch(obj, x0, optimset('Display','off', ...
                        'MaxFunEvals', 10000, 'MaxIter', 5000, 'TolX', 1e-10, 'TolFun', 1e-10));
                    [J, alphaOpt, lambda0Opt] = objectiveAP(xOpt, lb, ub, settings, lam_fit, chi_fit, lam_all, chi_all);

                    if J < bestJ
                        bestJ = J;
                        bestAlpha = alphaOpt;
                        bestLambda0 = lambda0Opt;
                    end
                catch
                end
            end
        end

        [candidateRows, curveStore, rowCounter, curveCounter] = appendCandidate( ...
            candidateRows, curveStore, rowCounter, curveCounter, ...
            settings, groupName, lam_all, chi_all, type_all, case_all, ...
            bestAlpha, NaN, bestLambda0, bestJ, lambdaCurve, 'AP');

    else
        for lambda0 = lambda0Trials
            bestJ = inf; bestAlpha = NaN;

            lb = settings.AP.alphaBounds(1);
            ub = settings.AP.alphaBounds(2);

            for a0 = settings.AP.alphaSeeds
                x0 = phys2free(a0, lb, ub);
                obj = @(x) objectiveAP_alphaOnly(x, lb, ub, settings, lambda0, lam_fit, chi_fit, lam_all, chi_all);

                try
                    xOpt = fminsearch(obj, x0, optimset('Display','off', ...
                        'MaxFunEvals', 10000, 'MaxIter', 5000, 'TolX', 1e-10, 'TolFun', 1e-10));
                    [J, alphaOpt] = objectiveAP_alphaOnly(xOpt, lb, ub, settings, lambda0, lam_fit, chi_fit, lam_all, chi_all);

                    if J < bestJ
                        bestJ = J;
                        bestAlpha = alphaOpt;
                    end
                catch
                end
            end

            [candidateRows, curveStore, rowCounter, curveCounter] = appendCandidate( ...
                candidateRows, curveStore, rowCounter, curveCounter, ...
                settings, groupName, lam_all, chi_all, type_all, case_all, ...
                bestAlpha, NaN, lambda0, bestJ, lambdaCurve, 'AP');
        end
    end
end

function [candidateRows, curveStore, rowCounter, curveCounter] = runModifiedAPGroup( ...
    settings, groupName, lam_all, chi_all, type_all, case_all, ...
    lam_fit, chi_fit, lambdaCurve, candidateRows, curveStore, rowCounter, curveCounter)

    for lambda0 = settings.ModAP.lambda0Trials
        bestJ = inf; bestAlpha = NaN; bestBeta = NaN;

        lb = [settings.ModAP.alphaBounds(1), settings.ModAP.betaBounds(1)];
        ub = [settings.ModAP.alphaBounds(2), settings.ModAP.betaBounds(2)];

        for a0 = settings.ModAP.alphaSeeds
            for b0 = settings.ModAP.betaSeeds
                x0 = phys2free([a0 b0], lb, ub);
                obj = @(x) objectiveModifiedAP(x, lb, ub, settings, lambda0, lam_fit, chi_fit, lam_all, chi_all);

                try
                    xOpt = fminsearch(obj, x0, optimset('Display','off', ...
                        'MaxFunEvals', 10000, 'MaxIter', 5000, 'TolX', 1e-10, 'TolFun', 1e-10));
                    [J, alphaOpt, betaOpt] = objectiveModifiedAP(xOpt, lb, ub, settings, lambda0, lam_fit, chi_fit, lam_all, chi_all);

                    if J < bestJ
                        bestJ = J;
                        bestAlpha = alphaOpt;
                        bestBeta  = betaOpt;
                    end
                catch
                end
            end
        end

        [candidateRows, curveStore, rowCounter, curveCounter] = appendCandidate( ...
            candidateRows, curveStore, rowCounter, curveCounter, ...
            settings, groupName, lam_all, chi_all, type_all, case_all, ...
            bestAlpha, bestBeta, lambda0, bestJ, lambdaCurve, 'ModifiedAP');
    end
end

function [candidateRows, curveStore, rowCounter, curveCounter] = appendCandidate( ...
    candidateRows, curveStore, rowCounter, curveCounter, ...
    settings, groupName, lam_all, chi_all, type_all, case_all, ...
    alpha, beta, lambda0, objValue, lambdaCurve, modelFamily)

    switch lower(modelFamily)
        case 'ap'
            chi_pred_all = chiG_AP(lam_all, alpha, lambda0, settings.deltaG);
            chi_curve    = chiG_AP(lambdaCurve, alpha, lambda0, settings.deltaG);

        case 'modifiedap'
            chi_pred_all = chiG_ModifiedAP(lam_all, alpha, beta, lambda0, settings.deltaG, settings.ModAP.useSecondCap);
            chi_curve    = chiG_ModifiedAP(lambdaCurve, alpha, beta, lambda0, settings.deltaG, settings.ModAP.useSecondCap);

        otherwise
            error('Unknown model family in appendCandidate.');
    end

    ratio_all = chi_pred_all ./ chi_all;
    prMask    = lam_all >= settings.practicalRange(1) & lam_all <= settings.practicalRange(2);
    ratio_pr  = ratio_all(prMask);

    statsAll = ratioStats(ratio_all);
    statsPr  = ratioStats(ratio_pr);

    rowCounter = rowCounter + 1;
    candidateRows(rowCounter).ModelFamily = string(modelFamily); %#ok<AGROW>
    candidateRows(rowCounter).Group       = string(groupName);
    candidateRows(rowCounter).Ncases      = numel(lam_all);
    candidateRows(rowCounter).Nshell      = sum(type_all=="SHELL");
    candidateRows(rowCounter).Nbeam       = sum(type_all=="BEAM");
    candidateRows(rowCounter).lambda0     = lambda0;
    candidateRows(rowCounter).alpha       = alpha;
    candidateRows(rowCounter).beta        = beta;
    candidateRows(rowCounter).delta       = settings.deltaG;
    candidateRows(rowCounter).ObjValue    = objValue;

    candidateRows(rowCounter).Mean_all    = statsAll.Mean;
    candidateRows(rowCounter).COV_all     = statsAll.COV;
    candidateRows(rowCounter).Max_all     = statsAll.Max;
    candidateRows(rowCounter).Min_all     = statsAll.Min;
    candidateRows(rowCounter).Ngt100_all  = statsAll.Ngt100;
    candidateRows(rowCounter).Ngt103_all  = statsAll.Ngt103;
    candidateRows(rowCounter).Ngt110_all  = statsAll.Ngt110;

    candidateRows(rowCounter).Mean_pr     = statsPr.Mean;
    candidateRows(rowCounter).COV_pr      = statsPr.COV;
    candidateRows(rowCounter).Max_pr      = statsPr.Max;
    candidateRows(rowCounter).Min_pr      = statsPr.Min;
    candidateRows(rowCounter).Ngt100_pr   = statsPr.Ngt100;
    candidateRows(rowCounter).Ngt103_pr   = statsPr.Ngt103;
    candidateRows(rowCounter).Ngt110_pr   = statsPr.Ngt110;
    candidateRows(rowCounter).MaxUnsafeExcess_pr = max(0, statsPr.Max - 1.0);
    candidateRows(rowCounter).AbsMeanShift_pr    = abs(statsPr.Mean - 1.0);

    curveCounter = curveCounter + 1;
    curveStore(curveCounter).Group       = char(groupName); %#ok<AGROW>
    curveStore(curveCounter).ModelFamily = char(modelFamily);
    curveStore(curveCounter).lambda0     = lambda0;
    curveStore(curveCounter).alpha       = alpha;
    curveStore(curveCounter).beta        = beta;
    curveStore(curveCounter).lambdaCurve = lambdaCurve;
    curveStore(curveCounter).chiCurve    = chi_curve;
    curveStore(curveCounter).lam_all     = lam_all;
    curveStore(curveCounter).chi_all     = chi_all;
    curveStore(curveCounter).type_all    = type_all;
    curveStore(curveCounter).case_all    = case_all;
end

function [J, alpha, lambda0] = objectiveAP(x, lb, ub, settings, lam_fit, chi_fit, lam_all, chi_all)
    p = free2phys(x, lb, ub);
    alpha   = p(1);
    lambda0 = p(2);

    chi_fit_pred = chiG_AP(lam_fit, alpha, lambda0, settings.deltaG);
    chi_all_pred = chiG_AP(lam_all, alpha, lambda0, settings.deltaG);

    J = buildObjective(settings, lam_fit, chi_fit, chi_fit_pred, lam_all, chi_all, chi_all_pred);
end

function [J, alpha] = objectiveAP_alphaOnly(x, lb, ub, settings, lambda0, lam_fit, chi_fit, lam_all, chi_all)
    alpha = free2phys(x, lb, ub);

    chi_fit_pred = chiG_AP(lam_fit, alpha, lambda0, settings.deltaG);
    chi_all_pred = chiG_AP(lam_all, alpha, lambda0, settings.deltaG);

    J = buildObjective(settings, lam_fit, chi_fit, chi_fit_pred, lam_all, chi_all, chi_all_pred);
end

function [J, alpha, beta] = objectiveModifiedAP(x, lb, ub, settings, lambda0, lam_fit, chi_fit, lam_all, chi_all)
    p = free2phys(x, lb, ub);
    alpha = p(1);
    beta  = p(2);

    chi_fit_pred = chiG_ModifiedAP(lam_fit, alpha, beta, lambda0, settings.deltaG, settings.ModAP.useSecondCap);
    chi_all_pred = chiG_ModifiedAP(lam_all, alpha, beta, lambda0, settings.deltaG, settings.ModAP.useSecondCap);

    J = buildObjective(settings, lam_fit, chi_fit, chi_fit_pred, lam_all, chi_all, chi_all_pred);
end

function J = buildObjective(settings, lam_fit, chi_fit, chi_fit_pred, lam_all, chi_all, chi_all_pred)

    sse = sum((chi_fit_pred - chi_fit).^2);

    prFitMask = lam_fit >= settings.practicalRange(1) & lam_fit <= settings.practicalRange(2);
    sse_pr = sum((chi_fit_pred(prFitMask) - chi_fit(prFitMask)).^2);

    if strcmpi(settings.fitGoal, 'bestfit')
        J = sse + settings.weightPractical * sse_pr;
        return;
    end

    ratio_all = chi_all_pred ./ chi_all;
    prAllMask = lam_all >= settings.practicalRange(1) & lam_all <= settings.practicalRange(2);
    ratio_pr  = ratio_all(prAllMask);

    if isempty(ratio_pr)
        ratio_pr = ratio_all;
    end

    n100  = sum(ratio_pr > 1.00);
    n103  = sum(ratio_pr > 1.03);
    n110  = sum(ratio_pr > 1.10);
    maxPr = max(ratio_pr);
    meanPr = mean(ratio_pr);
    covPr  = std(ratio_pr) / mean(ratio_pr);

    J = sse ...
      + settings.weightPractical * sse_pr ...
      + settings.designPenalty.wNgt100    * n100 ...
      + settings.designPenalty.wNgt103    * n103 ...
      + settings.designPenalty.wNgt110    * n110 ...
      + settings.designPenalty.wMaxExcess * max(0, maxPr - settings.designPenalty.maxRef)^2 ...
      + settings.designPenalty.wMeanBelow * max(0, settings.designPenalty.targetMeanLo - meanPr)^2 ...
      + settings.designPenalty.wMeanAbove * max(0, meanPr - settings.designPenalty.targetMeanHi)^2 ...
      + settings.designPenalty.wCov       * covPr;
end

function chi = chiG_AP(lambda, alphaG, lambda0G, deltaG)
    phi = 0.5 .* (1 + alphaG .* (lambda - lambda0G) + lambda.^deltaG);
    rad = max(0, phi.^2 - lambda.^deltaG);
    chi = 1 ./ (phi + sqrt(rad));
    chi = min(chi, 1);
end

function chi = chiG_ModifiedAP(lambda, alphaG, betaG, lambda0G, deltaG, useSecondCap)
    phi = 0.5 .* (1 + alphaG .* (lambda - lambda0G) + betaG .* lambda.^deltaG);
    rad = max(0, phi.^2 - betaG .* lambda.^deltaG);
    chi = 1 ./ (phi + sqrt(rad));
    chi = min(chi, 1);

    if useSecondCap
        chi = min(chi, 1 ./ (lambda.^deltaG));
    end
end

function s = ratioStats(ratio)
    ratio = ratio(~isnan(ratio) & ratio > 0);

    if isempty(ratio)
        s.Mean   = NaN;
        s.COV    = NaN;
        s.Max    = NaN;
        s.Min    = NaN;
        s.Ngt100 = NaN;
        s.Ngt103 = NaN;
        s.Ngt110 = NaN;
        return;
    end

    s.Mean   = mean(ratio);
    s.COV    = std(ratio) / mean(ratio);
    s.Max    = max(ratio);
    s.Min    = min(ratio);
    s.Ngt100 = sum(ratio > 1.00);
    s.Ngt103 = sum(ratio > 1.03);
    s.Ngt110 = sum(ratio > 1.10);
end

function x = phys2free(p, lb, ub)
    z = (p - lb) ./ (ub - lb);
    z = min(max(z, 1e-8), 1-1e-8);
    x = log(z ./ (1-z));
end

function p = free2phys(x, lb, ub)
    z = 1 ./ (1 + exp(-x));
    p = lb + (ub - lb) .* z;
end

function plotScenario(scenRes, settings, figName)

    groupNames = scenRes.groupNames;
    curveStore = scenRes.curveStore;
    nGroups = numel(groupNames);

    fig = figure('Color','w','Position',[100 100 520*nGroups 520]);
    tiledlayout(1,nGroups,'Padding','compact','TileSpacing','compact');

    for g = 1:nGroups
        nexttile; hold on; box on; grid on;

        % find first curve entry for this group
        idxCurve = find(strcmp({curveStore.Group}, char(groupNames(g))), 1, 'first');
        if isempty(idxCurve)
            continue;
        end

        lam_all = curveStore(idxCurve).lam_all;
        chi_all = curveStore(idxCurve).chi_all;
        type_all = curveStore(idxCurve).type_all;

        idxShell = type_all == "SHELL";
        idxBeam  = type_all == "BEAM";

        scatter(lam_all(idxShell), chi_all(idxShell), 30, ...
            'o', 'MarkerFaceColor', [0.30 0.60 0.90], ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.4, 'DisplayName', 'shell');

        scatter(lam_all(idxBeam), chi_all(idxBeam), 36, ...
            'd', 'MarkerFaceColor', [0.95 0.55 0.25], ...
            'MarkerEdgeColor', 'k', 'LineWidth', 0.5, 'DisplayName', 'beam');

        idxThisGroup = find(strcmp({curveStore.Group}, char(groupNames(g))));
        lineClr = lines(numel(idxThisGroup));

        for j = 1:numel(idxThisGroup)
            c = curveStore(idxThisGroup(j));
            if strcmpi(c.ModelFamily, 'AP')
                lbl = sprintf('AP: \\lambda_0=%.3f, \\alpha=%.3f', c.lambda0, c.alpha);
            else
                lbl = sprintf('ModAP: \\lambda_0=%.3f, \\alpha=%.3f, \\beta=%.3f', c.lambda0, c.alpha, c.beta);
            end

            plot(c.lambdaCurve, c.chiCurve, '-', 'Color', lineClr(j,:), ...
                'LineWidth', 2.2, 'DisplayName', lbl);
        end

        xline(settings.practicalRange(1), '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);
        xline(settings.practicalRange(2), '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2);

        xlabel('\lambda_G', 'FontName', 'Times New Roman', 'FontSize', 16);
        ylabel('\chi_G',    'FontName', 'Times New Roman', 'FontSize', 16);
        title(char(groupNames(g)), 'FontName', 'Times New Roman', 'FontSize', 16);

        set(gca, 'FontName', 'Times New Roman', ...
                 'FontSize', 12, ...
                 'LineWidth', 1.1, ...
                 'Layer', 'top');

        xlim([0 3]);
        ylim([0.2 1.05]);

        legend('Location', 'southwest', ...
               'FontName', 'Times New Roman', ...
               'FontSize', 9, ...
               'Box', 'on');

        hold off;
    end

    exportgraphics(fig, figName, 'Resolution', 600);
end