
clear  
clc  
if 1==1
    parameters = xlsread('Aluminium Database_2024-12-01 - 66 sections.xlsm','Filtered_database');
    save('W_simple','parameters')
else
    load('W_simple.mat');
end


nb=size(parameters,1);

xdata=parameters(1:end,37); 
ydata=parameters(1:end,33);
fdata=parameters(1:end,91);
radius=parameters(1:end,13);
fy=parameters(1:end,31);
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    (Chi<1)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1==0
Lamda_0=0.60;
if 1==0
Khi=@(s,xdata)min(1,1./( (0.5.*(1+( s(1).*fdata + s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3))))...
        +(max(0,( (0.5.*(1+(s(1).*fdata+s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3)))).^2)...
        -(xdata.^ (s(3))))).^0.5));


s0= [ -0.0245    0.1828   -0.1465];

for i=1:150
s=lsqcurvefit(Khi, s0, xdata, ydata);
s0=s;
end
s
end

s = [ 0.01    0.1   0.35];


Alfa=s(1).*fdata+s(2);
Beita=s(3);
Pesi=0.5.*(1+Alfa.*(xdata-Lamda_0)+xdata.^Beita);
Khi_test=min(1,1./(Pesi+(max(0,(Pesi.*Pesi)-(xdata.^Beita))).^0.5));

Khi_OIC=min(1,1./( (0.5.*(1+(s(1).*fdata+s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3))))...
        +(max(0,( (0.5.*(1+(s(1).*fdata+s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3)))).^2)...
        -(xdata.^ (s(3))))).^0.5));
    
aaa=Khi_OIC-Khi_test;
curve_results=zeros(2/0.05,2);
count=1;
for lamda_curve=0:0.05:2
    fdata_curve=6;
    %s=[0.25    0.01   0.3    0.4];

    Alfa=s(1)*fdata_curve+s(2);
    Beita=s(3);
    Pesi=0.5*(1+Alfa*(lamda_curve-Lamda_0)+lamda_curve^Beita);
    Khi_curve=min(1,1/(Pesi+(max(0,(Pesi*Pesi)-(lamda_curve^Beita)))^0.5));
    
    curve_results(count,1)=lamda_curve;
    curve_results(count,2)=Khi_curve;
    count=count+1;
end

end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   N (Chi<1)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1==0
Lamda_0=0.60;
if 1==0
Khi=@(s,xdata)min(1,1./( (0.5.*(1+( s(1).*fdata + s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3).*fdata+s(4))))...
        +(max(0,( (0.5.*(1+(s(1).*fdata+s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3).*fdata+s(4)))).^2)...
        -(xdata.^ (s(3).*fdata+s(4))))).^0.5));


s0= [ -0.0245    0.1828   -0.1465    0.9766];

for i=1:150
s=lsqcurvefit(Khi, s0, xdata, ydata);
s0=s;
end
s
end

s = [ 0.05    0.05   0.0    0.4];


Alfa=s(1).*fdata+s(2);
Beita=s(3).*fdata+s(4);
Pesi=0.5.*(1+Alfa.*(xdata-Lamda_0)+xdata.^Beita);
Khi_test=min(1,1./(Pesi+(max(0,(Pesi.*Pesi)-(xdata.^Beita))).^0.5));

Khi_OIC=min(1,1./( (0.5.*(1+(s(1).*fdata+s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3).*fdata+s(4))))...
        +(max(0,( (0.5.*(1+(s(1).*fdata+s(2)).*(xdata-Lamda_0)...
        +xdata.^ (s(3).*fdata+s(4)))).^2)...
        -(xdata.^ (s(3).*fdata+s(4))))).^0.5));
    
aaa=Khi_OIC-Khi_test;
curve_results=zeros(2/0.05,2);
count=1;
for lamda_curve=0:0.05:2
    fdata_curve=6;
    %s=[0.25    0.01   0.3    0.4];

    Alfa=s(1)*fdata_curve+s(2);
    Beita=s(3)/fdata_curve+s(4);
    Pesi=0.5*(1+Alfa*(lamda_curve-Lamda_0)+lamda_curve^Beita);
    Khi_curve=min(1,1/(Pesi+(max(0,(Pesi*Pesi)-(lamda_curve^Beita)))^0.5));
    
    curve_results(count,1)=lamda_curve;
    curve_results(count,2)=Khi_curve;
    count=count+1;
end

end


%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   N (Chi>1)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1==1
Lamda_0=0.6;
if 1==1
Khi=@(s,xdata)( s(1)*(xdata-Lamda_0)+1 );

s0=[-1];

for i=1:150
s=lsqcurvefit(Khi, s0, xdata, ydata);
s0=s;
end
s
end
   %s = -0.25
Khi_OIC=s(1)*(xdata-Lamda_0)+1;

curve_results=zeros(2/0.05,2);
count=1;
for lamda_curve=0:0.05:2
    %s=[0.25    0.01   0.3    0.4];

    Khi_curve=s(1)*(lamda_curve-Lamda_0)+1;
    
    curve_results(count,1)=lamda_curve;
    curve_results(count,2)=Khi_curve;
    count=count+1;
end

end



%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   My(Chi<1)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1==0
Lamda_0=0.6;
if 1==0

Khi=@(s,xdata)min(1,1./( (0.5.*(1+ s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2)))...
        +(max(0,( (0.5.*(1+s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2))).^2)...
        -(xdata.^ s(2)))).^0.5));
s0=[2    1];


for i=1:100
s=lsqcurvefit(Khi, s0, xdata, ydata);
s0=s;
end
s
end

s=[2    1]

Alfa=s(1);
Beita=s(2);
Pesi=0.5.*(1+Alfa.*(xdata-Lamda_0)+xdata.^Beita);
Khi_test=min(1,1./(Pesi+(max(0,(Pesi.^2)-(xdata.^Beita))).^0.5));

Khi_OIC=min(1,1./( (0.5.*(1+ s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2)))...
        +(max(0,( (0.5.*(1+s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2))).^2)...
        -(xdata.^ s(2)))).^0.5));
for o=1:size(xdata)
     if xdata(o)<Lamda_0
         Khi_OIC(o)=1;
     end
end
aaa=Khi_OIC-Khi_test;

end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   My (Chi>1)  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1==0
Lamda_0=0.6;
if 1==0
Khi=@(s,xdata)( s(1)*(xdata-Lamda_0)+s(2)*(xdata-Lamda_0).^2+1 );

s0=[ -1.1912 1];

for i=1:150
s=lsqcurvefit(Khi, s0, xdata, ydata);
s0=s;
end
s
end
 s=[ -1 -1.6];

Khi_OIC=s(1)*(xdata-Lamda_0)+s(2)*(xdata-Lamda_0).^2+1;

curve_results=zeros(2/0.05,2);
count=1;
for lamda_curve=0:0.05:2
    %s=[0.25    0.01   0.3    0.4];

    Khi_curve=s(1)*(lamda_curve-Lamda_0)+1;
    
    curve_results(count,1)=lamda_curve;
    curve_results(count,2)=Khi_curve;
    count=count+1;
end

end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   Mz(Chi<1)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1==0
Lamda_0=0.6;
if 1==0
Khi=@(s,xdata)min(1,1./( (0.5.*(1+ s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2)))...
        +(max(0,( (0.5.*(1+s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2))).^2)...
        -(xdata.^ s(2)))).^0.5));
s0=[2    1];


for i=1:100
s=lsqcurvefit(Khi, s0, xdata, ydata);
s0=s;
end
s
end


s=[0.1    0.8];
Alfa=s(1);
Beita=s(2);
Pesi=0.5.*(1+Alfa.*(xdata-Lamda_0)+xdata.^Beita);
Khi_test=min(1,1./(Pesi+(max(0,(Pesi.^2)-(xdata.^Beita))).^0.5));

Khi_OIC=min(1,1./( (0.5.*(1+ s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2)))...
        +(max(0,( (0.5.*(1+s(1).*(xdata-Lamda_0)...
        +xdata.^ s(2))).^2)...
        -(xdata.^ s(2)))).^0.5));
for o=1:size(xdata)
     if xdata(o)<Lamda_0
         Khi_OIC(o)=1;
     end
end
aaa=Khi_OIC-Khi_test;

end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   Mz (Chi>1)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if 1==0
Lamda_0=0.6;
if 1==0
    
%Khi=@(s,xdata)( (s(1)+s(2).*radius.^(0.5)).*(xdata-Lamda_0)+(s(3)+s(4).*radius.^(1)).*(xdata-Lamda_0).^2 + 1 );
Khi=@(s,xdata)( (s(1)+s(2).*radius.^(0.5)).*(xdata-Lamda_0)+ + 1 );

s0=[ 1 1 ];

for i=1:150
s=lsqcurvefit(Khi, s0, xdata, ydata);
s0=s;
end
s
end
s=[ -0.15 -0.11];

% Khi_OIC=(s(1)+s(2).*radius.^(0.5)).*(xdata-Lamda_0)+(s(3)+s(4).*radius.^(1)).*(xdata-Lamda_0).^2+1;
Khi_OIC=(s(1)+s(2).*radius.^(0.5)).*(xdata-Lamda_0)+1;

curve_results=zeros(2/0.05,2);
count=1;
for lamda_curve=0:0.05:2
    %s=[0.25    0.01   0.3    0.4];

    Khi_curve=s(1)*(lamda_curve-Lamda_0)+1;
    
    curve_results(count,1)=lamda_curve;
    curve_results(count,2)=Khi_curve;
    count=count+1;
end

end


figure(1)
scatter(xdata,ydata,'r','filled')
hold on;
scatter(xdata,Khi_OIC,'b','filled')
grid on
xlabel('Lambda_L'),ylabel('Chi_L');
legend('FE','OIC');
xlim([0 3]);
ylim([0.2 1.5]);
hold off

figure(2)
histfit(Khi_OIC./ydata,25);
set(gca,'xTickLabel',num2str(get(gca,'xTick')','%.2f'));
set(gca,'yTickLabel',num2str(get(gca,'yTick')','%.0f'));
%set(gca,'xtick',0.97:0.01:1.05);
%xlim([0.97 1.05]);
%set(gca,'YAxisLocation','right'); 
h=findobj(gca,'Type','patch');
set(h,'facecolor','b');
%xlim([0.85 1.25]);
grid on;
xlabel('OIC/FE','fontname','Times New Roman','FontSize',15);
ylabel('number','fontname','Times New Roman','FontSize',15)
title([num2str(length(Khi_OIC./ydata)), ' cases'],'fontname','Times New Roman','FontSize',15);
[n,hx]=hist(Khi_OIC./ydata,25);
str = mat2cell(num2str(n'));
%str = mat2cell(num2str(n'), ones(size(n')), size(num2str(n', '%.0f'), 2));
text(hx,n+0.3,str,'Color','r');

qq=Khi_OIC./ydata;
OIC_over_FE=[mean(Khi_OIC./ydata) std(Khi_OIC./ydata)./mean(Khi_OIC./ydata) max(Khi_OIC./ydata) min(Khi_OIC./ydata)]
SUM_number=[sum(sum(qq>1.03)) sum(sum(qq>1.10)) sum(sum(qq>1.25))]