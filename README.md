# PEACh
*** Parameter Estimation for Atmospheric Chemistry (PEACh) v.1 ****
v.1. Released Oct. 5, 2020

This package estimates the physicochemical properties of molecular formulas.
This readme provides a short users guide, for information on how to cite this work, please see "How To Cite"

Functions can be called from the PEACh menu, or from the command line.
When using the commmand line, single inputs can be provided directly as strings

Output of PEACh is formula-based estimations of:
 -vapor pressure, units of log (atm)
 -Henry's Law Constants, units of log (M/atm)
 -gas-phase OH rate constants, units of cm3/molec-s
   All properties are calculated at T=298K and P=1 atm


___METHODS___

Descriptions of all estimation methods used are found in Isaacman-VanWertz and Aumont. They include (in output order):
 -vp_LiDaum: Vapor pressure by averaging Daumit and Li methjods, modified to acccount for nitrates (recommended)
 -HLC_linearVP: HLC from linear correlation with vp_LiDaum (recommended)
 -kOH_Constants: kOH as a constant depending on the elements present (recommended)
 -vp_Daumit: Vapor pressure by Daumit et al. (2013)
 -vp_ModLi: Vapor pressure by Li et al. (2016), modified to account for nitrates
 -vp_Donahue: Vapor pressure by Donahue et al. (2011)
 -kOH_Donahue: kOH by Donahue et al. (2013)


___INPUTS___

There are two options for how to provide input:
 Formulas:
    Must be of the form XnYmZr (e.g., C4H10O or C4H10O2), where the number is allowed but not required for a single atom.
    Only C, H, O, and/or N are allowed.
    Order of elements does not matter.
    Must contain at least one C, and any other elements only one time (e.g., C4H9O2H is not allowed).

 SMILES:
    Use with caution! Converting SMILES strings into formulas is in development, some strings may convert incorrectly.
    Only C, H, O, and/or N are allowed.

Input can be provided as a single input as a string, or as a batch using a textwave.

___OUTPUTS___

Results of single inputs are printed to the command line.
Results of batch inputs include:
  2D wave PEACh_output:
    Rows are input lines. Rows are labeled with their input formula
    Columns are estimated properties. Columns are labeled with the output property as named above
  1D text wave PEACh_error including any errors encountered for each input line
  2D text wave PEACh_input:
    Rows are input lines
    Columns are Formula, SMILES, and GECKO.
    	   If input as formulas, SMILES and GECKO are all 'none'
    	   If input as SMILES, GECKO is a derived  GECKO-compatible string, from which Formula is derived
    	     In principle, the GECKO string can be used at the GECKO website, but accuracy is not guaranteed
