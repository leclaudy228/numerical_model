% Plot midspan load vs displacement for the Al3PB_L1800_H250 run.
d = readtable(fullfile(fileparts(mfilename('fullpath')),'load_disp.csv'));
[Pmax,i] = max(d.load_kN);
f = figure('Color',[.988 .988 .984],'Position',[100 100 760 480]);
ax = axes(f,'Color',[.988 .988 .984],'XColor',[.32 .32 .31],'YColor',[.32 .32 .31], ...
    'FontSize',10,'GridColor',[.85 .85 .83],'GridAlpha',1,'Box','off','TickDir','out');
hold(ax,'on'); grid(ax,'on');
plot(ax,d.disp_mm,d.load_kN,'-','Color',[.165 .471 .839],'LineWidth',2);
plot(ax,d.disp_mm,d.load_kN,'o','MarkerSize',4,'MarkerFaceColor',[.165 .471 .839], ...
    'MarkerEdgeColor',[.988 .988 .984]);
plot(ax,d.disp_mm(i),Pmax,'o','MarkerSize',8,'MarkerFaceColor',[.165 .471 .839], ...
    'MarkerEdgeColor',[.988 .988 .984],'LineWidth',1.5);
text(ax,d.disp_mm(i),Pmax+5,sprintf('Peak %.1f kN at %.1f mm',Pmax,d.disp_mm(i)), ...
    'HorizontalAlignment','center','FontSize',10,'Color',[.043 .043 .043]);
xlabel(ax,'Midspan displacement (mm)'); ylabel(ax,'Applied load P (kN)');
title(ax,'Al3PB\_L1800\_H250: load vs midspan displacement','FontWeight','normal', ...
    'Color',[.043 .043 .043]);
xlim(ax,[0 31]); ylim(ax,[0 140]);
exportgraphics(f,fullfile(fileparts(mfilename('fullpath')),'load_disp.png'),'Resolution',200);
