# Numerical model

MATLAB scripts, Excel databases, and validation results for research into the buckling and load capacity of hot-rolled and welded steel I-section members. The workflow generates Abaqus finite-element models, extracts analysis results, and evaluates or calibrates buckling reduction curves against numerical data.

This is a research workspace with multiple script variants and saved study outputs. There is no single application entry point; select a script according to the section type and study being reproduced.

## Workflow

1. Define section geometry, material properties, member length, loads, imperfections, and analysis settings.
2. Generate Abaqus input files, Python extraction scripts, and Windows batch commands using MATLAB.
3. Run elastic buckling or nonlinear collapse analyses in Abaqus.
4. Extract critical loads and resistance results into spreadsheets.
5. Compare results with validation data and calibrate buckling reduction curves.

| Term | Meaning |
| --- | --- |
| LBA | Linear buckling analysis |
| MNA | Materially nonlinear analysis |
| GMNIA | Geometrically and materially nonlinear analysis with imperfections |
| `lambdaG` | Nondimensional global slenderness |
| `chiG` | Global buckling reduction factor |

## Repository guide

| Files or directories | Purpose |
| --- | --- |
| `Hot_rolled_OK*.m` | Abaqus model generators for hot-rolled I-sections, including beam and spring variants. |
| `Welded_I_section*.m` | Abaqus model generators for welded I-sections and related variants. |
| [Aluminum_Welded_I_section_3PB.m](Aluminum_Welded_I_section_3PB.m) | Welded aluminum I-section generator with transverse stiffeners, separate HAZ materials, and three-point bending. See [setup and assumptions](ALUMINUM_3PB.md). |
| [Aluminum_3PB_Input.xlsx](Aluminum_3PB_Input.xlsx) | Excel input workbook for the aluminum model. Edit/save it, then run `run_aluminum_3pb_excel` in MATLAB. |
| [Get_GMNIA_and_LBA_Results_Equation.m](Get_GMNIA_and_LBA_Results_Equation.m) | Processes exported Abaqus results for LBA, MNA, and GMNIA cases into spreadsheets. |
| `mean_square*.m` | Buckling curve fitting and evaluation experiments, including Eurocode 3 style equations. Some versions optimize parameters; others evaluate manually selected values. |
| [Step1_calibrate_chiG_pureN_master.m](Step1_calibrate_chiG_pureN_master.m) | Master global buckling calibration workflow for pure compression. |
| [Step1_calibrate_chiG_pureN_master_2digit_cleaned.m](Step1_calibrate_chiG_pureN_master_2digit_cleaned.m) | Calibration variant that rounds fitted parameters to two decimals during objective evaluation and saves retained-curve plots. |
| `graphic_code*.m` | Plotting scripts. |
| `stresgen.m`, `yieldMP.m` | Section stress and yield load/moment helpers. |
| `1. Name.dat` through `7. Webdata.dat` | Naming, model parameters, section designations, and flange/web data; usage depends on the generator. |
| `Input*.xlsm`, `parameters_section_*.xlsx`, `Material_law*.xlsm` | Study inputs, section properties, and material-law data. |
| `Result*.xlsm`, `Results.xlsm`, `Database*.xlsm` | Saved numerical results and databases. |
| `Validation*`, `validation 6 HR`, `test_calibration` | Validation spreadsheets and comparison/calibration figures. |
| `Step1_ChiG_*` | Saved calibration tables, MATLAB results, and plots. |

Numbered filenames and suffixes such as `old` and `mod` identify existing variants; they do not establish which implementation to use for every study. MATLAB `.asv` files are editor autosaves.

## Requirements

- **MATLAB** with the spreadsheet functions used by the selected script, including `readmatrix` and `readcell`. No minimum release is specified.
- **Abaqus** for finite-element analyses and execution of generated Abaqus Python scripts.
- **CUFSM routines** for model generation. Generators add a local `CUFSM software` directory and its subdirectories to the MATLAB path; that directory is not included in this repository.
- **Windows** for existing batch commands and path conventions. Other platforms require changes.
- **Optimization Toolbox** for scripts using `lsqcurvefit`, such as `Curve_Fitting_Alu_Simple_Loading_E.m`. The two-digit master calibration script uses MATLAB's `fminsearch`.

Excel workbooks are central inputs. Microsoft Excel is useful for inspecting and editing them; spreadsheet-reading requirements depend on the MATLAB function and environment. No automated workbook macro execution is documented here.

## Run the pure-compression calibration

This workflow uses an existing finite-element database and can run independently of generating new Abaqus models.

1. Set MATLAB's current folder to the repository root.
2. Review the `CONTROL_PANEL` sheet in `Parametric study_Prachi_Online_Redo.xlsm`.
3. Verify the raw data in `OIC-N-Prachi`, starting at row 4. The script reads A:T, including case number in A, alloy in D, `lambdaG` in F, `chiG` in H, and model type (`SHELL` or `BEAM`) in T.
4. Run:

   ```matlab
   Step1_calibrate_chiG_pureN_master_2digit_cleaned
   ```

The control panel uses column C:

| Cells | Setting |
| --- | --- |
| C2 | Model family |
| C3 | Alloy grouping |
| C4 | Shell/beam row selection |
| C5 | Fit goal |
| C6 | AP fit mode |
| C7 | `deltaG` |
| C8 | Trial `lambda0` values |
| C9:C10 | Practical slenderness range |
| C11 | Weight for the practical range |
| C12:C13 | Modified AP beta bounds |
| C14 | Beta starting values |

See the script's `readControlPanel` function and option-handling code for defaults and accepted settings.

Outputs are written to the current folder with a `Step1_ChiG_` prefix:

- Candidate and retained parameter tables (`.csv`).
- Group comparison and retained-only plots (`.png`).
- A master result structure containing settings, filtered data, and scenario results (`.mat`).

This script does not write back to Excel. Repeating a run with the same settings can replace output files with the same names.

## Generate and process Abaqus models

Review configuration directly in the selected generator: existing scripts contain study-specific case selections and overrides.

1. Choose a generator, for example `Hot_rolled_OK_beam.m` or `Welded_I_section_Equation_General_OK3_beam.m`.
2. Provide CUFSM routines at the configured location or update the MATLAB path setup.
3. Review `1. Name.dat`, `3. Parameters.dat`, section designations, and other inputs read by the chosen variant. Parameter-column meanings appear beside their assignments in the script.
4. Check the active case-selection loop (`for o=...`), loads, material properties, imperfections, element types, and boundary conditions. Some input values are subsequently overridden in code.
5. Configure output locations and the Abaqus command path. The example beam generators create study folders under `H_R_Validations_results` or `Validations_results` in the parent of the current directory. Generated commands contain an installation-specific Abaqus path and CPU count.
6. Run the generator in MATLAB, inspect its generated files, and execute the batch commands in an environment with Abaqus available.
7. Set `DataFolder` in `Get_GMNIA_and_LBA_Results_Equation.m` to the relevant results directory. Verify that the expected `Filename.dat` and exported `.txt` files exist before extracting results.

Generators can recreate batch files and case lists in their output directories. Use a distinct study folder when preserving previous runs.

## Validation and reproducibility

Validation material includes steel grades such as S235, Q690, and Q1100, alongside mesh-density studies and saved calibration figures. Reproducing a result requires matching the script variant, inputs, selected cases, and analysis settings used for that study.

There is no automated test suite or documented reference run. Inspect generated models and compare numerical outputs with the relevant validation spreadsheets and figures. Check units in the selected script: generators include conversions from kN to N, and extraction scripts convert loads or moments for reporting.

Some auxiliary scripts reference external inputs that are not included. For example, `Curve_Fitting_Alu_Simple_Loading_E.m` requires `Aluminium Database_2024-12-01 - 66 sections.xlsm`.
