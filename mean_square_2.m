%% =========================================================
%  Calibration of the imperfection factor alpha - Eurocode 3
%  chi = 1 / (Phi + sqrt(Phi^2 - lambda^2))   with chi <= 1
%  Phi = 0.5 * [1 + alpha*(lambda - 0.2) + lambda^2]
%  =========================================================
%%
clear; clc; close all;
% This script:
%   1) reads experimental (lambda, chi) pairs for 3 steel grades,
%   2) calibrates the EC3 imperfection factor alpha using a classic
%      BEST FIT (least-squares regression through the data, not an
%      envelope below the data),
%   3) plots 3 control figures,
%   4) prints a residuals table in the console.
% Every section is commented so the logic can be followed step by step.


%% ==========================================================================
%  SECTION 1: EXPERIMENTAL DATA PER STEEL GRADE (read from Excel)
%  ==========================================================================
%  Instead of typing the vectors by hand, they are read from an Excel file
%  named "Result", sheet "Global Only", where the data is organized in
%  columns (one lambda column + one chi column per grade). Just adjust the
%  settings below (file name/path, and the EXCEL RANGE of each column,
%  e.g. 'B2:B50') so they match your actual file.

% --- Source file settings ---
fichier_excel = 'Result_new - version 3.xlsm';    % <-- Excel file name (or full path)
feuille       = 'Global Only';                    % <-- sheet name

% --- Excel ranges to set for each column ---
% MATLAB 'Range' format: 'StartColumnStartRow:EndColumnEndRow'
% Example: 'B2:B120' = column B, from row 2 to row 120 (header excluded).
% Adjust BOTH the column letters and the row numbers to match your file.
range_lambda_690 = 'AJ6:AJ101';     % <-- lambda column + rows (S690)
range_chi_690    = 'AK6:AK101';     % <-- chi column + rows    (S690)

range_lambda_460 = 'AJ102:AJ197';   % <-- lambda column + rows (S460)
range_chi_460    = 'AK102:AK197';   % <-- chi column + rows    (S460)

range_lambda_355 = 'AJ198:AJ293';   % <-- lambda column + rows (S355)
range_chi_355    = 'AK198:AK293';   % <-- chi column + rows    (S355)

% --- Reading the columns ---
% readmatrix returns a COLUMN vector; it is transposed (') to a ROW vector,
% since the rest of the script expects row vectors.
lambda_data_690 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_690)';
chi_data_690    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_690)';

lambda_data_460 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_460)';
chi_data_460    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_460)';

lambda_data_355 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_355)';
chi_data_355    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_355)';

% --- Cleanup: remove empty cells ---
% If the range read (e.g. 'A2:A200') is longer than the number of actually
% filled rows, readmatrix returns NaN for the empty cells. They are removed
% here, checking lambda and chi TOGETHER (a pair is dropped if either value
% is NaN), so lambda_i and chi_i never get desynchronized.
[lambda_data_690, chi_data_690] = nettoyer_paire(lambda_data_690, chi_data_690);
[lambda_data_460, chi_data_460] = nettoyer_paire(lambda_data_460, chi_data_460);
[lambda_data_355, chi_data_355] = nettoyer_paire(lambda_data_355, chi_data_355);

% The 3 grades are concatenated into one big lambda_data / chi_data vector,
% because the WHOLE calibration (section 3) works on the entire dataset,
% regardless of grade. It's only for PLOTTING (figures) that we need to
% remember which grade each point belongs to: that is the role of the
% "grade_data" vector (a text label, e.g. 'S690', associated to each
% lambda_data / chi_data value at the same index).
lambda_data = [lambda_data_690, lambda_data_460, lambda_data_355];
chi_data    = [chi_data_690,    chi_data_460,    chi_data_355];
grade_data  = [repmat({'S690'}, 1, numel(lambda_data_690)), ...
               repmat({'S460'}, 1, numel(lambda_data_460)), ...
               repmat({'S355'}, 1, numel(lambda_data_355))];

% List of grades and the color associated with each (same order in both
% variables: grades_uniques{1} <-> couleurs_grade(1,:), etc.)
% These colors are reused across all figures so each grade is always
% represented the same way.
grades_uniques  = {'S690', 'S460', 'S355'};
couleurs_grade  = [0.843 0.188 0.122;    % S690 -> red
                    0.000 0.180 0.600;   % S460 -> dark blue
                    0.200 0.627 0.173];  % S355 -> green

% --- Consistency check ---
% A simple guard: if more lambda values were pasted than chi values (or the
% opposite), the script stops right away with a clear message, instead of
% a cryptic MATLAB error further down.
assert(length(lambda_data) == length(chi_data), ...
    'Error: lambda_data and chi_data must have the same length.');

% Just an information message if some tests were repeated (same lambda
% appearing several times): this is not an error, all points are kept in
% the calibration.
n_doublons = length(lambda_data) - length(unique(lambda_data));
if n_doublons > 0
    fprintf('  [INFO] %d duplicate value pair(s) detected and kept.\n\n', ...
        n_doublons);
end


%% ==========================================================================
%  SECTION 2: EUROCODE 3 BUCKLING CURVE FUNCTIONS
%  ==========================================================================

phi_fun = @(alpha, lam) 0.5 .* (1 + alpha .* (lam - 0.2) + lam.^2);

chi_fun = @(alpha, lam) min(1.0, ...
    1 ./ (phi_fun(alpha, lam) + sqrt(max(0, phi_fun(alpha, lam).^2 - lam.^2))));

residual_fun = @(alpha) chi_fun(alpha, lambda_data) - chi_data;

cost_fun = @(alpha) sum(residual_fun(alpha).^2);

% Reasonable physical bounds for alpha (the official EC3 curves range from
% 0.13 to 0.76; a wider range is used here as a safety margin).
lb = 0.01;
ub = 2.00;


%% ==========================================================================
%  SECTION 3: BEST-FIT CALIBRATION OF ALPHA (classic least squares)
%  ==========================================================================

options   = optimset('Display', 'off', 'TolX', 1e-10, 'TolFun', 1e-14);
alpha_opt = fminbnd(cost_fun, lb, ub, options);

% --- Goodness-of-fit indicators ---
chi_fit   = chi_fun(alpha_opt, lambda_data);      % chi predicted by the calibrated model
residuals = chi_data - chi_fit;                   % measured - predicted (can be positive
                                                    % OR negative, since this is a best fit,
                                                    % not a one-sided envelope)
SSres     = sum(residuals.^2);                        % sum of squared residuals
SStot     = sum((chi_data - mean(chi_data)).^2);      % total variance of the data
R2        = 1 - SSres / SStot;                        % coefficient of determination
RMSE      = sqrt(mean(residuals.^2));                 % root-mean-square error
MAE       = mean(abs(residuals));                     % mean absolute error


%% ==========================================================================
%  SECTION 4: CONSOLE SUMMARY
%  ==========================================================================
%  Plain text printout of the calibration results (nothing computed here,
%  just fprintf calls to read the results without opening a figure).

fprintf('\n========================================\n');
fprintf('  ALPHA CALIBRATION - EUROCODE 3 (best fit)\n');
fprintf('========================================\n');
fprintf('  Calibrated alpha  : %.4f\n', alpha_opt);
fprintf('  R2                : %.6f\n', R2);
fprintf('  RMSE              : %.6f\n', RMSE);
fprintf('  MAE               : %.6f\n', MAE);
fprintf('  Number of points  : %d\n',   length(lambda_data));
fprintf('========================================\n\n');

% For reference, the SSR cost of the 5 "official" EC3 curves (a0, a, b, c,
% d) on this dataset is also printed, purely for comparison.
alphas_EC3 = [0.13, 0.21, 0.34, 0.49, 0.76];
noms_EC3   = {'a0', 'a', 'b', 'c', 'd'};
fprintf('  Standard EC3 curves:\n');
for k = 1:length(alphas_EC3)
    fprintf('    Curve %-3s (alpha=%.2f) : SSR = %.6f\n', ...
        noms_EC3{k}, alphas_EC3(k), cost_fun(alphas_EC3(k)));
end
fprintf('\n');


%% ==========================================================================
%  SECTION 5: SENSITIVITY ANALYSIS
%  ==========================================================================
%  Goal: see how sensitive the choice of alpha is, i.e. over which range of
%  alpha the SSR cost stays close to the observed minimum.
%  1000 alpha values are swept between lb and ub, the SSR is computed for
%  each, and the values staying under a "minimum SSR + 5%" threshold are
%  identified.
%  (Used only for console information here, and reused to plot figure 2.)

alpha_range    = linspace(lb, ub, 1000);
cost_range     = arrayfun(cost_fun, alpha_range);
cost_threshold = cost_fun(alpha_opt) * 1.05;

idx_conf = alpha_range(cost_range <= cost_threshold);
if ~isempty(idx_conf)
    fprintf('  Alpha interval (SSR +5%% threshold): [%.4f, %.4f]\n\n', ...
        min(idx_conf), max(idx_conf));
end


%% ==========================================================================
%  SECTION 6: SHARED PLOT SETTINGS (used by all 3 figures)
%  ==========================================================================
%  Nothing scientific here: these are just visual settings (colors, font
%  sizes, line widths...) grouped once so the 3 figures share a consistent
%  style.

% lam_plot: a "smooth" vector of 400 lambda values between 0 and
% (max of the data * 1.1), used only to PLOT the theoretical curves (EC3
% and calibrated curve) -- this is not measured data.
lam_plot = linspace(0, max(lambda_data) * 1.1, 400);

col_opt  = [0.10, 0.10, 0.10];       % color of the calibrated curve (black)
col_EC3  = [0.650, 0.650, 0.650];    % color of the standard EC3 curves (grey)
col_b    = [0.200, 0.627, 0.173];    % color for curve "b" specifically (green, visual reference)

styles_EC3 = {'--', ':', '-.', '--', ':'};   % a different line style per EC3 curve (a0,a,b,c,d)

fs_label = 17;   % axis label font size
fs_title = 14;   % title font size
fs_tick  = 11;   % tick label font size
fs_leg   = 10;   % legend font size
lw_main  = 2.0;  % line width of the main (calibrated) curve
lw_EC3   = 1.0;  % line width of the standard EC3 curves

% Small reusable function that applies the same "clean" style (white
% background, black text, light grid...) to any axes handle passed to it.
styleAxe = @(ax) set(ax, ...
    'Color',          'white',       ...
    'XColor',         'black',       ...
    'YColor',         'black',       ...
    'GridColor',      [0 0 0],       ...
    'GridAlpha',      0.12,          ...
    'MinorGridAlpha', 0.06,          ...
    'FontSize',       fs_tick,       ...
    'FontName',       'Helvetica',   ...
    'LineWidth',      0.8,           ...
    'Box',            'on',          ...
    'TickDir',        'out');


%% ==========================================================================
%  SECTION 7: FIGURE 1 - Buckling curves (legend by grade)
%  ==========================================================================
%  This figure overlays:
%   (a) the 5 standard EC3 curves (a0,a,b,c,d), in the background, in grey,
%   (b) the experimental points, colored by steel grade,
%   (c) the calibrated best-fit curve, in black, on top.

f1 = figure('Name', 'Buckling curves', ...
    'Color', 'white', 'Position', [80 120 720 520]);
ax1 = axes(f1);
hold(ax1, 'on');   % allows several plot() calls to be overlaid on the same axes
grid(ax1, 'on');

% --- (a) Standard EC3 curves in the background ---
for k = 1:length(alphas_EC3)
    chi_k = chi_fun(alphas_EC3(k), lam_plot);   % theoretical curve for this EC3 alpha
    if alphas_EC3(k) == 0.34
        % Curve "b" (alpha=0.34) is highlighted in green, since it is
        % often the reference curve for common structural steel.
        plot(ax1, lam_plot, chi_k, styles_EC3{k}, ...
            'Color', col_b, 'LineWidth', lw_EC3 + 0.4, ...
            'DisplayName', sprintf('EC3 - %s  (\\alpha=%.2f)', noms_EC3{k}, alphas_EC3(k)));
    else
        plot(ax1, lam_plot, chi_k, styles_EC3{k}, ...
            'Color', col_EC3, 'LineWidth', lw_EC3, ...
            'DisplayName', sprintf('EC3 - %s  (\\alpha=%.2f)', noms_EC3{k}, alphas_EC3(k)));
    end
end

% --- (b) Experimental points, one group per grade ---
% Looping over each grade; "idxg" is a logical mask (true/false) that
% selects only the points of this grade in lambda_data / chi_data. Each
% scatter() call creates a distinct legend entry (the grade name), with
% its own dedicated color and marker shape.
% Marker shapes per grade: circle, square, 5-point star.
% Order matches grades_uniques: {1}='S690'->circle, {2}='S460'->square, {3}='S355'->5-point star (pentagram).
% Note: '*' in MATLAB is an asterisk (not a true star); 'p' (pentagram) gives a real 5-point star.
marqueurs_grade = {'o', 's', 'p'};

for g = 1:length(grades_uniques)
    idxg = strcmp(grade_data, grades_uniques{g});
    if any(idxg)   % only plot/legend the grades that actually have points
        scatter(ax1, lambda_data(idxg), chi_data(idxg), 40, couleurs_grade(g,:), 'filled', marqueurs_grade{g}, ...
            'MarkerEdgeColor', 'black', 'LineWidth', 0.6, ...
            'DisplayName', grades_uniques{g});
    end
end

% --- (c) Calibrated best-fit curve ---
% Reminder: chi(lambda=0) = 1 is already guaranteed by the EC3 formula's
% mathematics (see section 2: at lambda=0, phi < 0.5, so chi > 1, which is
% then capped exactly to 1). The first point of the plotted vector is
% still explicitly forced to 1, as a numerical safety lock.
chi_plot_opt = chi_fun(alpha_opt, lam_plot);
chi_plot_opt(1) = 1;

plot(ax1, lam_plot, chi_plot_opt, '-', ...
    'Color', col_opt, 'LineWidth', lw_main + 0.5, ...
    'DisplayName', sprintf('Best-fit curve \\alpha = %.3f', alpha_opt));

% Horizontal line at chi = 1 (physical upper limit), just as a visual
% reference. 'HandleVisibility','off' means it does not appear in the
% legend (it is only a visual guide, not a data series).
plot(ax1, [0 max(lam_plot)], [1 1], '-', ...
    'Color', [0.5 0.5 0.5], 'LineWidth', 0.7, 'HandleVisibility', 'off');

% --- Plot decoration (titles, axis labels, legend) ---
xlabel(ax1, '$\bar{\lambda}_G$', ...
    'Interpreter','latex', ...
    'FontSize', fs_label, 'FontName', 'Helvetica', 'Color', 'black');
ylabel(ax1, '$\chi_{G}$', ...
    'Interpreter','latex', ...
    'FontSize', fs_label, 'FontName', 'Helvetica', 'Color', 'black');
title(ax1, 'Buckling curves', ...
    'FontSize', fs_title, 'FontName', 'Helvetica', 'FontWeight', 'bold', 'Color', 'black');

xlim(ax1, [0, max(lam_plot)]);
ylim(ax1, [0, 1.15]);

leg1 = legend(ax1, 'Location', 'northeast', 'FontSize', fs_leg, ...
    'FontName', 'Helvetica', 'TextColor', 'black', 'EdgeColor', 'black', 'Color', 'white');
set(leg1, 'Color', 'white', 'TextColor', 'black', 'EdgeColor', 'black');

styleAxe(ax1);   % applies the shared style defined in section 6



%% ==========================================================================
%  SECTION 10: RESIDUALS TABLE (with grade) in the console
%  ==========================================================================
%  Plain text printout, point by point, to inspect precise values (useful
%  e.g. to spot an outlier).

fprintf('  Residuals table:\n');
fprintf('  %-8s %-12s %-12s %-12s %-12s %-12s\n', ...
    'grade', 'lambda', 'chi_exp', 'chi_fit', 'residual', 'residual(%)');
fprintf('  %s\n', repmat('-', 1, 70));
for i = 1:length(lambda_data)
    pct = 100 * abs(residuals(i)) / max(chi_data(i), 1e-9);   % max(...,1e-9) avoids a division by 0
    fprintf('  %-8s %-12.4f %-12.4f %-12.4f %-12.4f %-12.2f\n', ...
        grade_data{i}, lambda_data(i), chi_data(i), chi_fit(i), residuals(i), pct);
end
fprintf('\n');


%% ==========================================================================
%  LOCAL FUNCTION: nettoyer_paire (clean_pair)
%  ==========================================================================
%  Removes empty cells (NaN) read from Excel, making sure lambda and chi
%  stay paired up (if either value is NaN at index i, the whole pair at
%  that index is dropped, not just the NaN value).
%  Must stay at the very end of the file (MATLAB rule for local functions
%  inside a script).
function [lambda_propre, chi_propre] = nettoyer_paire(lambda_brut, chi_brut)
    valide        = ~isnan(lambda_brut) & ~isnan(chi_brut);
    lambda_propre = lambda_brut(valide);
    chi_propre    = chi_brut(valide);
end