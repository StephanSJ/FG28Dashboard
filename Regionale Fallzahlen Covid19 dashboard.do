*-------------------------------------------------------------------------------*
* Pfade RKI Office Niels
* Datenordner 
global data "S:\OE\FG28\COVID19\Covid_19 Cube"
* Shapefiles Ordner
global shape "S:\OE\FG28\205 Regionale Unterschiede\Referenzdaten\Kartendaten"
* R-Projekt Ordner  
cd "S:\OE\FG28\COVID19\FG28Dashboard"
*-------------------------------------------------------------------------------*


*-------------------------------------------------------------------------------*
* Pfade Homeoffice Niels
* Datenordner 
* global data "D:\Data\Covid19 Meldezahlen\Covid_19 Cube"
* Shapefiles Ordner
* global shape "D:\Data\Shapefiles\Referenzdaten\"
* R-Projekt Ordner  
* cd "D:\work\projects_RStudio\FG28Dashboard"
*-------------------------------------------------------------------------------*


*********************************************************************************
* I. Datenaufbereitung
*********************************************************************************

*-------------------------------------------------------------------------------*
* 1. Datei um den Landkreisstrings aus Meldedaten die KKZ anzuspielen
*-------------------------------------------------------------------------------*
import excel using "Schlüssel Landkreisstring KKZ.xlsx", clear first  
save "Schlüssel Landkreisstring KKZ.dta", replace

*-------------------------------------------------------------------------------*
* 2. Datei um Bevölkerungszahlen auf Kreisebene anzuspielen
*-------------------------------------------------------------------------------*

* Quelle: Destatis
* Gebietsstand: 31.12.2018
* Erscheinungsmonat: Oktober 2019
import excel using "$data\04-kreise.xlsx", clear first cellrange(A8:I478)  sheet("Kreisfreie Städte u. Landkreise")  
gen dropcases=strlen(A)
rename A kkz
rename SchleswigHolstein typ
	label var typ "Kreis oder Kreisfreie Stadt"
rename C kreisname
rename D nuts3
rename E area
rename F pop
rename G pop_m
rename H pop_f
rename I pop_dens

keep if dropcases==5 // nur Information über Kreise behalten
destring kkz, replace

save "Kreise_pop.dta", replace

*-------------------------------------------------------------------------------*
* 3. Meldedaten aufbereiten
*-------------------------------------------------------------------------------*

import delimited "https://opendata.arcgis.com/datasets/dd4580c810204019a7b8eb3e0b329dd6_0.csv", clear encoding(utf-8)

encode altersgruppe, gen(agecat)
encode landkreis, gen(meldelandkreis)
encode bundesland, gen(bula)
sort refdatum
encode refdatum, gen(infdatum)
sort meldedatum
encode meldedatum, gen(meldedat)

ta anzahlfall

ta anzahltod


replace idlandkreis=11000 if bula==3
 * Um den GISD anzuspielen wird Berlin desaggregiert	
 
* Fallzahlen aggegieren und crude CFR berechnen
collapse (sum) anzahltod (sum) anzahlfall (mean) bula (mean) meldelandkreis, by(idlandkreis meldedat)
	replace meldelandkreis=500 if bula==3
		label def meldelandkreis 500 "Berlin", add
	lab val bula bula
	lab val meldelandkreis meldelandkreis
	reshape wide anzahltod anzahlfall , i(meldelandkreis bula) j(meldedat) 	
	
egen fall_total=rowtotal(anzahlfall*)
egen verst_total=rowtotal(anzahltodesfall*)
gen cfr=verst_total/fall_total
	replace cfr=0 if verst_total==0

order meldelandkreis fall_total verst_total cfr, first
	
rename idlandkreis kkz
	
*-------------------------------------------------------------------------------*
* 3. Bevölkerungszahlen anspielen
*-------------------------------------------------------------------------------*	
merge m:1 kkz using "Kreise_pop.dta"	
drop _merge 	


gen fall_p100k=fall_total/pop*100000
gen verst_p100k=verst_total/pop*100000

save "FG28_meldedaten_arbeitsdatensatz.dta", replace	
	
*********************************************************************************
* II. Erstellung von Karten 
*********************************************************************************

use "FG28_meldedaten_arbeitsdatensatz.dta", clear

*GISD-Map
gen KRkennziffer=kkz

* Kreisgebietsreform Göttingen: Zusammenlegung von LK Göttingen und LK Osterode am Harz
recode KRkennziffer 3159=3152	// KKZ Göttingens mit alter KKZ überschreiben
* Die bislang verwendeten Kartendaten trennen beide Landkreise noch. 
* Damit die Information des zusammengefassten Landkreises Göttingen auf der Karte auch für Osterode angezeigt werden, muss ein weiterer Fall kreiert werden. 
* Osterode im Harz
list if KRkennziffer==3152 // Zeile von Göttingen identifizieren
expand 2 in 26 // Zeile von Göttingen duplizieren
recode KRkennziffer 3152=3156 in 26 // Kreiskennziffer in einem der Zeilen durch KKZ Osterodes ersetzen

* Zusammenfassen der Berliner Bezirke zu Berlin 
replace KRkennziffer=11000 if bula==3	// Zusammenfassen der Berliner Bezirke
	
* Todo: Shapefiles für eine Karte der Kreise inklusive Berliner Bezirke finden


merge m:1 KRkennziffer using "$shape\Kartendaten\BRD\2012\BRD_KRS.dta"
drop _merge
sort KRkennziffer
drop if KRkennziffer[_n]==KRkennziffer[_n-1]
		  	
* Karte Fallzahlen	
spmap fall_total using "$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta" , legenda(on)   ///
  id(KRkennziffer ) fcolor(rkicmyk5 rkicmyk4 rkicmyk3 rkicmyk2 rkicmyk1) ///
  clm(custom) clbreaks(0 200 400 800 1600 10000) ///
  ndlabel(keine Daten)	  ///
  subtitle("") legorder(lohi)   ///
  polygon(  osize(thin) data("$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta") legshow(2 3 4 5))  ///
  osize(thin .. )  legstyle(2)   graphregion(margin(zero) style(none))  ///
  legend(size(small)  keygap(minuscule) symysize(medium) ///
          symxsize(small) ring(1) row(1) pos(6) rowgap(tiny) colgap(small)) legjunction(" {&ge} ") 		
gr export "Fallzahlen_Regional.png" , width(450) replace	 		


* Karte Fallzahlen pro 100k EW	
spmap fall_p100k using "$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta" , legenda(on)   ///
  id(KRkennziffer )  fcolor(rkicmyk5 rkicmyk4 rkicmyk3 rkicmyk2 rkicmyk1) ///
  clm(custom)   clbreaks(0 100 200 400 800 1600) ///
  ndlabel(keine Daten)	  ///
  subtitle("") legorder(lohi)   ///
  polygon(  osize(thin) data("$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta") legshow(2 3 4 5))  ///
  osize(thin .. )  legstyle(2)   graphregion(margin(zero) style(none))  ///
  legend(size(small)  keygap(minuscule) symysize(medium) ///
          symxsize(small) ring(1) row(1) pos(6) rowgap(tiny) colgap(small)) legjunction(" {&ge} ") 		
gr export "Fallzahlen_p100k_Regional.png" , width(450) replace	 		
	
	

* Karte Verstorbene 
spmap verst_total using "$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta" , legenda(on)   ///
  id(KRkennziffer ) fcolor(rkicmyk5 rkicmyk4 rkicmyk3 rkicmyk2 rkicmyk1) ///
  clm(custom) clbreaks(0 5 20 40 80 160) ///
  ndlabel(keine Daten)	  ///
  subtitle("") legorder(lohi)   ///
  polygon(  osize(thin) data("$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta") legshow(2 3 4 5))  ///
  osize(thin .. )  legstyle(2)   graphregion(margin(zero) style(none))  ///
  legend(size(small)  keygap(minuscule) symysize(medium) ///
          symxsize(small) ring(1) row(1) pos(6) rowgap(tiny) colgap(small)) legjunction(" {&ge} ") 	
gr export "Todeszahlen_Regional.png" , width(450) replace	 		  

* Karte Verstorbene 
spmap verst_p100k using "$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta" , legenda(on)   ///
  id(KRkennziffer ) fcolor(rkicmyk5 rkicmyk4 rkicmyk3 rkicmyk2 rkicmyk1) ///
  clm(custom) clbreaks(0 5 20 50 100 200) ///
  ndlabel(keine Daten)	  ///
  subtitle("") legorder(lohi)   ///
  polygon(  osize(thin) data("$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta") legshow(2 3 4 5))  ///
  osize(thin .. )  legstyle(2)   graphregion(margin(zero) style(none))  ///
  legend(size(small)  keygap(minuscule) symysize(medium) ///
          symxsize(small) ring(1) row(1) pos(6) rowgap(tiny) colgap(small)) legjunction(" {&ge} ") 	
gr export "Todeszahlen_p100k_Regional.png" , width(450) replace	 		  
	
* Karte CFR
spmap cfr using "$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta" , legenda(on)   ///
  id(KRkennziffer ) fcolor(rkicmyk5 rkicmyk4 rkicmyk3 rkicmyk2 rkicmyk1) ///
  clm(custom) clbreaks(0 0.02 0.04 0.06 0.08 0.10 0.12 0.14 0.2) ///
  ndlabel(keine Daten)	  ///
  subtitle("") legorder(lohi)   ///
  polygon(  osize(thin) data("$shape\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta") legshow(2 3 4 5))  ///
  osize(thin .. )  legstyle(2)   graphregion(margin(zero) style(none))  ///
  legend(size(small)  keygap(minuscule) symysize(medium) ///
          symxsize(small) ring(1) row(1) pos(6) rowgap(tiny) colgap(small)) legjunction(" {&ge} ") 	
gr export "Krude_CFR_Regional.png" , width(450) replace	 		  


* Option clm(kmeans) erzeugt natural breaks
	
	
