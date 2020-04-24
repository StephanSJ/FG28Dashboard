cd "S:\OE\FG28\COVID19\FG28Dashboard"

import excel using "S:\OE\FG28\COVID19\FG28Dashboard\Schlüssel Landkreisstring KKZ.xlsx", clear first  
save "S:\OE\FG28\COVID19\FG28Dashboard\Schlüssel Landkreisstring KKZ.dta", replace

* Alle Infos auf Individualebene
import delim using "S:\OE\FG28\COVID19\FG28Dashboard\Covid19_Liste_2020-04-22_Faelle_ohne_deskription.csv", clear delim(";") 

drop aktenzeichen wasvorhanden was exp*

gen alter=alterberechnet
	replace alter=. if alter>114
	mvdecode alter, mv(-1=.)

egen agecat=cut(alter), at(0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 120)

egen agecat2=cut(alter), at(0, 5, 15, 35, 60, 80, 120)
	recode agecat2 (0=1 "0-4") (5=2 "5-14") (15=3 "15-34") (35=4 "35-59") (60=5 "60-79") (80=6 "80 und älter"), gen(agegrp)

ta verstorbenst
gen verstorben=verstorbenst
	replace verstorben=".a" if verstorben=="-nicht erhoben-" 
	replace verstorben=".b" if verstorben=="-nicht ermittelbar-" 
	replace verstorben="1" if verstorben=="Ja" 
	replace verstorben="0" if verstorben=="Nein" 
	destring verstorben, replace
	lab def verstorben 1 "ja" 0 "nein"
	lab val verstorben verstorben 
	
ta fallstatus
gen fall=fallstatus
	replace fall="1" if fall=="bestätigt"
	destring fall, replace
	
gen verst_=1 if verstorben==1
	
recode meldewoche 28=15

encode meldelandkreisbundesland, gen(bula)
	
replace meldelandkreis="Berlin" if bula==3	
	
collapse (mean) cfr=verstorben  (count) verst_ (count) fall (mean) bula , by(meldelandkreis meldewoche)
	lab val bula bula
	reshape wide verst_ fall cfr , i(meldelandkreis bula) j(meldewoche) 	
	
egen fall_total=rowtotal(fall*)
egen verst_total=rowtotal(verst_*)
gen cfr=verst_total/fall_total

order meldelandkreis fall_total verst_total cfr, first
	
merge m:1 meldelandkreis using "S:\OE\FG28\COVID19\FG28Dashboard\Schlüssel Landkreisstring KKZ.dta"

order meldelandkreis kkz fall_total verst_total cfr, first
	
*GISD-Map
gen KRkennziffer=kkz
recode KRkennziffer 3159=3152	// Kreisgebietsreform Göttingen

replace KRkennziffer=11000 if bula==3	// Berlin 


drop _merge

merge m:1 KRkennziffer using "S:\OE\FG28\205 Regionale Unterschiede\Referenzdaten\Kartendaten\BRD\2012\BRD_KRS.dta"
* Probleme: Berliner Bezirke zusammenfassen, oder in Karte integrieren


		  	
* Karte Fallzahlen	
spmap fall_total using "S:\OE\FG28\205 Regionale Unterschiede\Referenzdaten\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta" , legenda(on)   ///
  id(KRkennziffer ) fcolor(rkicmyk5 rkicmyk4 rkicmyk3 rkicmyk2 rkicmyk1) clm(custom)   clbreaks(0 200 400 800 1600 10000) ///
  ndlabel(keine Daten)	  ///
  subtitle("") legorder(lohi)   ///
  polygon(  osize(thin) data("S:\OE\FG28\205 Regionale Unterschiede\Referenzdaten\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta") legshow(2 3 4 5))  ///
  osize(thin .. )  legstyle(2)   graphregion(margin(zero) style(none))  ///
  legend(size(small)  keygap(minuscule) symysize(medium) ///
          symxsize(small) ring(1) row(1) pos(6) rowgap(tiny) colgap(small)) legjunction(" {&ge} ") 		
gr export "Fallzahlen_Regional.png" , width(450) replace	 		
	


* Karte Verstorbene 
spmap verst_total using "S:\OE\FG28\205 Regionale Unterschiede\Referenzdaten\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta" , legenda(on)   ///
  id(KRkennziffer ) fcolor(rkicmyk5 rkicmyk4 rkicmyk3 rkicmyk2 rkicmyk1) clm(custom) clbreaks(0 5 20 50 160) ///
  ndlabel(keine Daten)	  ///
  subtitle("") legorder(lohi)   ///
  polygon(  osize(thin) data("S:\OE\FG28\205 Regionale Unterschiede\Referenzdaten\Kartendaten\BRD\2012\BRD_KRS_Koordinaten.dta") legshow(2 3 4 5))  ///
  osize(thin .. )  legstyle(2)   graphregion(margin(zero) style(none))  ///
  legend(size(small)  keygap(minuscule) symysize(medium) ///
          symxsize(small) ring(1) row(1) pos(6) rowgap(tiny) colgap(small)) legjunction(" {&ge} ") 	
gr export "Todeszahlen_Regional.png" , width(450) replace	 		  

	
	

