%% =========================================================
%  Calibration du facteur d'imperfection alpha - Eurocode 3
%  chi = 1 / (Phi + sqrt(Phi^2 - lambda^2))  avec chi <= 1
%  Phi = 0.5 * [1 + alpha*(lambda - 0.2) + lambda^2]
%  =========================================================
%%
clear; clc; close all;
% Ce script :
%   1) lit des couples experimentaux (lambda, chi) issus de 3 nuances d'acier,
%   2) calibre le facteur d'imperfection alpha de la formule de flambement EC3
%      de facon CONSERVATIVE (la courbe calibree reste sous tous les points),
%   3) trace 3 figures de controle,
%   4) imprime un tableau de residus dans la console.
% Chaque section est commentee pour pouvoir suivre le raisonnement pas a pas.


%% ==========================================================================
%  SECTION 1 : DONNEES EXPERIMENTALES PAR NUANCE D'ACIER (lues depuis Excel)
%  ==========================================================================
%  Idee generale : au lieu de remplir les vecteurs a la main, on va les lire
%  dans un fichier Excel nomme "Result", feuille "Global only", ou les
%  donnees sont structurees en colonnes (une colonne lambda + une colonne
%  chi par nuance). Vous n'avez qu'a ajuster les reglages ci-dessous
%  (nom/chemin du fichier, et la PLAGE EXCEL de chaque colonne, ex. 'B2:B50')
%  pour qu'ils correspondent exactement a votre fichier.

% --- Reglages du fichier source ---
fichier_excel = 'Result_new - version 3.xlsm';    % <-- nom (ou chemin complet) du fichier Excel
feuille       = 'Global Only';    % <-- nom de la feuille

% --- Plages Excel a preciser pour chaque colonne ---
% Format 'Range' de MATLAB : 'ColonneLigneDebut:ColonneLigneFin'
% Exemple : 'B2:B120' = colonne B, de la ligne 2 a la ligne 120 (sans l'entete).
% Adaptez les lettres de colonne ET les numeros de ligne a votre fichier.
range_lambda_690 = 'AJ6:AJ101';   % <-- colonne + lignes de lambda (S690)
range_chi_690    = 'AK6:AK101';   % <-- colonne + lignes de chi    (S690)

range_lambda_460 = 'AJ102:AJ197';   % <-- colonne + lignes de lambda (S460)
range_chi_460    = 'AK102:AK197';   % <-- colonne + lignes de chi    (S460)

range_lambda_355 = 'AJ198:AJ293';   % <-- colonne + lignes de lambda (S355)
range_chi_355    = 'AK198:AK293';   % <-- colonne + lignes de chi    (S355)

% --- Lecture des colonnes ---
% readmatrix renvoie un vecteur COLONNE ; on le transpose (') pour repasser
% en vecteur LIGNE, comme le reste du script l'attend.
lambda_data_690 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_690)';
chi_data_690    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_690)';

lambda_data_460 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_460)';
chi_data_460    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_460)';

lambda_data_355 = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_lambda_355)';
chi_data_355    = readmatrix(fichier_excel, 'Sheet', feuille, 'Range', range_chi_355)';

% --- Nettoyage : on retire les cellules vides ---
% Si la plage lue (ex. 'A2:A200') depasse le nombre reel de lignes remplies,
% readmatrix renvoie des NaN pour les cellules vides. On les retire ici,
% en verifiant lambda et chi ENSEMBLE (une paire est retiree si l'un des
% deux est NaN), pour ne jamais desynchroniser lambda_i et chi_i.
[lambda_data_690, chi_data_690] = nettoyer_paire(lambda_data_690, chi_data_690);
[lambda_data_460, chi_data_460] = nettoyer_paire(lambda_data_460, chi_data_460);
[lambda_data_355, chi_data_355] = nettoyer_paire(lambda_data_355, chi_data_355);

% On concatene les 3 nuances en un seul grand vecteur lambda_data / chi_data,
% car TOUTE la calibration (section 3) travaille sur l'ensemble des points,
% quelle que soit la nuance. C'est uniquement pour l'AFFICHAGE (figures)
% qu'on doit se souvenir de quelle nuance appartient chaque point : c'est
% le role du vecteur "grade_data" (un texte, ex. 'S690', associe a chaque
% valeur de lambda_data / chi_data, au meme indice).
lambda_data = [lambda_data_690, lambda_data_460, lambda_data_355];
chi_data    = [chi_data_690,    chi_data_460,    chi_data_355];
grade_data  = [repmat({'S690'}, 1, numel(lambda_data_690)), ...
               repmat({'S460'}, 1, numel(lambda_data_460)), ...
               repmat({'S355'}, 1, numel(lambda_data_355))];

% Liste des nuances et couleur associee a chacune (meme ordre dans les 2
% variables : grades_uniques{1} <-> couleurs_grade(1,:), etc.)
% Ces couleurs seront reutilisees dans toutes les figures pour que chaque
% nuance soit toujours representee de la meme facon.
grades_uniques  = {'S690', 'S460', 'S355'};
couleurs_grade  = [0.843 0.188 0.122;   % S690 -> rouge
                    0.000 0.180 0.600;   % S460 -> bleu foncé
                    0.200 0.627 0.173]; % S355 -> vert

% --- Verification de coherence ---
% Un simple garde-fou : si on a colle plus de valeurs de lambda que de chi
% (ou l'inverse), on arrete le script tout de suite avec un message clair,
% plutot que d'avoir une erreur MATLAB cryptique plus loin.
assert(length(lambda_data) == length(chi_data), ...
    'Erreur : lambda_data et chi_data doivent avoir la meme longueur.');

% On informe juste si des essais ont ete repetes (meme lambda plusieurs
% fois) : ce n'est pas une erreur, on les garde tous dans la calibration.
n_doublons = length(lambda_data) - length(unique(lambda_data));
if n_doublons > 0
    fprintf('  [INFO] %d paire(s) de valeurs dupliquees detectees et conservees.\n\n', ...
        n_doublons);
end


%% ==========================================================================
%  SECTION 2 : FONCTIONS DE LA COURBE DE FLAMBEMENT EC3
%  ==========================================================================
%  Formule de l'Eurocode 3 (EN 1993-1-1, §6.3.1) :
%     phi(alpha, lambda) = 0.5 * (1 + alpha*(lambda - 0.2) + lambda^2)
%     chi(alpha, lambda)  = min( 1 ,  1 / ( phi + sqrt(phi^2 - lambda^2) ) )
%  ou :
%     - lambda = elancement reduit (donnee d'entree, connue),
%     - alpha  = facteur d'imperfection (c'est LUI qu'on cherche a calibrer),
%     - chi    = coefficient de reduction pour le flambement (resultat).
%  Le "min(1, ...)" traduit le fait que chi ne peut physiquement pas
%  depasser 1 (au-dela, il n'y a pas de flambement, chi=1).

phi_fun = @(alpha, lam) 0.5 .* (1 + alpha .* (lam - 0.2) + lam.^2);

chi_fun = @(alpha, lam) min(1.0, ...
    1 ./ (phi_fun(alpha, lam) + sqrt(max(0, phi_fun(alpha, lam).^2 - lam.^2))));
% Le "max(0, ...)" sous la racine est une securite numerique : pour eviter
% de prendre la racine carree d'un nombre negatif si jamais phi^2 < lambda^2
% (arrondi numerique), on force ce terme a rester >= 0.

% residual_fun(alpha) : pour un alpha donne, calcule l'ecart
%   (chi predit par le modele) - (chi mesure) pour CHAQUE point de donnees.
% C'est un vecteur (autant de valeurs que de points experimentaux).
residual_fun = @(alpha) chi_fun(alpha, lambda_data) - chi_data;

% cost_fun(alpha) : somme des carres des ecarts ci-dessus (SSR = "Sum of
% Squared Residuals"). Plus cost_fun(alpha) est petit, mieux la courbe
% passe "au milieu" des points. On garde cette fonction pour comparer les
% differentes valeurs d'alpha (section 4) et pour la figure 2, mais ce
% N'EST PAS elle qui est minimisee pour choisir alpha_opt (voir section 3 :
% on veut une courbe SOUS les points, pas au milieu).
cost_fun = @(alpha) sum(residual_fun(alpha).^2);

% Bornes physiques raisonnables pour alpha (les courbes EC3 officielles
% vont de 0.13 a 0.76, on prend une plage plus large par securite).
lb = 0.01;
ub = 2.00;


%% ==========================================================================
%  SECTION 3 : CALIBRATION "CONSERVATIVE" DE ALPHA
%  ==========================================================================
%  OBJECTIF DEMANDE : la courbe calibree doit rester INFERIEURE (ou tangente)
%  a TOUS les points experimentaux -> c'est une courbe de dimensionnement
%  "du cote de la securite", pas une courbe de tendance moyenne.
%
%  PRINCIPE MATHEMATIQUE :
%  chi_fun est une fonction DECROISSANTE de alpha (plus alpha est grand,
%  plus on penalise le flambement, plus chi est petit). Donc, pour chaque
%  point experimental (lambda_i, chi_i), il existe UNE valeur alpha_i qui
%  fait que la courbe touche EXACTEMENT ce point :
%       chi_fun(alpha_i, lambda_i) = chi_i
%  Si on choisit un alpha PLUS GRAND que alpha_i, la courbe passera EN
%  DESSOUS de ce point i (puisque chi_fun decroit avec alpha).
%
%  Donc, pour que la courbe finale passe sous TOUS les points a la fois,
%  il suffit de prendre :
%       alpha_opt = max( alpha_1, alpha_2, ..., alpha_N )
%  C'est le point le "plus difficile a satisfaire" qui impose la valeur
%  finale de alpha (c'est le point qui touchera exactement la courbe ;
%  tous les autres seront strictement au-dessus).
 
% On calcule alpha_i pour chaque point, un par un, dans une boucle :
alpha_par_point = zeros(size(lambda_data));   % pre-allocation du resultat
 
for i = 1:length(lambda_data)
 
    % f(a) = (chi predit pour ce point avec le parametre a) - (chi mesure).
    % On cherche la valeur de "a" qui annule f (c'est-a-dire la racine de f).
    f = @(a) chi_fun(a, lambda_data(i)) - chi_data(i);
 
    if f(lb) <= 0
        % Meme avec le alpha le plus petit autorise (lb), la courbe est
        % DEJA sous ce point (f<=0 signifie chi_predit <= chi_mesure).
        % Pas besoin de chercher plus loin : alpha_i = lb suffit.
        alpha_par_point(i) = lb;
 
    elseif f(ub) >= 0
        % A l'inverse, meme avec le alpha maximal autorise (ub), la courbe
        % reste AU-DESSUS de ce point : on ne peut pas faire mieux dans la
        % plage autorisee, on prend alpha_i = ub (cas limite/donnee suspecte).
        alpha_par_point(i) = ub;
 
    else
        % Cas normal : f change de signe entre lb et ub, donc il existe
        % une racine exacte entre les deux. fzero() la trouve numeriquement.
        alpha_par_point(i) = fzero(f, [lb, ub]);
    end
end
 
% alpha_opt = le plus grand des alpha_i -> garantit que la courbe finale
% est sous (ou touche) TOUS les points. On le recadre dans [lb, ub] par
% securite (au cas ou un point isole aurait pousse la valeur hors bornes).
alpha_opt = min(max(max(alpha_par_point), lb), ub);
 
% --- Indicateurs de qualite de l'ajustement (a titre informatif) ---
chi_fit   = chi_fun(alpha_opt, lambda_data);   % chi predit par le modele calibre
residuals = chi_data - chi_fit;                % ecart mesure - predit (>= 0 partout,
                                                % puisque la courbe est sous les points)
SSres     = sum(residuals.^2);                        % somme des carres des ecarts
SStot     = sum((chi_data - mean(chi_data)).^2);      % variance totale des donnees
R2        = 1 - SSres / SStot;                        % coefficient de determination
RMSE      = sqrt(mean(residuals.^2));                 % erreur quadratique moyenne
MAE       = mean(abs(residuals));                     % erreur absolue moyenne
 
% Astuce laissee en commentaire : si un jour vous voulez comparer avec
% l'ancienne methode "moindres carres classiques" (courbe au milieu des
% points plutot qu'en dessous), il suffit de decommenter ces 2 lignes :
% options    = optimset('Display','off','TolX',1e-10,'TolFun',1e-14);
% alpha_lsq  = fminbnd(cost_fun, lb, ub, options);
 
 
%% ==========================================================================
%  SECTION 4 : RESUME DANS LA CONSOLE
%  ==========================================================================
%  Simple affichage texte des resultats de calibration (rien de calcule ici,
%  juste du fprintf pour lire les resultats sans ouvrir de figure).
 
fprintf('\n========================================\n');
fprintf('  CALIBRATION ALPHA - EUROCODE 3 (courbe inferieure)\n');
fprintf('========================================\n');
fprintf('  alpha calibre     : %.4f\n', alpha_opt);
fprintf('  R2                : %.6f\n', R2);
fprintf('  RMSE              : %.6f\n', RMSE);
fprintf('  MAE               : %.6f\n', MAE);
fprintf('  Nb points         : %d\n',   length(lambda_data));
fprintf('========================================\n\n');
 
% Pour reference, on compare avec le cout (SSR) qu'auraient les 5 courbes
% EC3 "officielles" (a0, a, b, c, d) sur nos donnees, meme si ce n'est pas
% ce critere qui a servi a choisir alpha_opt.
alphas_EC3 = [0.13, 0.21, 0.34, 0.49, 0.76];
noms_EC3   = {'a0', 'a', 'b', 'c', 'd'};
fprintf('  Courbes EC3 standard :\n');
for k = 1:length(alphas_EC3)
    fprintf('    Courbe %-3s (alpha=%.2f) : SSR = %.6f\n', ...
        noms_EC3{k}, alphas_EC3(k), cost_fun(alphas_EC3(k)));
end
fprintf('\n');
 
 
%% ==========================================================================
%  SECTION 5 : ANALYSE DE SENSIBILITE
%  ==========================================================================
%  But : voir a quel point le choix de alpha est "sensible", c'est-a-dire
%  dans quelle plage de alpha le cout SSR reste proche du minimum observe.
%  On balaye 1000 valeurs de alpha entre lb et ub, on calcule le SSR pour
%  chacune, puis on regarde quelles valeurs restent sous un seuil de
%  "SSR minimal + 5%".
%  (Utilise uniquement a titre informatif dans la console, et reutilise
%  pour tracer la figure 2.)
 
alpha_range    = linspace(lb, ub, 1000);
cost_range     = arrayfun(cost_fun, alpha_range);
cost_threshold = cost_fun(alpha_opt) * 1.05;
 
idx_conf = alpha_range(cost_range <= cost_threshold);
if ~isempty(idx_conf)
    fprintf('  Intervalle alpha (seuil SSR +5%%) : [%.4f, %.4f]\n\n', ...
        min(idx_conf), max(idx_conf));
end
 
 
%% ==========================================================================
%  SECTION 6 : PARAMETRES GRAPHIQUES COMMUNS (utilises par les 3 figures)
%  ==========================================================================
%  Rien de scientifique ici : ce sont juste des reglages visuels (couleurs,
%  tailles de police, epaisseurs de trait...) regroupes une seule fois pour
%  que les 3 figures aient un style coherent.
 
% lam_plot : un vecteur "lisse" de 400 valeurs de lambda entre 0 et
% (max des donnees * 1.1), utilise uniquement pour TRACER les courbes
% theoriques (EC3 et courbe calibree) -- ce n'est pas une donnee mesuree.
lam_plot = linspace(0, max(lambda_data) * 1.1, 400);
 
col_opt  = [0.10, 0.10, 0.10];       % couleur de la courbe calibree (noir)
col_EC3  = [0.650, 0.650, 0.650];    % couleur des courbes EC3 standard (gris)
col_b    = [0.200, 0.627, 0.173];    % couleur specifique pour la courbe "b" (vert, reference visuelle)
 
styles_EC3 = {'--', ':', '-.', '--', ':'};   % un style de trait different par courbe EC3 (a0,a,b,c,d)
 
fs_label = 17;   % taille de police des labels d'axes
fs_title = 14;   % taille de police des titres
fs_tick  = 11;   % taille de police des graduations
fs_leg   = 10;   % taille de police des legendes
lw_main  = 2.0;  % epaisseur de trait de la courbe principale (calibree)
lw_EC3   = 1.0;  % epaisseur de trait des courbes EC3 standard
 
% Petite fonction reutilisable qui applique le meme style "propre" (fond
% blanc, texte noir, grille legere...) a n'importe quel axe qu'on lui passe.
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
%  SECTION 7 : FIGURE 1 - Courbes de flambement (legende par nuance)
%  ==========================================================================
%  Cette figure superpose :
%   (a) les 5 courbes EC3 standard (a0,a,b,c,d), en arriere-plan, en gris,
%   (b) les points experimentaux, colores par nuance d'acier,
%   (c) la courbe calibree (enveloppe inferieure), en noir, au-dessus.
 
f1 = figure('Name', 'Courbes de flambement', ...
    'Color', 'white', 'Position', [80 120 720 520]);
ax1 = axes(f1);
hold(ax1, 'on');   % permet de superposer plusieurs trace() sur le meme graphique
grid(ax1, 'on');
 
% --- (a) Courbes EC3 standard en arriere-plan ---
for k = 1:length(alphas_EC3)
    chi_k = chi_fun(alphas_EC3(k), lam_plot);   % courbe theorique pour ce alpha EC3
    if alphas_EC3(k) == 0.34
        % La courbe "b" (alpha=0.34) est mise en valeur en vert, car c'est
        % souvent la courbe de reference pour l'acier courant.
        plot(ax1, lam_plot, chi_k, styles_EC3{k}, ...
            'Color', col_b, 'LineWidth', lw_EC3 + 0.4, ...
            'DisplayName', sprintf('EC3 - %s  (\\alpha=%.2f)', noms_EC3{k}, alphas_EC3(k)));
    else
        plot(ax1, lam_plot, chi_k, styles_EC3{k}, ...
            'Color', col_EC3, 'LineWidth', lw_EC3, ...
            'DisplayName', sprintf('EC3 - %s  (\\alpha=%.2f)', noms_EC3{k}, alphas_EC3(k)));
    end
end
 
% --- (b) Points experimentaux, un groupe de points par nuance ---
% On boucle sur chaque nuance ; "idxg" est un masque logique (true/false)
% qui selectionne uniquement les points de cette nuance dans lambda_data /
% chi_data. Chaque appel a scatter() cree une entree distincte dans la
% legende (le nom de la nuance), avec sa couleur dediee.
% Un marqueur different par nuance (en plus de la couleur) : o, carre, etoile a 5 branches.
% L'ordre correspond a grades_uniques : {1}='S690'->o, {2}='S460'->carre, {3}='S355'->etoile (pentagram).
% Note : '*' en MATLAB est un asterisque (pas une vraie etoile) ; 'p' (pentagram) donne une etoile a 5 branches (star).
marqueurs_grade = {'o', 's', 'p'};
 
for g = 1:length(grades_uniques)
    idxg = strcmp(grade_data, grades_uniques{g});
    if any(idxg)   % on ne trace/legende que les nuances qui ont des points
        scatter(ax1, lambda_data(idxg), chi_data(idxg), 40, couleurs_grade(g,:), 'filled', marqueurs_grade{g}, ...
            'MarkerEdgeColor', 'black', 'LineWidth', 0.6, ...
            'DisplayName', grades_uniques{g});
    end
end
 
% --- (c) Courbe calibree (enveloppe inferieure) ---
% Rappel : chi(lambda=0) = 1 est deja garanti par les mathematiques de la
% formule EC3 (voir section 2 : a lambda=0, phi < 0.5, donc chi > 1, ce qui
% est plafonne exactement a 1). On force malgre tout explicitement le
% premier point du vecteur trace a 1, en verrou de securite numerique.
chi_plot_opt = chi_fun(alpha_opt, lam_plot);
chi_plot_opt(1) = 1;
 
plot(ax1, lam_plot, chi_plot_opt, '-', ...
    'Color', col_opt, 'LineWidth', lw_main + 0.5, ...
    'DisplayName', sprintf('Courbe calibree \\alpha = %.3f', alpha_opt));
 
% Ligne horizontale chi = 1 (limite physique superieure), juste pour
% reperer visuellement ce plafond. 'HandleVisibility','off' = n'apparait
% pas dans la legende (ce n'est qu'un repere visuel, pas une donnee).
plot(ax1, [0 max(lam_plot)], [1 1], '-', ...
    'Color', [0.5 0.5 0.5], 'LineWidth', 0.7, 'HandleVisibility', 'off');
 
% --- Habillage du graphique (titres, axes, legende) ---
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
 
styleAxe(ax1);   % applique le style commun defini en section 6
 
 
%% ==========================================================================
%  SECTION 8 : FIGURE 2 - Fonction cout (SSR) en fonction de alpha
%  ==========================================================================
%  Cette figure sert a VISUALISER l'analyse de sensibilite de la section 5 :
%  comment le cout SSR varie avec alpha, ou se situent les courbes EC3
%  standard, et ou se trouve le alpha finalement retenu.
%  Note : cette figure utilise le critere SSR (moindres carres) uniquement
%  pour information/comparaison ; ce n'est pas ce critere qui a determine
%  alpha_opt (voir section 3).
 
f2 = figure('Name', 'Fonction cout vs alpha', ...
    'Color', 'white', 'Position', [120 90 720 520]);
ax2 = axes(f2);
hold(ax2, 'on');
grid(ax2, 'on');
 
% Courbe du cout SSR pour chaque valeur de alpha testee
plot(ax2, alpha_range, cost_range, '-', ...
    'Color', 'black', 'LineWidth', lw_main, ...
    'DisplayName', 'Fonction cout SSR');
 
% Ligne horizontale du seuil "SSR minimal + 5%" (voir section 5)
plot(ax2, alpha_range, repmat(cost_threshold, size(alpha_range)), '--', ...
    'Color', [0.5 0.5 0.5], 'LineWidth', 1.0, ...
    'DisplayName', 'Seuil SSR +5%');
 
% Traits verticaux pour repere les 5 valeurs de alpha EC3 standard
for k = 1:length(alphas_EC3)
    xline(ax2, alphas_EC3(k), ':', 'Color', col_EC3, 'LineWidth', 1.0, ...
        'Label', noms_EC3{k}, 'FontSize', 10, 'FontName', 'Helvetica', ...
        'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
end
 
% Marqueur sur le alpha finalement retenu (celui de l'enveloppe inferieure)
scatter(ax2, alpha_opt, cost_fun(alpha_opt), 100, col_opt, 'filled', 'd', ...
    'MarkerEdgeColor', 'black', 'LineWidth', 0.8, ...
    'DisplayName', sprintf('Alpha retenu (enveloppe inf.)   \\alpha = %.4f', alpha_opt));
 
xlabel(ax2, '\alpha  (facteur d''imperfection)', ...
    'FontSize', fs_label, 'FontName', 'Helvetica', 'Color', 'black');
ylabel(ax2, 'SSR  (somme des residus au carre)', ...
    'FontSize', fs_label, 'FontName', 'Helvetica', 'Color', 'black');
title(ax2, 'Fonction cout vs \alpha', ...
    'FontSize', fs_title, 'FontName', 'Helvetica', 'FontWeight', 'bold', 'Color', 'black');
 
xlim(ax2, [lb, min(ub, 1.0)]);
 
leg2 = legend(ax2, 'Location', 'northeast', 'FontSize', fs_leg, ...
    'FontName', 'Helvetica', 'TextColor', 'black', 'EdgeColor', 'black', 'Color', 'white');
set(leg2, 'Color', 'white', 'TextColor', 'black', 'EdgeColor', 'black');
 
styleAxe(ax2);
 
 
%% ==========================================================================
%  SECTION 9 : FIGURE 3 - Residus point par point (par nuance)
%  ==========================================================================
%  Un "residu" = chi mesure - chi predit par le modele calibre, pour chaque
%  point. Comme la courbe est une enveloppe inferieure, tous les residus
%  sont >= 0 (les points sont tous au-dessus ou sur la courbe).
%  On trie les points par lambda croissant pour un affichage plus lisible.
 
[lam_sort, idx_sort] = sort(lambda_data);
res_sort   = residuals(idx_sort);     % on reordonne les residus dans le meme ordre
grade_sort = grade_data(idx_sort);    % ...et les nuances aussi (meme indice = meme point)
 
f3 = figure('Name', 'Residus', ...
    'Color', 'white', 'Position', [160 60 720 520]);
ax3 = axes(f3);
hold(ax3, 'on');
grid(ax3, 'on');
 
% Un "stem" (baton + marqueur) par nuance, pour garder le code couleur
% coherent avec la figure 1 et avoir une legende par nuance ici aussi.
for g = 1:length(grades_uniques)
    idxg = strcmp(grade_sort, grades_uniques{g});
    if any(idxg)
        stem(ax3, lam_sort(idxg), res_sort(idxg), ...
            'filled', 'Color', couleurs_grade(g,:), ...
            'MarkerFaceColor', couleurs_grade(g,:), 'MarkerEdgeColor', 'black', ...
            'LineWidth', 1.4, 'MarkerSize', 7, ...
            'DisplayName', grades_uniques{g});
    end
end
 
% Ligne horizontale a 0 (residu nul = la courbe touche exactement le point)
plot(ax3, [min(lam_sort)-0.1, max(lam_sort)+0.1], [0 0], '-', ...
    'Color', 'black', 'LineWidth', 1.2, 'HandleVisibility', 'off');
 
% Ligne horizontale au niveau du RMSE, pour donner un ordre de grandeur
% de l'ecart "typique" entre points et courbe calibree.
plot(ax3, [min(lam_sort)-0.1, max(lam_sort)+0.1], [RMSE RMSE], '--', ...
    'Color', col_opt, 'LineWidth', 1.2, 'DisplayName', sprintf('RMSE = %.4f', RMSE));
 
xlabel(ax3, '\lambda  (elancement reduit)', ...
    'FontSize', fs_label, 'FontName', 'Helvetica', 'Color', 'black');
ylabel(ax3, '\chi_{exp} - \chi_{fit}  (\geq 0 par construction)', ...
    'FontSize', fs_label, 'FontName', 'Helvetica', 'Color', 'black');
title(ax3, 'Residus point par point', ...
    'FontSize', fs_title, 'FontName', 'Helvetica', 'FontWeight', 'bold', 'Color', 'black');
 
leg3 = legend(ax3, 'Location', 'best', 'FontSize', fs_leg, ...
    'FontName', 'Helvetica', 'TextColor', 'black', 'EdgeColor', 'black', 'Color', 'white');
set(leg3, 'Color', 'white', 'TextColor', 'black', 'EdgeColor', 'black');
 
styleAxe(ax3);
 
 
%% ==========================================================================
%  SECTION 10 : TABLEAU DES RESIDUS (avec nuance) dans la console
%  ==========================================================================
%  Impression texte, point par point, pour pouvoir inspecter les valeurs
%  precises (utile pour reperer un point aberrant par exemple).
 
fprintf('  Tableau des residus :\n');
fprintf('  %-8s %-12s %-12s %-12s %-12s %-12s\n', ...
    'nuance', 'lambda', 'chi_exp', 'chi_fit', 'residus', 'residus(%)');
fprintf('  %s\n', repmat('-', 1, 70));
for i = 1:length(lambda_data)
    pct = 100 * abs(residuals(i)) / max(chi_data(i), 1e-9);   % max(...,1e-9) evite une division par 0
    fprintf('  %-8s %-12.4f %-12.4f %-12.4f %-12.4f %-12.2f\n', ...
        grade_data{i}, lambda_data(i), chi_data(i), chi_fit(i), residuals(i), pct);
end
fprintf('\n');
 
 
%% ==========================================================================
%  FONCTION LOCALE : nettoyer_paire
%  ==========================================================================
%  Retire les cellules vides (NaN) lues depuis Excel, en s'assurant que
%  lambda et chi restent bien apparies (si l'un des deux est NaN a l'indice
%  i, on retire la paire complete a cet indice, pas seulement la valeur NaN).
%  Doit rester a la toute fin du fichier (regle MATLAB pour les fonctions
%  locales dans un script).
function [lambda_propre, chi_propre] = nettoyer_paire(lambda_brut, chi_brut)
    valide        = ~isnan(lambda_brut) & ~isnan(chi_brut);
    lambda_propre = lambda_brut(valide);
    chi_propre    = chi_brut(valide);
end

%%

