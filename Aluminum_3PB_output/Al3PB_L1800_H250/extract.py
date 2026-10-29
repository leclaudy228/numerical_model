from odbAccess import openOdb
odb = openOdb('Al3PB_L1800_H250.odb', readOnly=True)
st = odb.steps['THREE_POINT_BENDING']
def hist(setname, var):
    lab = {'RP_LEFT':5953,'RP_RIGHT':5954,'RP_LOAD':5955}[setname]
    reg = [r for k, r in st.historyRegions.items() if k.endswith('.%d' % lab)][0]
    return reg.historyOutputs[var].data
u = hist('RP_LOAD','U3'); f = hist('RP_LOAD','RF3')
rl = hist('RP_LEFT','RF3'); rr = hist('RP_RIGHT','RF3')
out = open('load_disp.csv','w'); out.write('disp_mm,load_kN,Rleft_kN,Rright_kN\n')
for i in range(len(u)):
    out.write('%.4f,%.4f,%.4f,%.4f\n' % (-u[i][1], -f[i][1]/1e3, rl[i][1]/1e3, rr[i][1]/1e3))
out.close()
fr = st.frames[-1]; pe = fr.fieldOutputs['PEEQ']
print('max PEEQ final', max(v.data for v in pe.values))
odb.close()
