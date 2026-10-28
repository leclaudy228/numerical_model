%% =========================================================
%  Code to plot graphic
%  =========================================================
clear; clc; close all;

%% --- 1. DONNEES EXPERIMENTALES et NUMERIQUES (lues depuis Excel) ---
dossier_fichier = 'Validation  4 files Q690'; % le dossier se trouve dans le repertoire courant
fichier_excel   = 'Validation_4.xlsx';

chemin_complet = fullfile(dossier_fichier, fichier_excel);

% Une feuille par eprouvette
feuilles = {'HSS-I1-C', 'HSS-I1-C-R', 'HSS-I2-C'};
n_curves = numel(feuilles);

% Noms des courbes pour la legende (cell arrays)
name_Test = {'HSS-I1-C (Test)', 'HSS-I1-C-R (Test)', 'HSS-I2-C (Test)'};
name_FE   = {'HSS-I1-C (FE)',   'HSS-I1-C-R (FE)',   'HSS-I2-C (FE)'};

% Lignes de debut/fin (differentes pour Test et FE)
ligne_debut_test = 4;  ligne_fin_test = 48;
ligne_debut_fe   = 4;

% Colonnes : Test = A (x), B (y) -- FE = F (x), G (y)
range_x_Test = sprintf('A%d:A%d', ligne_debut_test, ligne_fin_test);
range_y_Test = sprintf('B%d:B%d', ligne_debut_test, ligne_fin_test);

% Lecture des donnees dans des cell arrays (une entree par feuille/eprouvette)
X_Test = cell(1, n_curves);
Y_Test = cell(1, n_curves);
X_FE   = cell(1, n_curves);
Y_FE   = cell(1, n_curves);

for i = 1:n_curves
    X_Test{i} = readmatrix(chemin_complet, 'Sheet', feuilles{i}, 'Range', range_x_Test);
    Y_Test{i} = readmatrix(chemin_complet, 'Sheet', feuilles{i}, 'Range', range_y_Test);

    % Detection dynamique de la derniere ligne avec des donnees en colonne G
    % (G contient une ligne supplementaire qui ne compte pas : on l'ignore
    %  et on applique la meme plage de lignes a F et G)
    colonne_brute = readmatrix(chemin_complet, 'Sheet', feuilles{i}, 'Range', 'G4:G10000');
    derniere_ligne_donnees = ligne_debut_fe + find(~isnan(colonne_brute), 1, 'last') - 1;
    ligne_fin_fe = derniere_ligne_donnees - 1; % on ignore la derniere ligne de G

    range_x_FE = sprintf('F%d:F%d', ligne_debut_fe, ligne_fin_fe);
    range_y_FE = sprintf('G%d:G%d', ligne_debut_fe, ligne_fin_fe);

    X_FE{i} = readmatrix(chemin_complet, 'Sheet', feuilles{i}, 'Range', range_x_FE);
    Y_FE{i} = readmatrix(chemin_complet, 'Sheet', feuilles{i}, 'Range', range_y_FE);
end

%% --- 2. TRACE DES COURBES ---
figure('Color', 'w', 'Position', [100, 100, 900, 650]);
hold on;

% Couleurs choisies manuellement pour chaque paire Test/FE (une ligne RGB par eprouvette)
couleurs = [0.00 0.45 0.74;   % bleu    - HSS-I1-C
            0.85 0.33 0.10;   % orange  - HSS-I1-C-R
            0.47 0.67 0.19;   % vert    - HSS-I2-C
            0.49 0.18 0.56];  % violet  - C2L4
markers_test = {'o', 's', '^', 'd'};

for i = 1:n_curves
    % Test experimental : marqueurs seuls, pas de ligne continue
    plot(X_Test{i}, Y_Test{i}, markers_test{i}, ...
        'Color', couleurs(i,:), ...
        'MarkerFaceColor', couleurs(i,:), ...
        'MarkerSize', 8, ...
        'LineWidth', 1.2, ...
        'DisplayName', name_Test{i});

    % Elements finis : ligne continue
    plot(X_FE{i}, Y_FE{i}, '-', ...
        'Color', couleurs(i,:), ...
        'LineWidth', 2.5, ...
        'DisplayName', name_FE{i});
end

xlabel('Lateral displacement at mid-height [mm]', 'FontSize', 16, 'FontWeight', 'bold');
ylabel('Load [KN]', 'FontSize', 16, 'FontWeight', 'bold');


%title('C1E Specimens', 'FontSize', 18, 'FontWeight', 'bold', 'Color', 'k');


lgd = legend('show', 'Location', 'best');
lgd.FontSize = 12;
lgd.Color = 'w';        % fond blanc (pas noir)
lgd.EdgeColor = 'k';
lgd.Box = 'on';
lgd.TextColor = 'k';    % texte en noir (pas gris)

grid on;
box on;

% Style des axes (equivalent inline de styleAxe : fond blanc, axes noirs)
ax = gca;
ax.Color = 'w';
ax.XColor = 'k';
ax.YColor = 'k';
ax.LineWidth = 1.5;
ax.FontSize = 14;
ax.GridAlpha = 0.25;
set(gcf, 'Color', 'w');

hold off;