# -*- coding: mbcs -*-
#
# Abaqus/Viewer Release 2025 replay file
# Internal Version: 2024_09_20-09.00.46 RELr427 198590
# Run by KOATT6 on Wed Oct 28 20:19:05 2026
#

# from driverUtils import executeOnCaeGraphicsStartup
# executeOnCaeGraphicsStartup()
#: Executing "onCaeGraphicsStartup()" in the site directory ...
from abaqus import *
from abaqusConstants import *
session.Viewport(name='Viewport: 1', origin=(0.0, 0.0), width=225.302871704102, 
    height=123.841659545898)
session.viewports['Viewport: 1'].makeCurrent()
session.viewports['Viewport: 1'].maximize()
from viewerModules import *
from driverUtils import executeOnCaeStartup
executeOnCaeStartup()
o2 = session.openOdb(name='Al3PB_L1800_H250.odb')
#: Model: C:/Kokou/Kokou_Case_study_1_Steel_Column/Numerical model_validation/Aluminum_3PB_output/Al3PB_L1800_H250/Al3PB_L1800_H250.odb
#: Number of Assemblies:         1
#: Number of Assembly instances: 0
#: Number of Part instances:     1
#: Number of Meshes:             1
#: Number of Element Sets:       20
#: Number of Node Sets:          16
#: Number of Steps:              1
session.viewports['Viewport: 1'].setValues(displayedObject=o2)
session.viewports['Viewport: 1'].makeCurrent()
session.viewports['Viewport: 1'].view.setValues(nearPlane=3293.6, 
    farPlane=4466.07, width=3186.07, height=1429.95, cameraPosition=(1022.13, 
    974.002, 3867.89), cameraUpVector=(-0.87902, 0.465757, -0.101953), 
    cameraTarget=(-31.6495, 963.145, 94.4045))
session.viewports['Viewport: 1'].view.setValues(nearPlane=2889.8, 
    farPlane=4798.73, width=2795.46, height=1254.64, cameraPosition=(2235.82, 
    -679.561, 2825.33), cameraUpVector=(-0.855491, 0.301834, 0.420751), 
    cameraTarget=(-43.5498, 979.358, 104.627))
session.viewports['Viewport: 1'].view.setValues(nearPlane=2565.87, 
    farPlane=5057.54, width=2482.11, height=1114, cameraPosition=(1382.68, 
    -2408.61, 1419.25), cameraUpVector=(-0.70906, 0.325058, 0.625757), 
    cameraTarget=(-27.2134, 1012.47, 131.551))
session.viewports['Viewport: 1'].view.setValues(nearPlane=2850.45, 
    farPlane=4772.96, width=751.943, height=337.481, viewOffsetX=-249.834, 
    viewOffsetY=18.9833)
session.viewports['Viewport: 1'].odbDisplay.display.setValues(plotState=(
    CONTOURS_ON_DEF, ))
session.viewports['Viewport: 1'].view.setValues(nearPlane=2717.65, 
    farPlane=4932.07, width=1813.62, height=813.976, viewOffsetX=-195.043, 
    viewOffsetY=-59.4357)
session.viewports['Viewport: 1'].view.setValues(nearPlane=2840.7, 
    farPlane=4595.35, width=1895.74, height=850.833, cameraPosition=(1413.16, 
    -1021.86, 2954.85), cameraUpVector=(-0.929164, 0.275631, 0.246337), 
    cameraTarget=(-141.01, 1083.16, 38.827), viewOffsetX=-203.875, 
    viewOffsetY=-62.127)
session.viewports['Viewport: 1'].view.setValues(nearPlane=2736.61, 
    farPlane=4377.09, width=1826.28, height=819.656, cameraPosition=(1067.36, 
    2583.9, 3064.51), cameraUpVector=(-0.72507, -0.63095, 0.275999), 
    cameraTarget=(-394.87, 807.314, -106.507), viewOffsetX=-196.404, 
    viewOffsetY=-59.8505)
session.viewports['Viewport: 1'].view.setValues(nearPlane=3158.91, 
    farPlane=4003.01, width=2108.1, height=946.142, cameraPosition=(2255.44, 
    1097.13, 2883.63), cameraUpVector=(-0.917798, -0.122432, 0.3777), 
    cameraTarget=(-362.524, 1064.11, -30.9683), viewOffsetX=-226.712, 
    viewOffsetY=-69.0864)
session.viewports['Viewport: 1'].view.setValues(nearPlane=2685.16, 
    farPlane=4528.3, width=1791.94, height=804.245, cameraPosition=(2786.32, 
    -1054.48, 1290.81), cameraUpVector=(-0.658225, 0.0577898, 0.7506), 
    cameraTarget=(-223.51, 1212.03, 216.781), viewOffsetX=-192.711, 
    viewOffsetY=-58.7252)
session.viewports['Viewport: 1'].view.setValues(nearPlane=2555.2, 
    farPlane=4724.29, width=1705.21, height=765.322, cameraPosition=(1870.42, 
    -2061.33, 1092.12), cameraUpVector=(-0.596889, 0.240403, 0.76546), 
    cameraTarget=(-73.9496, 1233.42, 247.295), viewOffsetX=-183.384, 
    viewOffsetY=-55.883)
