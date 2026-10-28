%% =========================================================
%  Evaluation manuelle du modele de flambement - Eurocode 3
%  chi = 1 / (Phi + sqrt(Phi^2 - lambda^p))     avec chi <= 1
%  Phi = 0.5 * [1 + alpha*(lambda - 0.2) + lambda^p]
%
%  PAS D'OPTIMISATION ICI : alpha et p sont fixes a la main
%  ci-dessous. Deux jeux de donnees (1 et 2) sont evalues
%  separement, avec leur propre alpha, et traces ensemble sur
%  le meme graphique.
%  =========================================================
clear; clc; close all;


%% --- 1. DONNEES EXPERIMENTALES (lues depuis Excel, 2 jeux de donnees) ---

fichier_excel = 'Result_new - version 3.xlsm';
feuille       = 'Welded shape';

% --- Jeu de donnees 1 : pour Xhi dans [0.85 ; 2.5[ ---
range_chi_1    = 'G3:G82';   % <-- colonne corrigee (A avant B)
range_lambda_1 = 'H3:H82';

% --- Jeu de donnees 2 : pour Xhi dans [2.5 ; 7.1[ ---
range_chi_2    = 'J3:J66';
range_lambda_2 = 'K3:K66';

lambda_data_1 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_1)';
chi_data_1    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_1)';

lambda_data_2 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_2)';
chi_data_2    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_2)';

% Retrait des cellules vides (NaN), lambda et chi retires ensemble
[lambda_data_1, chi_data_1] = nettoyer_paire(lambda_data_1, chi_data_1);
[lambda_data_2, chi_data_2] = nettoyer_paire(lambda_data_2, chi_data_2);

assert(length(lambda_data_1) == length(chi_data_1), ...
    'Erreur : lambda_data_1 et chi_data_1 doivent avoir la meme longueur.');
assert(length(lambda_data_2) == length(chi_data_2), ...
    'Erreur : lambda_data_2 et chi_data_2 doivent avoir la meme longueur.');


%% --- 2. VALEURS A TESTER MANUELLEMENT ---
% <-- Modifiez ces valeurs pour explorer differentes combinaisons.

alpha_test_1 = 0.23;   % <-- alpha a evaluer pour le jeu de donnees 1
alpha_test_2 = 0.23;   % <-- alpha a evaluer pour le jeu de donnees 2
p_test       = 2;      % <-- exposant p, partage par les deux evaluations
lambda0_fixe = 0.1;    % <-- lambda0, partage (reste fixe, valeur EC3 classique)


%% --- 3. MODELE ---

phi_fun = @(alpha, p, lam) 0.5 .* (1 + alpha .* (lam - lambda0_fixe) + lam.^p);

chi_fun = @(alpha, p, lam) min(1.0, ...
    1 ./ (phi_fun(alpha, p, lam) + sqrt(max(0, phi_fun(alpha, p, lam).^2 - lam.^p))));


%% --- 4. EVALUATION DE L'AJUSTEMENT POUR CHAQUE JEU DE DONNEES ---
% Aucun fminbnd/lsqnonlin ici : on calcule juste la qualite de l'ajustement
% pour LES VALEURS CHOISIES ci-dessus, separement pour chaque jeu.

% --- Evaluation 1 ---
chi_fit_1   = chi_fun(alpha_test_1, p_test, lambda_data_1);
residuals_1 = chi_data_1 - chi_fit_1;
SSres_1     = sum(residuals_1.^2);
SStot_1     = sum((chi_data_1 - mean(chi_data_1)).^2);
R2_1        = 1 - SSres_1 / SStot_1;
RMSE_1      = sqrt(mean(residuals_1.^2));
MAE_1       = mean(abs(residuals_1));

% --- Evaluation 2 ---
chi_fit_2   = chi_fun(alpha_test_2, p_test, lambda_data_2);
residuals_2 = chi_data_2 - chi_fit_2;
SSres_2     = sum(residuals_2.^2);
SStot_2     = sum((chi_data_2 - mean(chi_data_2)).^2);
R2_2        = 1 - SSres_2 / SStot_2;
RMSE_2      = sqrt(mean(residuals_2.^2));
MAE_2       = mean(abs(residuals_2));


%% --- 5. RESUME CONSOLE ---

fprintf('\n==========================================\n');
fprintf('  EVALUATION MANUELLE (pas de calibration)\n');
fprintf('==========================================\n');
fprintf('  --- Jeu de donnees 1 ---\n');
fprintf('  alpha teste  : %.4f\n', alpha_test_1);
fprintf('  R2           : %.6f\n', R2_1);
fprintf('  RMSE         : %.6f\n', RMSE_1);
fprintf('  MAE          : %.6f\n', MAE_1);
fprintf('  Nb points    : %d\n',   length(lambda_data_1));
fprintf('  --- Jeu de donnees 2 ---\n');
fprintf('  alpha teste  : %.4f\n', alpha_test_2);
fprintf('  R2           : %.6f\n', R2_2);
fprintf('  RMSE         : %.6f\n', RMSE_2);
fprintf('  MAE          : %.6f\n', MAE_2);
fprintf('  Nb points    : %d\n',   length(lambda_data_2));
fprintf('  --- Parametres partages ---\n');
fprintf('  p        : %.4f  (fixe)\n', p_test);
fprintf('  lambda0  : %.4f  (fixe)\n', lambda0_fixe);
fprintf('==========================================\n\n');


%% --- 6. FIGURE : les 2 jeux de donnees + les 2 courbes testees ---

lam_max = max([lambda_data_1, lambda_data_2]);   % echelle commune pour les 2 courbes
lam_plot = linspace(0, lam_max * 1.1, 400);

chi_plot_1 = chi_fun(alpha_test_1, p_test, lam_plot);
chi_plot_1(1) = 1;   % verrou numerique : chi(lambda=0) = 1

chi_plot_2 = chi_fun(alpha_test_2, p_test, lam_plot);
chi_plot_2(1) = 1;

figure('Color', 'white', 'Position', [100 100 300 250]);
ax = axes; hold(ax, 'on'); grid(ax, 'on');

% --- Points experimentaux, jeu 1 ---
scatter(ax, lambda_data_1, chi_data_1, 40, [0.843 0.188 0.122], 'filled', 'o', ...
    'MarkerEdgeColor', 'black', 'LineWidth', 0.6, ...
    'DisplayName', '\xi \in [0.1 ; 0.50[');

% --- Points experimentaux, jeu 2 ---
scatter(ax, lambda_data_2, chi_data_2, 40, [0.000 0.180 0.600], 'filled', 's', ...
    'MarkerEdgeColor', 'black', 'LineWidth', 0.6, ...
    'DisplayName', '\xi \in [0.57 ; 1.3[');

% --- Courbe testee, jeu 1 ---
plot(ax, lam_plot, chi_plot_1, '-', ...
    'Color', [0.843 0.188 0.122], 'LineWidth', 2.2, ...
    'DisplayName', sprintf('\\alpha_1=%.3f, p=%.2f  (R^2=%.4f)', alpha_test_1, p_test, R2_1));

% --- Courbe testee, jeu 2 ---
plot(ax, lam_plot, chi_plot_2, '--', ...
    'Color', [0.000 0.180 0.600], 'LineWidth', 2.2, ...
    'DisplayName', sprintf('\\alpha_2=%.3f, p=%.2f  (R^2=%.4f)', alpha_test_2, p_test, R2_2));

xlabel(ax, '$\bar{\lambda}_G$', 'Interpreter', 'latex', 'FontSize', 16, 'Color', 'black');
ylabel(ax, '${\chi}_G$', 'Interpreter', 'latex', 'FontSize', 16, 'Color', 'black');
title(ax, 'Buckling curves - H shape', ...
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