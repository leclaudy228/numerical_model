# Welded aluminum I-section: three-point bending

This self-contained MATLAB generator follows the welded plate/shell approach in
`Welded_I_section_Equation_General_OK_beam.m`. It generates an Abaqus/Standard
S4R model without the steel script's CUFSM, Excel, numbered input files, end
compression loads, or hard-coded study loop. Existing generators are unchanged.

## Excel input workbook

Edit and save **Aluminum_3PB_Input.xlsx**, then run:

```matlab
model = run_aluminum_3pb_excel();
% Or select another workbook:
model = run_aluminum_3pb_excel('C:\my_study\Aluminum_3PB_Input.xlsx');
% Read inputs without generating a model:
c = read_aluminum_3pb_excel('Aluminum_3PB_Input.xlsx');
```

The workbook has Instructions, Control, Geometry, HAZ, Analysis, Stiffeners,
Materials, Plastic, and Regions sheets. Keep sheet names, headers and parameter
keys unchanged; edit the input values. Stiffener/region rows use Enabled=0/1.
Material IDs 1-8 have fixed component meanings; additional IDs must be contiguous.
Each material's Plastic rows must be ordered by increasing plastic strain.
Blank region bounds mean unlimited extent in that direction. Relative output
folders are resolved from the workbook folder. Update stiffener positions when
changing the span. Use plain numbers, or recalculate and save formulas in Excel
before reading their cached values. No VBA/macros or Excel installation are
required by the MATLAB reader.

Run `test_aluminum_3pb_excel` in MATLAB to check parsing and workbook-to-deck
generation. The template's Python round-trip checks passed; MATLAB execution
remains unverified in this environment. To create a fresh template, use
`py create_aluminum_3pb_workbook.py other_inputs.xlsx` with Python/openpyxl.
Existing workbooks are preserved unless `--force` is explicitly supplied.

```matlab
c = aluminum_welded_3pb_config();
% Edit geometry, mesh, HAZ widths, materials and stiffeners here or in config.
c.materials(1).plastic = readmatrix('web_base_true_stress_plastic_strain.csv');
c.materials(2).plastic = readmatrix('web_HAZ_true_stress_plastic_strain.csv');
model = Aluminum_Welded_I_section_3PB(c);
```

Running `Aluminum_Welded_I_section_3PB` without arguments uses the example.
MATLAB R2023a is the intended environment. Output is an `.inp`, a mesh/config
`.mat` file, an element-to-region `.csv`, and an optional material-region plot.
From the output directory, run:

```text
abaqus job=Aluminum_Welded_I_3PB input=Aluminum_Welded_I_3PB.inp datacheck interactive
abaqus job=Aluminum_Welded_I_3PB input=Aluminum_Welded_I_3PB.inp interactive
```

## Coordinates and loading

All units are N, mm, MPa. The member runs along **y**; flange width is **x**,
and height is **z**. `height` includes both flange thicknesses. Shell flange
planes are at half the bottom thickness and height minus half the top thickness.
The web joins those planes. Plate intersections share nodes, idealizing a fully
connected weld; weld beads and local weld notch geometry are not represented.

Lower-flange bearing lines are at y=0 and y=L; the upper-flange loading line is
at y=L/2. Vertical-only kinematic couplings keep each bearing/loading line level
across its width. This provides torsional restraint at these lines. The left
center node fixes axial movement; the right end can slide along y. Lateral
guides act at the two support center nodes and, by default, the load center node.
Set `lateralGuideAtLoad=false` to remove that additional lateral guide.
These are idealized bearing constraints, not rollers modeled with contact,
lift-off, finite bearing patches, or friction.

The nonlinear static step applies negative U3 to the central reference node.
`analysis.displacement` is its positive downward magnitude. History output
includes U3 and RF3 at all three reference nodes. Plot `-U3` against `-RF3` at
RP_LOAD for positive downward displacement and positive applied load; compare
the two support RF3 values with their sum for equilibrium. For a small-deflection
central load P, the reference elastic moment diagram peaks at P*L/4.

## User-selected stiffeners

Stiffeners are transverse shell plates spanning the web height and joined to
both flanges and the web. Define each side separately:

```matlab
c.stiffeners = struct('position',{400,1200,1200}, ...
    'side',{1,1,-1}, 'width',{50,65,65}, 'thickness',{5,8,8});
% Or remove every stiffener:
c.stiffeners = c.stiffeners([]);
```

Positions are measured along y from the left support. Side is +1 or -1 in x.
Width is measured from the web mid-plane; the ideal shell plate starts there.
Each plate has its own thickness. Width must fit within both flange half-widths.
The example has pairs at both supports and under the center load.

## HAZ and material regions

The first eight material entries are web base/HAZ, top base/HAZ, bottom base/HAZ,
and stiffener base/HAZ, in that order. Edit each E, nu, and plastic curve
independently. All example curves are illustrative, with no alloy/temper claim.
They must be replaced for research or capacity predictions.

`plastic` columns are **true stress, equivalent plastic strain**; the first
plastic strain must be zero, subsequent strains strictly increase, and stress
must not decrease. An empty plastic matrix gives an elastic-only material.
Engineering total strain must not be copied directly into this field.

`haz.flangeWidth` extends outwards from the web face at the longitudinal weld.
`haz.webWidth` extends from each flange inner face into the clear web.
`haz.stiffenerWidth` extends outwards from transverse stiffener faces along y,
and from the web/flange faces into each stiffener plate. Intersecting HAZ bands
use the affected component's HAZ material. These widths describe a prescribed
material zoning scheme, not a thermal welding simulation.

For an independently prescribed area, append a material and a box region:

```matlab
c.materials(9) = c.materials(2);
c.materials(9).name = 'MY_WEB_ZONE';
c.materials(9).plastic = readmatrix('my_zone_curve.csv');
c.regions(1) = struct('component',1, ...
    'bounds',[-inf inf; 900 1500; 30 80], 'material',9);
```

Bounds are x/y/z min/max pairs in the undeformed geometry. Component 0 selects
all plates, 1 web, 2 top flange, 3 bottom flange, 4 stiffeners. Later boxes take
precedence over earlier boxes and automatic HAZ. Finite box boundaries and HAZ
boundaries enter the mesh. Thin HAZ bands therefore remain distinct elements.

## Checks and limits

Run `test_aluminum_welded_3pb` in MATLAB for mesh/material/export smoke checks,
including no stiffeners, unequal flanges, custom regions and variable plates.
The generator checks connectivity and degenerate elements before export.
The MATLAB/Abaqus executables were unavailable during implementation, so these
checks and solver execution still require a local run. Perform an Abaqus data
check, inspect the zoning and constraints, and establish mesh convergence before
interpreting resistance results. Displacement control can encounter convergence
limits at snap-back. No residual welding stress, damage/fracture, eigenmode
imperfection, or local imperfection is included. `imperfection` optionally adds
a sinusoidal lateral crookedness; zero gives a geometrically perfect model.

An independent numerical reproduction of the mesh construction checked
connectivity and conforming web/flange-to-stiffener interfaces for the default
six-plate model (5,493 nodes, 5,360 shells), an unstiffened unequal-flange model
with a custom zone, and a two-plate model with different positions/thicknesses.
This checks the meshing algorithm; it does not validate MATLAB execution or
the Abaqus input processor and solver.

Coupling behavior follows the
[Abaqus coupling constraint documentation](https://docs.software.vt.edu/abaqusv2025/English/SIMACAECSTRefMap/simacst-c-coupling.htm).
