%% =========================================================
%  Evaluation manuelle du modele de flambement - Eurocode 3
%  chi = 1 / (Phi + sqrt(Phi^2 - lambda^p))     avec chi <= 1
%  Phi = 0.5 * [1 + alpha*(lambda - 0.2) + lambda^p]
%
%  PAS D'OPTIMISATION ICI : alpha et p sont fixes a la main
%  ci-dessous. Changez leurs valeurs et relancez le script pour
%  voir immediatement l'effet sur la courbe, R2 et RMSE.
%  =========================================================
clear; clc; close all;


%% --- 1. DONNEES EXPERIMENTALES (lues depuis Excel) ---

fichier_excel = 'Result_new - version 3.xlsm';
feuille       = 'HR_Global Only';

range_chi    = 'AK6:AK293';
range_lambda = 'AJ6:AJ293';

lambda_data = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda)';
chi_data    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi)';

% Retrait des cellules vides (NaN), lambda et chi retires ensemble
[lambda_data, chi_data] = nettoyer_paire(lambda_data, chi_data);

assert(length(lambda_data) == length(chi_data), ...
    'Erreur : lambda_data et chi_data doivent avoir la meme longueur.');


%% --- 2. VALEURS A TESTER MANUELLEMENT ---
% <-- Modifiez ces 3 valeurs pour explorer differentes combinaisons.

alpha_test   = 0.1;   % <-- valeur de alpha a evaluer
p_test       = 2.0;    % <-- valeur de l'exposant p a evaluer
lambda0_fixe = 0.2;    % <-- lambda0 (reste fixe, valeur EC3 classique)


%% --- 3. MODELE ---

phi_fun = @(alpha, p, lam) 0.5 .* (1 + alpha .* (lam - lambda0_fixe) + lam.^p);

chi_fun = @(alpha, p, lam) min(1.0, ...
    1 ./ (phi_fun(alpha, p, lam) + sqrt(max(0, phi_fun(alpha, p, lam).^2 - lam.^p))));


%% --- 4. EVALUATION DE L'AJUSTEMENT POUR (alpha_test, p_test) ---
% Aucun fminbnd/lsqnonlin ici : on calcule juste la qualite de l'ajustement
% pour LES VALEURS CHOISIES ci-dessus, pour pouvoir les comparer a l'oeil
% et au R2/RMSE en testant plusieurs combinaisons a la main.

chi_fit   = chi_fun(alpha_test, p_test, lambda_data);
residuals = chi_data - chi_fit;
SSres     = sum(residuals.^2);
SStot     = sum((chi_data - mean(chi_data)).^2);
R2        = 1 - SSres / SStot;
RMSE      = sqrt(mean(residuals.^2));
MAE       = mean(abs(residuals));


%% --- 5. RESUME CONSOLE ---

fprintf('\n==========================================\n');
fprintf('  EVALUATION MANUELLE (pas de calibration)\n');
fprintf('==========================================\n');
fprintf('  alpha testes : %.4f\n', alpha_test);
fprintf('  p testes     : %.4f\n', p_test);
fprintf('  lambda0      : %.4f  (fixe)\n', lambda0_fixe);
fprintf('  R2           : %.6f\n', R2);
fprintf('  RMSE         : %.6f\n', RMSE);
fprintf('  MAE          : %.6f\n', MAE);
fprintf('  Nb points    : %d\n',   length(lambda_data));
fprintf('==========================================\n\n');


%% --- 6. FIGURE : donnees experimentales + courbe testee ---

lam_plot  = linspace(0, max(lambda_data) * 1.1, 400);
chi_plot  = chi_fun(alpha_test, p_test, lam_plot);
chi_plot(1) = 1;   % verrou numerique : chi(lambda=0) = 1

figure('Color', 'white', 'Position', [100 100 720 520]);
ax = axes; hold(ax, 'on'); grid(ax, 'on');

% Points experimentaux
scatter(ax, lambda_data, chi_data, 40, 'filled', ...
    'MarkerEdgeColor', 'black', 'LineWidth', 0.6, ...
    'DisplayName', 'Donnees experimentales');

% Courbe testee (alpha_test, p_test)
plot(ax, lam_plot, chi_plot, '-', ...
    'Color', [0.1 0.1 0.1], 'LineWidth', 2.2, ...
    'DisplayName', sprintf('\\alpha=%.3f, p=%.2f  (R^2=%.4f)', alpha_test, p_test, R2));

xlabel(ax, '$\bar{\lambda}_G$', 'Interpreter', 'latex', 'FontSize', 16, 'Color', 'black');
ylabel(ax, '${\chi}_G$', 'Interpreter', 'latex', 'FontSize', 16, 'Color', 'black');
title(ax, 'Buckling curve - HR', ...
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