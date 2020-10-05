#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// *** Parameter Estimation for Atmospheric Chemistry (PEACh) v.1 ****
// 
// Written by G. Isaacman-VanWertz
//
// Please see "ReadMe" and "How To Cite" before use
//

Menu "PEACh"
	Submenu "Estimate single"
		"Single formula", PEACH_callForm("")		
		"Single SMILES", PEACH_callSMILES("")	
	End
	
	Submenu "Estimate batch"
		"Batch formulas", PEACH_callFormBatch()		
		"Batch SMILES", PEACH_callSMILESBatch()	
	End
	
	Submenu "About"
		"Readme", PEACh_ReadMe()
		"How To Cite", PEACh_HowToCite()
	End

End

Structure PEAChparams	//STRUCT containing all results and inputs
	string gecko
	string SMILES
	string formula
	string error
	double GECKOtime
	double MW
	double retMW
	
	// structure-based values, include some day
	double vp_MY
	double vp_Nann
	double vp_SIMP
	double vp_EVAP
	double vp_avg
	double HLC_GROMHE
	double kOH_Jenkin
	
	// formula-based values
	double vp_Daum
	double vp_Li
	double vp_Dona
	double vp_LiDaum
	double HLC_linearVP
	double kOH_Dona
	double kOH_Const
EndStructure

Function PEACH_callSMILES(SMILESin)
	string SMILESin
	STRUCT PEACHparams g
	g.error = ""
		
	if(strlen(SMILESin)==0)
		Prompt SMILESin, "Enter SMILES string:"
		DoPrompt "SMILES input", SMILESin
		if(V_flag==1)
			abort "User cancelled"
		endif
	endif
	
	if(stringmatch(SMILESin,"*S*"))
		abort "Sulfur is not allowed"
	endif
	if(!stringmatch(SMILESin,"*C*"))
		abort "Must contain carbon"
	endif
		
	g.SMILES = SMILESin
	PEACh_getGECKOstring(g)	// does all the stuff necessary to convert SMILES to GECKO string. This is necessary to get the formula
	PEACH_do(g)
	PEACh_PrintOutput(g)
End

Function PEACH_callForm(FormIn)
	string FormIn
	STRUCT PEACHparams g
	g.error = ""
	g.SMILES = "none"
	g.GECKO = "none"

	if(strlen(FormIn)==0)
		Prompt FormIn, "Enter formula string:"
		DoPrompt "Formula input", FormIn
		if(V_flag==1)
			abort "User cancelled"
		endif
	
	endif
	
	
	if(stringmatch(FormIn,"*S*"))
		abort "Sulfur is not allowed"
	endif
		
	if(!stringmatch(FormIn,"*C*"))
		abort "Must contain carbon"
	endif
	
	if(strlen(ReplaceString("C",FormIn,"",0)) < strlen(FormIn)-1)
		print "This doesn't look like a formula"
		return 0
	endif 
	g.formula = FormIn
	PEACH_do(g)
	PEACh_PrintOutput(g)
End



Function PEACH_callFormBatch()
	STRUCT PEACHparams g

 	string InWaveName
	Prompt InWaveName, "Wave that contains formulas:", popup wavelist("*",";","TEXT:1")
	DoPrompt "Select a formula wave", InWaveName
	
	if(V_flag==1)
		abort "User cancelled"
	endif
	
	wave/T inWave = $inwaveName 
	
	if(dimsize(inwave,1)>0)
		abort "Cannot use 2D wave"
	endif
	if(!waveexists(inWave))
		abort "Cannot find wave, try again"
	endif
	
	ControlInfo PEACh_batch_verbose
	variable verbose = V_value	
	
	variable idex,jdex
	wave PEACh_output
	wave/T PEACh_input, PEACh_error
	
	variable continueBatch = 1
	variable numToDo = dimsize(inWave,0)
	variable numDone = 0 
	print "Comparing to previous data..."
	
	if(dimsize($("PEACh_input"),0)>0)	// determine if we can and should continue previous batch
		if(dimsize(PEACh_input,0) == dimsize(inWave,0))
			Make/O/FREE/N=(dimsize(inWave,0)) compWave
			compWave = stringMatch(inwave[p],PEACh_input[p][%Formula])
			
			if(sum(compwave) != dimsize(compWave,0))
				continueBatch = 0
			else
				DoAlert/T="Continue?" 2, "It looks like you might be continuing the last batch.\rDo you want to pick up where we left off?\rIf you select No, it will be overwritten."
				if(V_flag==2)
					continueBatch = 0
				elseif(V_flag == 3)
					string alertStr ="User cancelled\r\r"
					abort alertStr					
				else 
					compWave = (compWave[p] && numtype(Peach_output[p][0])!=0)
					numToDo = sum(compWave)
				endif
			endif
		else
			continueBatch = 0
		endif
	else
		continueBatch = 0
	endif
	
	
	if(!continueBatch)
		if(dimsize($("PEACh_input"),0)>0) 
			DoAlert/T="Overwrite?" 1, "Previous batch will not be continued.\rThis action cannot be undone.\rAre you sure you want to overwrite it?"
			if(V_flag>1)
				alertStr ="User cancelled\r\r"
				alertStr += "To continue a batch input wave must be identical to previous." 
				abort alertStr
			endif 
		endif
		Make/O/N=(dimsize(InWave,0),8) PEACh_output = NaN
		Make/T/O/N=(dimsize(InWave,0),3) PEACh_input = ""
		Make/T/O/N=(dimsize(InWave,0),1) PEACh_error= ""

		SetDimLabel 1,0, MW, PEACh_output
		SetDimLabel 1,1, vp_LiDaum, PEACh_output
		SetDimLabel 1,2, HLC_linearVP, PEACh_output
		SetDimLabel 1,3, kOH_Constants, PEACh_output
		SetDimLabel 1,4, vp_Daumit, PEACh_output
		SetDimLabel 1,5, vp_ModLi, PEACh_output
		SetDimLabel 1,6, vp_Donahue, PEACh_output
		SetDimLabel 1,7, kOH_Donahue, PEACh_output
		
		SetDimLabel 1,0, SMILES, PEACh_input
		SetDimLabel 1,1, GECKO, PEACh_input
		SetDimLabel 1,2, Formula, PEACh_input
	
		SetDimLabel 1,0, error, PEACh_error
		
		PEACh_input[][%Formula] = Inwave[p]
		
	endif

	print "Starting estimations...."
	KillWindow/Z PEAChprog_panel
	Execute "PEAChprog_panel()"
	string textStr = "\\JRProcessing wave \\f01" + NameOfWave(inWave) + "\r\\f00as\f01 formula"
	TitleBox PEACh_inWaveName win=PEAChprog_panel, title=textStr
	variable startTime = DateTime
	variable avgTimePer
	string avgStr
	
	for(idex = 0; idex < dimsize(inwave,0); idex += 1)
	
		if(continueBatch)
			if(PEACh_output[idex][0] > 0)
				continue
			endif
		endif
		
		g.SMILES = "none"
		g.GECKO = "none"
		g.formula = inwave[idex]
		
		if(strlen(ReplaceString("C",g.formula,"",0)) < strlen(g.formula)-1)
			PEACh_error[idex][%error] = "noForm"
			continue
		endif 

		PEACH_do(g)
		PEACh_input[idex][%SMILES] = g.SMILES
		PEACh_input[idex][%GECKO] = g.GECKO
		
		PEACh_error[idex][%error] = g.error

		SetDimLabel 0,idex, $(g.Formula), PEACh_output
		PEACh_output[idex][%MW] = g.MW
		PEACh_output[idex][%vp_LiDaum] = g.vp_LiDaum
		PEACh_output[idex][%HLC_linearVP] = g.HLC_linearVP
		PEACh_output[idex][%kOH_Constants] = g.kOH_Const 
		PEACh_output[idex][%vp_Daumit] = g.vp_Daum
		PEACh_output[idex][%vp_ModLi] = g.vp_Li
		PEACh_output[idex][%kOH_Donahue] = g.vp_Dona

		numToDo-=1
		numDone += 1
		avgTimePer = (datetime-starttime)/(numDone)
		ValDisplay PEACh_timePer win=PEAChprog_panel, value=_NUM:(avgTimePer)	
		sprintf avgStr,"%2.e",avgTimePer
		avgTimePer = str2num(avgStr)
		ValDisplay PEACh_numToDo win=PEAChprog_panel, value=_NUM:numToDo
		ValDisplay PEACh_TimeRem win=PEAChprog_panel, value=_NUM:(numToDo*avgTimePer/60)


		DoUpdate/W=PEAChprog_panel/E=1
		if(V_flag==2)
			break
		endif
	endfor	
	
	KillWindow PEAChprog_panel
	DoWindow/K/Z PeachOutput
	Edit/N=PeachOutput PEACH_output.ld, peach_error, peach_input as "PEACh output"
	Print "Completed", numDone, "estimations"
	
	alertStr = "Batch complete.\r\r"
	alertStr += "Recommended values are vp_LiDaum, HLC_linearVP, and kOH_Constants\r"
	alertStr += "vp units: log (atm)\rHLC units: log (M/atm)\rkOH units: log (cm3/molec-s)" 
	DoAlert/T="Complete!" 0, alertStr
	
End




Function PEACH_callSMILESBatch()
	STRUCT PEACHparams g

 	string InWaveName
	Prompt InWaveName, "Wave that contains SMILES:", popup wavelist("*",";","TEXT:1")
	DoPrompt "Select a SMILES wave", InWaveName
	
	if(V_flag==1)
		abort "User cancelled"
	endif
	
	wave/T inWave = $inwaveName 
	
	if(dimsize(inwave,1)>0)
		abort "Cannot use 2D wave"
	endif
	if(!waveexists(inWave))
		abort "Cannot find wave, try again"
	endif
	
	ControlInfo PEACh_batch_verbose
	variable verbose = V_value	
	
	variable idex,jdex
	wave PEACh_output
	wave/T PEACh_input, PEACh_error
	
	variable continueBatch = 1
	variable numToDo = dimsize(inWave,0)
	variable numDone = 0 
	print "Comparing to previous data..."
	
	if(dimsize($("PEACh_input"),0)>0)	// determine if we can and should continue previous batch
		if(dimsize(PEACh_input,0) == dimsize(inWave,0))
			Make/O/FREE/N=(dimsize(inWave,0)) compWave
			compWave = stringMatch(inwave[p],PEACh_input[p][%SMILES])
			
			if(sum(compwave) != dimsize(compWave,0))
				continueBatch = 0
			else
				DoAlert/T="Continue?" 2, "It looks like you might be continuing the last batch.\rDo you want to pick up where we left off?\rIf you select No, it will be overwritten."
				if(V_flag==2)
					continueBatch = 0
				elseif(V_flag == 3)
					string alertStr ="User cancelled\r\r"
					abort alertStr					
				else 
					compWave = (compWave[p] && numtype(Peach_output[p][0])!=0)
					numToDo = sum(compWave)
				endif
			endif
		else
			continueBatch = 0
		endif
	else
		continueBatch = 0
	endif
	
	
	
	if(!continueBatch)
		if(dimsize($("PEACh_input"),0)>0) 
			DoAlert/T="Overwrite?" 1, "Previous batch will not be continued.\rThis action cannot be undone.\rAre you sure you want to overwrite it?"
			if(V_flag>1)
				alertStr ="User cancelled\r\r"
				alertStr += "To continue a batch input wave must be identical to previous." 
				abort alertStr
			endif 
		endif
		Variable numToInit = dimsize(inWave,0)
		
		print "Initializing..."
		Make/O/N=(dimsize(InWave,0),8) PEACh_output = NaN
		Make/T/O/N=(dimsize(InWave,0),3) PEACh_input = ""
		Make/T/O/N=(dimsize(InWave,0),1) PEACh_error= ""

		SetDimLabel 1,0, MW, PEACh_output
		SetDimLabel 1,1, vp_LiDaum, PEACh_output
		SetDimLabel 1,2, HLC_linearVP, PEACh_output
		SetDimLabel 1,3, kOH_Constants, PEACh_output
		SetDimLabel 1,4, vp_Daumit, PEACh_output
		SetDimLabel 1,5, vp_ModLi, PEACh_output
		SetDimLabel 1,6, vp_Donahue, PEACh_output
		SetDimLabel 1,7, kOH_Donahue, PEACh_output
		
		SetDimLabel 1,0, SMILES, PEACh_input
		SetDimLabel 1,1, GECKO, PEACh_input
		SetDimLabel 1,2, Formula, PEACh_input
	
		SetDimLabel 1,0, error, PEACh_error
		
		PEACh_input[][%SMILES] = inWave
		
//		variable size = dimsize(inwave,0)
//		for(idex = 0; idex < size; idex += 1)
//			string thisStr = inwave[idex]
//			SetDimLabel 0,idex, $(thisStr), PEACh_input, PEACh_error
//			numToInit -= 1
//			avgTimePer = (datetime-starttime)/(size-numToInit)
//			ValDisplay PEACh_numToInit win=PEAChprog_panel, value=_NUM:numToInit
//			ValDisplay PEACh_timeRemInit win=PEAChprog_panel, value=_NUM:(numToInit*avgTimePer)
//			ValDisplay PEACh_timeRemInit1 win=PEAChprog_panel, value=_NUM:(avgTimePer)
//		endfor
	endif

	print "Starting estimations...."
	Execute "PEAChprog_panel()"
	string textStr = "\\JRProcessing wave \\f01" + NameOfWave(inWave) + "\r\\f00as\f01 SMILES"
	TitleBox PEACh_inWaveName win=PEAChprog_panel, title=textStr
	
	variable startTime = DateTime
	variable avgTimePer
	string avgStr
	for(idex = 0; idex < dimsize(inwave,0); idex += 1)
		
		if(continueBatch)
			if(PEACh_output[idex][0] > 0)
				continue
			endif
		endif

		g.SMILES = inwave[idex]
		g.error=""
		PEACh_getGECKOstring(g)
		
		if(strlen(ReplaceString("C",g.formula,"",0)) < strlen(g.formula)-1)
			PEACh_error[idex][%error] = "noForm"
			continue
		endif 
	
		PEACH_do(g)

		PEACh_input[idex][%GECKO] = g.GECKO
		PEACh_input[idex][%Formula] = g.Formula
		PEACh_error[idex][%error] = g.error

		SetDimLabel 0,idex, $(g.Formula), PEACh_output
		PEACh_output[idex][%MW] = g.MW
		PEACh_output[idex][%vp_LiDaum] = g.vp_LiDaum
		PEACh_output[idex][%HLC_linearVP] = g.HLC_linearVP
		PEACh_output[idex][%kOH_Constants] = g.kOH_Const 
		PEACh_output[idex][%vp_Daumit] = g.vp_Daum
		PEACh_output[idex][%vp_ModLi] = g.vp_Li
		PEACh_output[idex][%kOH_Donahue] = g.kOH_Dona
		PEACh_output[idex][%vp_Donahue] = g.vp_Dona

		numToDo-=1
		numDone += 1
		avgTimePer = (datetime-starttime)/(numDone)
		ValDisplay PEACh_timePer win=PEAChprog_panel, value=_NUM:(avgTimePer)	
		
		sprintf avgStr,"%2.e",avgTimePer
		avgTimePer = str2num(avgStr)
		ValDisplay PEACh_numToDo win=PEAChprog_panel, value=_NUM:numToDo
		ValDisplay PEACh_TimeRem win=PEAChprog_panel, value=_NUM:(numToDo*avgTimePer/60)
		
		DoUpdate/W=PEAChprog_panel/E=1
		if(V_flag==2)
			break
		endif
	endfor	
	
	DoWindow/K/Z PeachOutput
	KillWindow PEAChprog_panel
	Edit/N=PeachOutput PEACH_output.ld, peach_error , peach_input as "PEACh output"

	Print "Completed", numDone, "estimations"
	alertStr = "Batch complete.\r"
	alertStr += "SMILES --> formula in development, PLEASE CHECK FORMULAS!\r\r"
	alertStr += "Recommended values are vp_LiDaum, HLC_linearVP, and kOH_Constants\r"
	alertStr += "vp units: log (atm)\rHLC units: log (M/atm)\rkOH units: log (cm3/molec-s)" 
	DoAlert/T="Complete!" 0, alertStr
End

Function PEACH_do(g)
	STRUCT PEACHparams &g
	g.error=""
	
	make/O/N=(4)/FREE FormWave = 0
	String ElemList = "C;H;O;N"

	string ElemStr, NumStr
	string inStr = g.formula
	variable num,idex
	
	// parse formula into elements
	do
		SplitString/E="([[:alpha:]])([[:digit:]]+)?" inStr, ElemStr, NumStr
		inStr = (inStr[strlen(S_value),strlen(InStr)])
		if(strlen(numStr) == 0)
			num = 1
		else
			num = str2num(numStr)
		endif
		idex = WhichListItem(ElemStr,ElemList)
		if(idex >= 0)
			FormWave[WhichListItem(ElemStr,ElemList)] = num
		else
			return -1
		endif
	while(strlen(inStr)>0)
	
	make/O/N=(4)/FREE MWwave = {12.01, 1.01,16.00,14.01}
	Formwave*=MWwave
	g.MW = round(sum(Formwave)*100)/100
	Formwave/=MWwave
	
	if(!g.MW>0)
		g.error += "noC;"
		g.kOH_Dona = NaN
		g.vp_Dona = NaN
		g.vp_Li = NaN
		g.vp_Daum = NaN
		g.vp_LiDaum = NaN
		g.vp_avg=nan
		g.HLC_linearVP = NaN
		g.kOH_const = NaN
		return 0
	endif
	
	//calculate all methods
	
	//kOH methods
	if(FormWave[3]>0) // if there is nitrogen, Donahue methods are no-go
		g.error += "hasN;"
		g.kOH_Dona = NaN
		g.vp_Dona = NaN
		g.kOH_const = 1.4e-11
	else	
		g.kOH_Dona = PEACh_Form2kOH_Dona(formWave)
		g.vp_Dona = log(PEACh_Cstar2atm(10^PEACh_Form2VP_Dona(formWave)))
		g.kOH_const = 2.8e-11
	endif
	
	// vp methods
	g.vp_Daum = log(PEACh_Cstar2atm(10^PEACh_Form2VP_Daum(formWave)))
	g.vp_Li = log(PEACh_Cstar2atm(10^PEACh_Form2VP_Li(formWave)))
	Make/O/N=(2)/FREE vpVals = {g.vp_Daum, g.vp_Li}
	Wavestats/Q vpVals
	g.vp_LiDaum = V_avg	
	
	// HLC methods
	g.HLC_linearVP = -1.15*V_avg-0.78
	
	
End




Function PEACh_PrintOutput(g)	//updates all panel fields
	STRUCT PEACHparams &g
	
	if(!stringmatch(g.SMILES,"none"))
		print "Entered string:", g.SMILES
		print "Parsed to GECKO string:", g.GECKO
		print "PLEASE CHECK FORMULA"
	endif
	
	print "Recommended estimates for", g.formula, "are:"

	print "  vp, Daumit-Li method:", g.vp_LiDaum, "log (atm)"
	print "  HLC, Linear-vp method:", g.HLC_linearvp, "log (M/atm)"
	print "  kOH, constants method:", g.kOH_Const, "cm3/molec-s"
	
	print "\r","  Other estimates are:"
	print "    vp, Daumit method:", g.vp_Daum, "log (atm)"
	print "    vp, Modified Li method:", g.vp_Li, "log (atm)"
	print "    vp, Donahue method:", g.vp_Dona, "log (atm)"
	print "    kOH, Donahue method:", g.kOH_Dona	, "cm3/molec-s"
End




Function/S PEACh_SMILES2GECKO(SMILESstring)	//converts SMILES string to GECKO input, which has explicit hydrogens and some other differences
	string SMILESstring
	string GECKOstring=""
	
		variable idex,jdex, ParenNest=0,BondNum=0
	
	string thisChar,thisChar2,thisChar3
	
	string Elem = "C;c;O;N;S;"
	
	
	SMILESstring = replacestring("=C(O)",replacestring("C(O)=",SMILESstring,"C(=O)"),"C(=O)")
	SMILESstring = replacestring("[O-][N+](=O)O",SMILESstring,"ON(=O)(=O)")
	SMILESstring = replacestring("O[N+](=O)[O-]",SMILESstring,"ON(=O)(=O)")
	SMILESstring = replacestring("O=N(=O)O",SMILESstring,"ON(=O)(=O)")
	SMILESstring = replacestring("O[N+](=O)[O-]",SMILESstring,"ON(=O)(=O)")
	SMILESstring = replacestring("N(=O)=O",SMILESstring,"N(=O)(=O)")
	SMILESstring = replacestring("ON(=O)(=O)",SMILESstring,"(ON(=O)(=O))")
	//if(stringmatch(SMILESstring,"(ON(=O)(=O))O*"))
	//	variable startHere = strSearch(SMILESstring,"C",0)
	//	string modSMILES = SMILESstring[startHere,startHere+1]+ "(OON(=O)(=O))" + SMILESstring[startHere+1, strlen(SMILESstring)]
	//	SMILESstring = modSMILES
	//endif
	if(stringmatch(SMILESstring,"(ON(=O)(=O))*"))
		variable startHere = strSearch(SMILESstring,"C",0)
		string modSMILES = SMILESstring[startHere,startHere+1]+ "(ON(=O)(=O))" + SMILESstring[startHere+1, strlen(SMILESstring)]
		SMILESstring = modSMILES
		
	endif
	
	Make/O/N=(strlen(SMILESstring),6)/T Bonds=""


	for(idex= 0; idex<strlen(SMILESstring); idex += 1)
		thisChar = SMILESstring[idex,idex]
		Bonds[idex][0] = thisChar
	
		//Characterize all bonds
		if(WhichListItem(thisChar, Elem) >=0)
			ParenNest = 0
			BondNum=0

			thisChar = SMILESstring[idex-1,idex-1]
			if(StringMatch(thisChar,"="))
				BondNum += 1
				Bonds[idex][BondNum] = "=Ca"
				BondNum += 1
				Bonds[idex][BondNum] = "=Cb"
			elseif(idex > 0)
				BondNum += 1
				Bonds[idex][BondNum] = "prev"
			endif

			jdex = 1
			
			do
				thisChar = SMILESstring[idex+jdex,idex+jdex]
				if(str2num(thisChar) >= 0)
					Bonds[idex][0]+=thisChar
					BondNum += 1
					Bonds[idex][BondNum] = thisChar
					jdex+=1
				else
					break
				endif
			while(1)

			if(StringMatch(thisChar,"="))
				thisChar = SMILESstring[idex+jdex+1]
				BondNum += 1
				Bonds[idex][BondNum] = "="+thisChar+"a"
				BondNum += 1
				Bonds[idex][BondNum] = "="+thisChar+"b"
				continue
			endif
			


			for(jdex = idex + 1; jdex < strlen(SMILESstring) ;jdex += 1)
				thisChar = SMILESstring[jdex,jdex]
				thisChar2 = SMILESstring[jdex+1,jdex+1]
				thisChar3 = SMILESstring[jdex+2,jdex+2]
				if(StringMatch(thisChar,"("))
					if(ParenNest < 1)
						BondNum += 1
						Bonds[idex][BondNum] = thisChar2
						
						if(StringMatch(thisChar2,"="))
							Bonds[idex][BondNum] += thisChar3+"a"
							BondNum += 1
							Bonds[idex][BondNum] = thisChar2+thisChar3+"b"
						endif
					endif
					ParenNest+=1				
				endif
				if(StringMatch(thisChar,")"))
					ParenNest-=1
					if(ParenNest < 0)
						break
					endif	
					
					if(StringMatch(thisChar2,"="))
						BondNum += 1
						Bonds[idex][BondNum] = thisChar2+thisChar3+"a"
						BondNum += 1
						Bonds[idex][BondNum] = thisChar2+thisChar3+"b"
						break
					endif
							
				endif
				if(ParenNest < 0)
					break
				endif
				if(WhichListItem(thisChar, Elem) >=0 && ParenNest == 0)
					BondNum += 1
					Bonds[idex][BondNum] = thisChar
					break
				endif

			endfor
		endif
	endfor
	
	Make/O/N=(dimsize(Bonds,0),dimsize(Bonds,1)) Valence
	Valence = strlen(Bonds)>0
	ImageTransform SumAllRows Valence
	wave W_sumrows
	W_sumrows -= 1
	
	string thisElem
	
	//Use bonding to add explicit hydrogens
	for(idex= 0; idex<dimsize(Bonds,0); idex += 1)
		thisElem = Bonds[idex][0]
		thisElem = thisElem[0,0]
		
		
		
		if(WhichListItem(thisElem, Elem) ==0)	//C
			if(stringmatch(Bonds[idex][2],"=C*") || stringmatch(Bonds[idex][3],"=C*"))
				Bonds[idex][0] += "d"
			endif
			if(W_sumrows[idex] < 4)
				Bonds[idex][0] += "H"
			endif
			if(W_sumrows[idex] < 3)
				Bonds[idex][0] += num2istr(4-W_sumrows[idex])
			endif

		endif

		if(WhichListItem(thisElem, Elem) ==1)	//c
			if(W_sumrows[idex] < 3)
				Bonds[idex][0] += "H"
			endif
		endif

		if(WhichListItem(thisElem, Elem) ==2)//O
			if(W_sumrows[idex] < 2)
				Bonds[idex][0] += "H"
			elseif(stringmatch(Bonds[idex][2],"C") || stringmatch(Bonds[idex][2],"O") || str2num(Bonds[idex][2])>0)
				Bonds[idex][0] = "-" + Bonds[idex][0] + "-"	// if second bond is a C or an O, must be in-line
			endif
		endif
		
		if(WhichListItem(thisElem, Elem) ==3)	//N
			if(W_sumrows[idex] < 3)
				Bonds[idex][0] += "H"
			endif
			if(W_sumrows[idex] < 2)
				Bonds[idex][0] += num2istr(3-W_sumrows[idex])
			endif
		endif
		
		if(str2num(thisElem) >= 0)
			continue
		endif 
	endfor
	
	string prevElem
		
	for(idex= 1; idex<dimsize(Bonds,0); idex += 1)
		thisElem = Bonds[idex][0]
		if(stringmatch(thisElem,"OH"))
			ParenNest = 0
			jdex = idex
			prevElem = Bonds[idex-1][0]
			
			if(stringmatch(prevElem,"-O-"))
				thisElem = "(OOH)"
				Bonds[idex-1][0] = ""
				jdex -= 1
				prevElem = Bonds[jdex-1][0]
			else
				thisElem = "(OH)"
			endif
			Bonds[idex][0] = thisElem
						
			if(stringmatch(prevElem,"("))
				Bonds[jdex-1][0] = ""
				Bonds[idex+1][0] = ""
				jdex -= 1
				
			endif
			Bonds[idex][0] = ""
			do
				prevElem = Bonds[jdex-1][0]
				if(stringmatch(prevElem,")"))
					ParenNest += 1
				elseif(stringmatch(prevElem,"("))
					ParenNest -= 1
				else
					if(ParenNest == 0)
						Bonds[jdex-1][0] += thisElem
						break
					endif
				endif
				jdex -= 1

			while(1)
		endif
	endfor
	
		
	for(idex= 0; idex<dimsize(Bonds,0); idex += 1)
		
		thisElem = Bonds[idex][0]
		thisElem = thisElem[0,0]
		
		
		
		if(str2num(thisElem) >= 0)

			continue
		endif
		GECKOstring += Bonds[idex][0]
	endfor


	if(stringmatch(SMILESstring,"O*"))//&& str2num(tempStr[1]) >= 0)
		string modGECKO
		variable ParenNum= 0, endHere=0,SMILESstartHere=0
		idex = 0
		startHere = 0
		do
			idex += 1
			if(stringmatch(GECKOstring[idex],"C") || stringmatch(GECKOstring[idex],"c"))
				if(ParenNum==0)
					if(startHere>0)
						endHere = idex
					else
						startHere = idex
					endif
				endif
			elseif(stringmatch(GECKOstring[idex],"("))
				ParenNum += 1
			elseif	(stringmatch(GECKOstring[idex],")"))
				ParenNum -= 1
			endif
		while(endHere == 0 || startHere == 0)
		string xfrGrp = ""//g.gecko[0,startHere-1]
		ParenNum=0
		
		idex=0
		do
			idex += 1		
			if(stringmatch(SMILESstring[idex],"C") || stringmatch(SMILESstring[idex],"c"))
				if(ParenNum==0)
					SMILESstartHere = idex
				endif
			elseif(stringmatch(SMILESstring[idex],"("))
				ParenNum += 1
			elseif	(stringmatch(SMILESstring[idex],")"))
				ParenNum -= 1
			endif
		while(SMILESstartHere == 0)
		
		wave/T Bonds	
		for(idex = SMILESstartHere-1 ; idex>=0; idex -= 1)
			if(stringmatch(Bonds[idex][0],"*O*"))
				xfrGrp+=Bonds[idex][0]
			endif
		endfor
		
		modGECKO = GECKOstring[starthere,endHere-1]+ "(" + xfrGrp + ")" + GECKOstring[endHere, strlen(GECKOstring)]
		
		GECKOstring = modGECKO

	endif

	//deal with functional groups that need different notation
	GECKOstring = ReplaceString("C(=O)OH", GECKOstring, "CO(OH)")
	GECKOstring = ReplaceString("C(OH)(=O)", GECKOstring, "CO(OH)")
	GECKOstring = ReplaceString("CH=O", GECKOstring, "CHO")
	GECKOstring = ReplaceString("ON(=O)(=O)", GECKOstring, "ONO2")
	GECKOstring = ReplaceString("N(=O)(=O)", GECKOstring, "NO2")
	GECKOstring = ReplaceString("(=O)", GECKOstring, "O") 
	GECKOstring = ReplaceString("CdH(O)", GECKOstring, "CHO") 
	GECKOstring = ReplaceString("--", GECKOstring, "-")
	GECKOstring = ReplaceString("-O-(OH)", GECKOstring, "OOH")
	GECKOstring = ReplaceString("-O-OH", GECKOstring, "OOH")
	GECKOstring = ReplaceString("-O-ONO2", GECKOstring, "OONO2")
	GECKOstring = ReplaceString("-O-(ONO2)", GECKOstring, "OONO2")
	GECKOstring = ReplaceString("COOONO2)", GECKOstring, "CO(OONO2)")

	
	
	
	//KillWaves/Z Bonds
	return GECKOstring
End

Function/S PEACh_GECKO2Formula(GECKOstring)	// use GECKO string to get the formula (used because it has explicit hydrogens)
	string GECKOstring
	
	string Elem = "C;H;O;N;c;"
	string nextChar,prevChar
	make/O/N=(5)/FREE FormWave = 0
	variable idex
	variable numRings =0
	
	variable thisElem
	
	for(idex = 0; idex < strlen(GECKOstring) ; idex += 1)
		thisElem = whichlistitem(GECKOstring[idex],Elem) 
		if(thisElem<0)
			continue
		endif
		if(idex < (strlen(GECKOstring) -1))
			nextChar = GECKOstring[idex+1]
		else
			nextChar = ""
		endif
		if(idex > 0)
			prevChar = GECKOstring[idex-1]
		else
			prevChar = ""
		endif
		if(thisElem >= 0)
			FormWave[thisElem] += 1
		endif
		if(str2num(nextChar)>0)
			if(thisElem > 0)
				if(stringmatch(prevChar,"-") && thisElem == 2)
					numRings += 0.5
				else
					FormWave[thisElem] += str2num(nextChar)-1
				endif
			else
				numRings += 0.5
			endif
		endif
	endfor
	
	string formStr = ""
	
	FormWave[0]+=FormWave[4]
	for(idex = 0 ;idex < dimsize(FormWave,0)-1 ; idex += 1)
		if(FormWave[idex]>0)
			formStr += stringfromlist(idex,Elem)
		endif
		if(FormWave[idex]>1)
			formStr += num2istr(Formwave[idex])
		endif
	endfor
	
	return formStr
End

Function PEACh_getGECKOstring(g)	//  First deals with known sources of error (e.g., enols), then converts to GECKO string
	STRUCT PEAChParams &g	
	
	variable verbose
	string tempStr
	tempStr = g.smiles
	
	if(stringmatch(tempStr,"*=C(O)*") || stringmatch(tempStr,"*C(O)=*") || strlen(tempStr)<1)
		g.error += "enol;"
	endif
	
	if(stringmatch(tempStr,"O*"))
		g.error += "Ostart;"
	endif

	g.gecko = PEACh_SMILES2GECKO(tempStr)	// convert the SMILES to GECKO string
	g.formula = PEACh_GECKO2Formula(g.gecko) // get formula from GECKO string

End





Function PEACh_Form2VP_Daum(formWave)	// calculate vp using Daumit 
	wave formWave
	variable Cnum = formWave[0]
	variable Hnum = formWave[1]
	variable Onum = formWave[2]
	variable Nnum = formWave[3]

	variable Temp = 298
	
	make/O/N=4 b_coefs
	b_coefs = {-426.938,0.289223,0.00442057,0.292846} //k=0
	variable b_0 = b_coefs[0]/Temp + b_coefs[1] + b_coefs[2]*Temp + b_coefs[3]*ln(Temp)//1.79		
	
	b_coefs = {-411.248,0.896919,-0.00248607,0.140312} //k=1
	variable b_C = b_coefs[0]/Temp + b_coefs[1] + b_coefs[2]*Temp + b_coefs[3]*ln(Temp)// -0.438
	
	b_coefs = {-13.7456,0.523486,0.000550298,-0.27695} //k=9
	variable b_carb = b_coefs[0]/Temp + b_coefs[1] + b_coefs[2]*Temp + b_coefs[3]*ln(Temp)// -0.935
	
	b_coefs = {-725.373,0.826326,0.00250957,-0.232304} //k=7
	variable b_hyd = b_coefs[0]/Temp + b_coefs[1] + b_coefs[2]*Temp + b_coefs[3]*ln(Temp)// -2.23	
	
	variable MW = Cnum*12 + Hnum + Onum*16 + Nnum*14
	
	variable alpha = 1e6*MW/(Temp*8.21e-5)
	
	// From Daumit et al., Faraday Disc. 2013:
	// N_c = (log(C*) - log(alpha) - b_0 - b_carb + b_hyd)   /    ( b_C + (b_carb * (1- 0.5*H:C)) + (b_hyd * (O:C + 0.5*H:C - 1)) )
	// log(C*) =  log(alpha) + b_0 + b_C*N_c + (b_carb * (1 + Cnum* (1- 0.5*H:C))) +  (b_hyd * (-1 + Cnum* (O:C + 0.5*H:C - 1)))
		
	variable Cstar,OtoC,HtoC
	variable Onum_adj,N_NO3,N_carb,N_hyd
	Onum_adj = Onum
	
	N_NO3 = min(trunc(Onum_adj/3),Nnum)	// for every three oxygens and nitrogen (after excluding PAN group), assume a nitrate group
	Onum_adj = Onum_adj-2*N_NO3
	// nitrate gets treated as a hydroxy, other nitrogen is ignored
	OtoC = (Onum_adj)/Cnum // for every nitrate group, 2 O atoms are not bound to the carbon
	HtoC = (Hnum+N_NO3)/Cnum	// for every nitrate group, 1 H is missing
	
	N_carb =  (1 + Cnum* (1- 0.5*HtoC)) // number of carbonyls is equal to number of double bonds, assuming there are no rings
	N_carb =max(0, min(N_carb,Onum_adj-N_NO3))		// can't have more carbonyls than O atoms + nitrate groups
	
	N_hyd = Onum_adj -  N_carb // all O atoms that aren't carbonyls are hydroxy (nitrate treated as hydroxy)
	 
	Cstar = log(alpha) + b_0 + b_C*Cnum + (b_carb *N_carb) +  (b_hyd * N_hyd) 

	return Cstar
End



Function PEACh_Form2VP_Li(formWave) // calculate vp using Li 
	wave formWave
		
	
	variable Cnum = formWave[0]
	variable Hnum = formWave[1]
	variable Onum = formWave[2]
	variable Nnum = formWave[3]
	variable Snum=0
	
	// From Li et al., ACP, 2016:
	// 
	// log(C*) =  (n0_C - Cnum)*b_C - Onum*b_O - 2*((Cnum*Onum)/(Cnum + Onum))*b_CO - Nnum * b_N - Snum * b_S
	// 
	variable N_NO3 = min(trunc(Onum/3),Nnum)	// for every three oxygens and nitrogen (after excluding PAN group), assume a nitrate group
	
	variable MW = Cnum*12 + Hnum + Onum*16 + Nnum*14 + Snum*32
	
	// nitrate gets treated as a hydroxy, other nitrogen is ignored
	Onum = (Onum-2*N_NO3) // for every nitrate group, 2 O atoms are not bound to the carbon
	Hnum = (Hnum+N_NO3)	// for every nitrate group, 1 H is missing
	Nnum = (Nnum-N_NO3)	// remove all nitrates from number of nitrogens

	variable Temp = 298
	variable Cstar298,Cstar
	variable delH
	variable R = 8.3144598e-3	//units of KJ K-1 mol-1
	
	string CompClass = "CH"
	if(Onum > 0)
		CompClass += "O"
	endif	

	if(Nnum > 0)
		CompClass += "N"
	endif

	if(Snum > 0)
		CompClass += "S"
	endif
	
	
	// this version includes H

	
	// order: n0_C, b_C,b_H,b_O,b_CO,b_N,b_S
	Make/O/N=7 b_Coefs
	strswitch(CompClass)	
		case "CH":	
			b_Coefs = {17.95,0.5742,-0.1417,0,0,0,0}
			break
		case "CHO":	
			b_Coefs = {15.77,0.6238,-0.1387,1.735,-0.8592,0,0}
			break
		case "CHN":	
			b_Coefs = {23.01,0.4307,-0.02110,0,0,0.9528,0}
			break
		case "CHON":	
			b_Coefs = {21.12,0.4139,-0.03760,0.8092,-0.1174,1.1010,0}
			break
		case "CHOS":	
			b_Coefs = {16.07,0.5348,-0.1507,1.354,-0.4175,0,0.8993}
			break
		case "CHONS":	
			b_Coefs = {19.20,0.5469,-0.1368,1.183,0.07310,1.0289,1.323}
			break
		default:
			b_coefs= 0
	endswitch
	
	Cstar298 =  (b_Coefs[0]-Cnum)*b_Coefs[1] - Onum*b_Coefs[3] - Hnum*b_coefs[2] - 2*((Cnum*Onum)/(Cnum + Onum))*b_Coefs[4] - Nnum*b_Coefs[5] - Snum*b_Coefs[6]
	
	delH = -11*Cstar298 + 129	// from Epstein et al., EST 2010 (linear correlation between enthalpy of vaporization and room temperature C*)
	Cstar =  (10^Cstar298)*(298/Temp)*exp(-(delH/R)*((1/Temp)-(1/298)))	// from Li et al. adjust for temperature using enthalpy of vaporization
	Cstar = log(Cstar)
	return Cstar
End

Function PEACh_Form2VP_Dona(formWave) // calculate vp using Donahue 
	wave formWave
	variable Cnum = formWave[0]
	variable Hnum = formWave[1]
	variable Onum = formWave[2]
	variable Nnum = formWave[3]

	// From Donahue et al., ACP, 2011:
	// 
	// log(C*) =  (n0_C - Cnum)*b_C - Onum*b_O - 2*((Cnum*Onum)/(Cnum + Onum))*b_CO 
	// 


	variable MW = Cnum*12 + Hnum + Onum*16
	variable Temp = 298
	variable Cstar298,Cstar
	variable delH
	variable R = 8.3144598e-3	//units of KJ K-1 mol-1

	Make/O/N=4 b_Coefs = {25,0.475,2.3,-0.3}
	
	Cstar298 =  (b_Coefs[0]-Cnum)*b_Coefs[1] - Onum*b_Coefs[2] - 2*((Cnum*Onum)/(Cnum + Onum))*b_Coefs[3]
	delH = -11*Cstar298 + 129	// from Epstein et al., EST 2010 (linear correlation between enthalpy of vaporization and room temperature C*)
	Cstar =  (10^Cstar298)*(298/Temp)*exp(-(delH/R)*((1/Temp)-(1/298)))	// from Li et al. adjust for temperature using enthalpy of vaporization
	Cstar = log(Cstar)
	
	
	if(Nnum > 0)
		Cstar=NaN
	endif
	return Cstar
End


Function PEACh_Form2kOH_Dona(formWave) // calculate kOH using Daumit 
	wave formWave
	variable Cnum = formWave[0]
	variable Hnum = formWave[1]
	variable Onum = formWave[2]
	variable Nnum = formWave[3]

	// From Donahue et al., Environ Chem, 2013:
	// 
	// k_OH =  1.2e-12 * (Cnum + 9*Onum - 10 * (Onum/Cnum)^2))
	// 
	
	variable retVal = 1.2e-12 * (Cnum + 9*Onum - 10 * (Onum/Cnum)^2)
	if(Nnum > 0)
		retVal=NaN
	endif
	return retVal
End

Function PEACh_Cstar2Atm(inCstar)   // convert a Cstar value to atm assuming MW=200
	variable inCstar
	variable outAtm

	variable MW = 200
	variable R = 8.205e-5 // units of atm K-1 mol-1 m3
	variable T = 293
	
	outAtm = (inCstar * R * T)/(MW*1e6)
	
	return outAtm
End


Window PEAChprog_panel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(135.6,40.8,339,182.4) as "Progress"
	SetDrawLayer UserBack
	SetDrawEnv fsize= 8,fstyle= 2
	DrawText 27,138,"\\JCyou can resume by starting the code again\rwith exactly the same input wave"
	ValDisplay PEACh_numToDo,pos={33.00,36.60},size={159.00,13.20},bodyWidth=80,title="Number remaining:"
	ValDisplay PEACh_numToDo,limits={0,0,0},barmisc={0,1000},value= _NUM:0
	ValDisplay PEACh_timeRem,pos={0.00,57.60},size={187.20,13.20},bodyWidth=80,title="Estimated  time remaining"
	ValDisplay PEACh_timeRem,format="%1.1f minutes",limits={0,0,0},barmisc={0,1000}
	ValDisplay PEACh_timeRem,value= _NUM:0
	Button PEACh_stopBatch,pos={75.00,96.60},size={48.00,18.00},title="Stop"
	Button PEACh_stopBatch,fColor=(65535,32768,32768)
	ValDisplay PEACh_timePer,pos={63.00,81.00},size={111.00,11.40},bodyWidth=60,title="Time per item"
	ValDisplay PEACh_timePer,fSize=8,format="%1.4f secs"
	ValDisplay PEACh_timePer,limits={0,0,0},barmisc={0,1000},value= _NUM:0
	TitleBox PEACh_inWaveName,pos={36.60,5.40},size={130.20,28.80},title="\\JRProcessing wave \\f01NameOfWave\r\\f00as\\f01 formula"
	TitleBox PEACh_inWaveName,frame=2,anchor= MT
EndMacro

Function PEACh_HowToCite()
	KillWindow/Z Citation
	NewNotebook/F=0/ENCG=1/N=Citation as "How to cite"
	
	Notebook Citation text= "*** Parameter Estimation for Atmospheric Chemistry (PEACh) v.1 ****\r\r"
	
	Notebook Citation text= "Citation for using this package:\r"
	Notebook Citation text= "   Isaacman-VanWertz, G.; Aumont, B. \"Impact of structure on the estimation of atmospherically relevant \r   physicochemical parameters.\" Atmos. Chem. Phys. in review.\r\r"
	 
	Notebook Citation text= "This work should be cited if using any of the following:\r" 
	Notebook Citation text = " -Average Li-Daumit for vapor pressure (vp_LiDaum)\r -Linear-vp for HLC (HLC_linearVP)\r -Constants for kOH (kOH_Constants)\r -Nitrate modification to Li et al. (vp_ModLi)\r\r"
	Notebook Citation text= "Citations for individual methods:\r"
	Notebook Citation text= "  If using Daumit (vp_Daumit) or Average Li-Daumit (vp_LiDaum) for vapor pressure:\r"
	Notebook Citation text= "    Daumit, K. E.; Kessler, S. H.; Kroll, J. H. \"Average chemical properties and potential formation pathways of highly \r    oxidized organic aerosol.\" Faraday Discuss. 2013, 165, 181–202.\r\r"
	Notebook Citation text= "  If using modified Li (vp_ModLi) or Average Li-Daumit (vp_LiDaum) for vapor pressure:\r"
	Notebook Citation text= "    Li, Y.; Pöschl, U.; Shiraiwa, M. \"Molecular corridors and parameterizations of volatility in the chemical evolution of \r    organic aerosols.\" Atmos. Chem. Phys. 2016, 16 (5), 3327–3344.\r\r"
	Notebook Citation text= "  If using Donahue (vp_Donahue) for vapor pressure:\r"
	Notebook Citation text= "    Donahue, N. M.; Epstein, S. A.; Pandis, S. N.; Robinson, A. L. \"A two-dimensional volatility basis set: 1. \r    organic-aerosol mixing thermodynamics.\" Atmos. Chem. Phys. 2011, 11 (7), 3303–3318.\r\r"
	Notebook Citation text= "  If using Donahue (kOH_Donahue) for kOH:\r"
	Notebook Citation text= "    Donahue, N. M.; Chuang, W.; Epstein, S. A.; Kroll, J. H.; Worsnop, D. R.; Robinson, A. L.; Adams, P. J.; Pandis, S. N. \r    \"Why do organic aerosols exist? Understanding aerosol lifetimes using the two-dimensional volatility basis set.\"\r    Environ. Chem. 2013, 10 (3), 151–157."
	Notebook Citation writeprotect=1
	Notebook Citation findText={"*** Parameter Estimation for Atmospheric Chemistry (PEACh) v.1 ****",2^0+2^3+2^4}
	Notebook Citation selection={startoffile,startoffile}
end

Function PEACh_ReadMe()
	KillWindow/Z Info
	NewNotebook/F=0/ENCG=1/N=Info as "ReadMe"
	Notebook Info text= "*** Parameter Estimation for Atmospheric Chemistry (PEACh) v.1 ****\r\r"
	Notebook Info text= "This package estimates the physicochemical properties of molecular formulas.\rThis readme provides a short users guide, for information on how to cite this work, please see \"How To Cite\"\r\r"

	Notebook Info text= "Functions can be called from the PEACh menu, or from the command line.\r"
	Notebook Info text= "When using the commmand line, single inputs can be provided directly as strings\r\r"


	Notebook Info text= "Output of PEACh is formula-based estimations of:"
	Notebook Info text= "\r -vapor pressure, units of log (atm)\r -Henry's Law Constants, units of log (M/atm)\r -gas-phase OH rate constants, units of cm3/molec-s\r"
	Notebook Info text= "   All properties are calculated at T=298K and P=1 atm\r\r"

	Notebook Info text= "\r___METHODS___\r\r"
	Notebook Info text= "Descriptions of all estimation methods used are found in Isaacman-VanWertz and Aumont. They include (in output order):\r"
	Notebook Info text= " -vp_LiDaum: Vapor pressure by averaging Daumit and Li methjods, modified to acccount for nitrates (recommended)\r"
	Notebook Info text= " -HLC_linearVP: HLC from linear correlation with vp_LiDaum (recommended)\r"
	Notebook Info text= " -kOH_Constants: kOH as a constant depending on the elements present (recommended)\r"	
	Notebook Info text= " -vp_Daumit: Vapor pressure by Daumit et al. (2013)\r"
	Notebook Info text= " -vp_ModLi: Vapor pressure by Li et al. (2016), modified to account for nitrates\r"
	Notebook Info text= " -vp_Donahue: Vapor pressure by Donahue et al. (2011)\r"
	Notebook Info text= " -kOH_Donahue: kOH by Donahue et al. (2013)\r\r"

	Notebook Info text= "\r___INPUTS___\r\r"			
	Notebook Info text= "There are two options for how to provide input:\r"
	Notebook Info text= " Formulas:\r"
	Notebook Info text= "    Must be of the form XnYmZr (e.g., C4H10O or C4H10O2), where the number is allowed but not required for a single atom.\r"
	Notebook Info text= "    Only C, H, O, and/or N are allowed.\r"
	Notebook Info text= "    Order of elements does not matter.\r"
	Notebook Info text= "    Must contain at least one C, and any other elements only one time (e.g., C4H9O2H is not allowed).\r\r"
	Notebook Info text= " SMILES:\r"
	Notebook Info text= "    Use with caution! Converting SMILES strings into formulas is in development, some strings may convert incorrectly.\r"
	Notebook Info text= "    Only C, H, O, and/or N are allowed.\r\r"

	Notebook Info text= "Input can be provided as a single input as a string, or as a batch using a textwave.\r"

	Notebook Info text= "\r___OUTPUTS___\r\r"	
	Notebook Info text= "Results of single inputs are printed to the command line.\r"

	Notebook Info text= "Results of batch inputs include:\r"
	Notebook Info text= "  2D wave PEACh_output:\r"
	Notebook Info text= "    Rows are input lines. Rows are labeled with their input formula\r"
	Notebook Info text= "    Columns are estimated properties. Columns are labeled with the output property as named above\r"	
	Notebook Info text= "  1D text wave PEACh_error including any errors encountered for each input line\r"	
	Notebook Info text= "  2D text wave PEACh_input:\r"
	Notebook Info text= "    Rows are input lines\r"
	Notebook Info text= "    Columns are Formula, SMILES, and GECKO.\r"
	Notebook Info text= "    	   If input as formulas, SMILES and GECKO are all 'none'\r"
	Notebook Info text= "    	   If input as SMILES, GECKO is a derived  GECKO-compatible string, from which Formula is derived\r"
	Notebook Info text= "    	     In principle, the GECKO string can be used at the GECKO website, but accuracy is not guaranteed"			
	
	Notebook Info writeprotect=1
	Notebook Info findText={"*** Parameter Estimation for Atmospheric Chemistry (PEACh) v.1 ****",2^0+2^3+2^4}
	Notebook Info selection={startoffile,startoffile}
end