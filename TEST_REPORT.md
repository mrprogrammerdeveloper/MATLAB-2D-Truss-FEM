# Test and Change Report

> **MATLAB execution update — 2026-10-09:** After this original independent-code review, the project owner ran `run_verification_tests.m` in MATLAB and supplied console output showing **`SUCCESS: 13 regression groups passed`**, including four exported PNGs. The owner also supplied plots for the 186-node / 485-element benchmark, whose extrema match the reference values below. Statements in the historical report that the revised MATLAB source was "unexecuted" describe only the **earlier review environment**, not the subsequent user-run test. The MATLAB testing environment/version was not independently inspected by the reviewer.

## Provenance and scope

- Reviewed archive: user-provided `matlab.rar` (16 files + input directory).
- Revision: fixes applied to a copy of the archive; original upload unchanged.
- Independent tests: executed with Python 3 / NumPy / SciPy in the review environment.
- MATLAB executable: **not installed in this environment**. The MATLAB regression script and updated figure exporters are **unexecuted in this revision**. Do not interpret the results below as proof that MATLAB itself or MATLAB PNG exports passed.

## Defects addressed

| File | Issue found | Change |
|---|---|---|
| `K_GLOBAL.m` | Thermal equivalent nodal force omitted for negative temperature changes | Apply `E*A*alpha*T` for both positive and negative nonzero `T` |
| `Truss.m` | Ignored `K_fc * U_c` for prescribed displacements | Correct partitioned RHS |
| `Truss.m` | Support reactions ignored external forces applied at supports | Use `K*U - (F_external + F_thermal)` on constrained DOFs |
| `Truss.m` | No actionable error on unstable/singular system | Guard `K_ff` using `rcond`, descriptive exception |
| `Stress.m` | `length(element)` returns 2 for a one-element `1 x 2` connectivity matrix | Preallocate `size(element,1)` stresses; unify signed temperature formulation |
| `processFile.m` | Bare `catch` hid parser errors; invalid elements/materials silently proceeded; missing force section broke vector construction | Parse by section, meaningful errors, check node IDs/connectivity/duplicates/zero-length/nonfinite data; make loads optional |
| `plotAxialStress.m` | Symmetric color limits washed out minority-sign stress for asymmetric stress ranges | Asymmetric limits with white at physical zero |
| `plotAxialStrain.m` | Same issue, plus silently defaulted invalid strain type to mechanical | Signed color map; reject unknown mode |
| `plotDisplacement.m` | Empty `deformationScale=[]` from README not supported | Support auto/empty, validate numeric scaling |
| `plotTrussGeometry.m` | Dense node and force annotations unreadable; X-constrained-only support drawn as a Y roller | Auto-hide node IDs for >40 nodes and force labels for >12 loaded nodes; horizontal restraint marker fixed |
| `postProcess.m` | `outputDir` option ignored, single failed plot prevented later exports, success message misleading | Honor custom output root and isolate figure exceptions |
| `trussFigure.m` (new) | Fixed portrait-ish figure produced excessive whitespace on long bridges | Adaptive figure aspect ratio |
| `trussColorMap.m` (new) | Color mapping repeated across renderers | Centralized consistent signed color map; neutral zero case |
| `README.md` | Obsolete Windows file links, old thermal limitation, inconsistent post-process argument order, unsupported option examples | Replaced with portable and explicit instructions |
| `.gitignore` (new) | Generated results and temp files not excluded | Add repository ignores |

## Independently executed tests

The command `python scripts/reference_validate.py` completed with **all checks passed**:

- Source invariants: MATLAB code includes signed thermal assembly, prescribed-displacement RHS, and constrained reaction load subtraction.
- Four real input models: problem-1 (16/32), problem-2-without-thermal (25/55), problem-2-with-thermal (25/55), `test_1` (186/485), all finite and satisfying equilibrium/residual checks in an **independent SciPy FEM implementation**.
- Analytic axial bar: free expansion with `DeltaT=-20, 0, +20`, zero stress; fully restrained cooling induces positive stress; settlement produces correct middle-node displacement and stresses; applied force at fixed support produces matching negative reaction.
- Large benchmark extrema:
  - max nodal displacement = **0.043893256 m** at **n16**
  - max axial tension = **+37.137045 MPa**
  - max axial compression = **-216.964007 MPa**

These checks validate the *mathematical reference* and guard key source changes, not MATLAB execution equivalence.

## MATLAB tests prepared but NOT RUN

`run_verification_tests.m` includes:

1. Four full-file regression and finite-result checks, constrained displacement checks, axial stress/strain identities, global equilibrium and free-DOF residuals.
2. Positive and negative free thermal expansion.
3. Fully constrained thermal contraction.
4. Nonzero prescribed displacement with a free internal DOF.
5. External nodal force applied directly at a support.
6. Singular stiffness matrix detection.
7. Eleven distinct malformed input scenarios plus absent file, duplicate force accumulation and partial supports.
8. Signed color maps for asymmetric, one-sign and zero fields.
9. Four **actual MATLAB PNG export tests** in a temporary directory.

Execute from MATLAB:

```matlab
run('run_verification_tests.m')
```

Expected final line on a successful run: `===== SUCCESS: 13 regression groups passed =====`.

## Remaining risks / release gate

- MATLAB runtime tests and graphical PNG inspection have not been performed on this updated revision.
- Large models use a dense stiffness matrix; sparse global assembly is a future optimization, not included here to avoid changing the numerical solver beyond critical fixes.
- `rcond(K_ff)<1e-14` identifies singular or very poorly conditioned models. Very slender geometries may require a problem-specific conditioning policy.
- This is linear axial truss FEM only; no buckling, nonlinear response, material yielding or beam bending.
- The repository has no newly chosen license. Choose a license explicitly before claiming an open-source release.
- No Git repository, commit, push, or publication was performed.
