%% =========================================================
%  Calibration du facteur d'imperfection alpha - Eurocode 3 (best fit)
%  chi = 1 / (Phi + sqrt(Phi^2 - lambda^2))     avec chi <= 1
%  Phi = 0.5 * [1 + alpha*(lambda - 0.2) + lambda^2]
%
%  p = 2 et lambda0 = 0.2 sont fixes (valeurs EC3 classiques) ;
%  seul alpha est calibre, par moindres carres (best fit).
%  =========================================================
clear; clc; close all;


%% --- 1. DONNEES EXPERIMENTALES PAR NUANCE (lues depuis Excel) ---

fichier_excel = 'Result_new - version 3.xlsm';
feuille       = 'Global Only';

range_lambda_690 = 'AJ6:AJ101';
range_chi_690    = 'AK6:AK101';
range_lambda_460 = 'AJ102:AJ197';
range_chi_460    = 'AK102:AK197';
range_lambda_355 = 'AJ198:AJ293';
range_chi_355    = 'AK198:AK293';

lambda_data_690 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_690)';
chi_data_690    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_690)';
lambda_data_460 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_460)';
chi_data_460    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_460)';
lambda_data_355 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_355)';
chi_data_355    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_355)';

% Retrait des cellules vides (NaN), lambda et chi retires ensemble
[lambda_data_690, chi_data_690] = nettoyer_paire(lambda_data_690, chi_data_690);
[lambda_data_460, chi_data_460] = nettoyer_paire(lambda_data_460, chi_data_460);
[lambda_data_355, chi_data_355] = nettoyer_paire(lambda_data_355, chi_data_355);

% Fusion des 3 nuances + etiquette de nuance (pour la legende / couleurs)
lambda_data = [lambda_data_690, lambda_data_460, lambda_data_355];
chi_data    = [chi_data_690,    chi_data_460,    chi_data_355];
grade_data  = [repmat({'S690'}, 1, numel(lambda_data_690)), ...
               repmat({'S460'}, 1, numel(lambda_data_460)), ...
               repmat({'S355'}, 1, numel(lambda_data_355))];

grades_uniques  = {'S690', 'S460', 'S355'};
couleurs_grade  = [0.843 0.188 0.122;    % S690 -> rouge
                    0.000 0.180 0.600;   % S460 -> bleu fonce
                    0.200 0.627 0.173];  % S355 -> vert
marqueurs_grade = {'o', 's', 'p'};       % cercle, carre, etoile a 5 branches

assert(length(lambda_data) == length(chi_data), ...
    'Erreur : lambda_data et chi_data doivent avoir la meme longueur.');


%% --- 2. MODELE (p et lambda0 fixes, seul alpha est variable) ---

p_fixe       = 2;      % <-- expose fixe (ne varie plus)
lambda0_fixe = 0.2;    % <-- lambda0 fixe (valeur EC3 classique)

phi_fun = @(alpha, lam) 0.5 .* (1 + alpha .* (lam - lambda0_fixe) + lam.^p_fixe);

chi_fun = @(alpha, lam) min(1.0, ...
    1 ./ (phi_fun(alpha, lam) + sqrt(max(0, phi_fun(alpha, lam).^2 - lam.^p_fixe))));


%% --- 3. CALIBRATION (best fit, moindres carres, alpha seul) ---

cost_fun = @(alpha) sum((chi_fun(alpha, lambda_data) - chi_data).^2);

alpha_min = 0.01;   % <-- borne basse
alpha_max = 2.00;   % <-- borne haute

options   = optimset('Display', 'off', 'TolX', 1e-10, 'TolFun', 1e-14);
alpha_opt = fminbnd(cost_fun, alpha_min, alpha_max, options);

chi_fit   = chi_fun(alpha_opt, lambda_data);
residuals = chi_data - chi_fit;
SSres     = sum(residuals.^2);
SStot     = sum((chi_data - mean(chi_data)).^2);
R2        = 1 - SSres / SStot;
RMSE      = sqrt(mean(residuals.^2));


%% --- 4. RESUME CONSOLE ---

fprintf('\n==========================================\n');
fprintf('  CALIBRATION ALPHA - EUROCODE 3 (best fit)\n');
fprintf('==========================================\n');
fprintf('  alpha    : %.4f\n', alpha_opt);
fprintf('  lambda0  : %.4f  (fixe)\n', lambda0_fixe);
fprintf('  p        : %.4f  (fixe)\n', p_fixe);
fprintf('  R2       : %.6f\n', R2);
fprintf('  RMSE     : %.6f\n', RMSE);
fprintf('  Nb points: %d\n',   length(lambda_data));
fprintf('==========================================\n\n');


%% --- 5. FIGURE : donnees experimentales + courbe calibree ---

lam_plot     = linspace(0, max(lambda_data) * 1.1, 400);
chi_plot_opt = chi_fun(alpha_opt, lam_plot);
chi_plot_opt(1) = 1;   % verrou numerique : chi(lambda=0) = 1

figure('Color', 'white', 'Position', [100 100 720 520]);
ax = axes; hold(ax, 'on'); grid(ax, 'on');

% Points experimentaux, colores et marques par nuance
for g = 1:length(grades_uniques)
    idxg = strcmp(grade_data, grades_uniques{g});
    if any(idxg)
        scatter(ax, lambda_data(idxg), chi_data(idxg), 40, couleurs_grade(g,:), 'filled', marqueurs_grade{g}, ...
            'MarkerEdgeColor', 'black', 'LineWidth', 0.6, 'DisplayName', grades_uniques{g});
    end
end

% Courbe calibree
plot(ax, lam_plot, chi_plot_opt, '-', ...
    'Color', [0.1 0.1 0.1], 'LineWidth', 2.2, ...
    'DisplayName', sprintf('Best fit : \\alpha=%.3f', alpha_opt));

xlabel(ax, '$\bar{\lambda}$', 'Interpreter', 'latex', 'FontSize', 16, 'Color', 'black');
ylabel(ax, '$\chi$', 'Interpreter', 'latex', 'FontSize', 16, 'Color', 'black');
title(ax, 'Courbe de flambement - modele generalise', ...
    'FontSize', 13, 'FontWeight', 'bold', 'Color', 'black');
xlim(ax, [0, max(lam_plot)]);
ylim(ax, [0, 1.15]);
legend(ax, 'Location', 'northeast', 'TextColor', 'black', 'EdgeColor', 'black', 'Color', 'white');

set(ax, 'Box', 'on', ...
    'Color', 'white', ...
    'XColor', 'black', ...
    'YColor', 'black', ...
    'GridColor', [0 0 0]);


%% --- FONCTION LOCALE : nettoyer_paire ---
function [lambda_propre, chi_propre] = nettoyer_paire(lambda_brut, chi_brut)
    valide        = ~isnan(lambda_brut) & ~isnan(chi_brut);
    lambda_propre = lambda_brut(valide);
    chi_propre    = chi_brut(valide);
end