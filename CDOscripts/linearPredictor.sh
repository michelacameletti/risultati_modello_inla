#!/bin/bash

source Intercept.sh
source d_a1.sh
source i_surface.sh
source q_dem.sh
source varianza.sh
source aod550.sh
source dust.sh
source logpbl00.sh
source logpbl12.sh
source ptp.sh
source sp.sh
source t2m.sh
source tp.sh

#ii va da 0 a 999 (1000 simulazioni): dentro il ciclo
#poi ii viene sommato a 1 in quanto i campi SPDE vanno da 1 a 1000
for ii in $(seq 0 9);do

#varianza va sommata a eta prima di passare all'esponenziale
#Attenzione: la Varianza va moltiplicata per 0.5 (formula lognormale)
Varianza=${vvarianza[${ii}]}

echo "*********"
#bc serve per fare operazioni con double in bash
SigmaQuadro05=$(echo "${Varianza}*0.5" |bc)
echo ${Varianza}
echo ${SigmaQuadro05}

echo "*********"

#I comandi source all'inizio dello script servono a importare i contenuti dei 
#file .sh prodotti con R. Con R, per ogni parametro/iperparametro del modello e' stato prodotto
#un vettore in stile bash. Questo vettore contiene, ad esempio in q_dem.sh, gli effetti 
#della quota stimati sui 1000 samples prodotti mediante inla.posterior.sample

Intercetta=${vIntercept[${ii}]}
beta_q_dem=${vq_dem[${ii}]}
beta_i_surface=${vi_surface[${ii}]}
beta_d_a1=${vd_a1[${ii}]}
beta_aod=${vaod550[${ii}]}
beta_dust=${vdust[${ii}]}
beta_logpbl00=${vlogpbl00[${ii}]}
beta_logpbl12=${vlogpbl12[${ii}]}
beta_sp=${vsp[${ii}]}
beta_t2m=${vt2m[${ii}]}
beta_tp=${vtp[${ii}]}
beta_ptp=${vptp[${ii}]}


echo ${Intercetta}
echo ${beta_q_dem}
#echo ${beta_i_surface}
#echo ${beta_d_a1}
#echo ${beta_aod}
#echo ${beta_logpbl00}
#echo ${beta_logpbl12}
#echo ${beta_dust}
#echo ${beta_sp}
echo ${beta_t2m}
#echo ${beta_tp}
echo ${beta_ptp}

#comincio con la componente solo spaziale, al dem*beta sommo Intercetta modello
cdo addc,${Intercetta} -mulc,${beta_q_dem} q_dem.s.nc IQ_DEM.S.nc

#d_a1 e i_surface
cdo mulc,${beta_d_a1} d_a1.s.nc D_A1.S.nc
cdo mulc,${beta_i_surface} i_surface.s.nc I_SURFACE.S.nc

#sommo le componenti spaziali (con intercetta)
cdo add IQ_DEM.S.nc D_A1.S.nc SPATIAL0.nc
rm -rf D_A1.S.nc
rm -rf IQ_DEM.S.nc
cdo add I_SURFACE.S.nc SPATIAL0.nc SPATIAL.nc
rm -rf SPATIAL0.nc
rm -rf I_SURFACE.S.nc


#a SPATIAL.nc sommo il campo SPDE relativo alla simulazione ${ii}+1: ii va da 0 a numSIm
#mentre i campi SPDE hanno una numerazione che parte da 1 a numSim+1
let SIM=${ii}+1
echo ${ii}
#SPDE
cdo add SPDE_sim${SIM}.nc SPATIAL.nc spdeSPATIAL.nc
rm -rf SPATIAL.nc

#sommo il dust
cdo mulc,${beta_dust} dust_daily_utm.nc TEMP.nc
cdo add spdeSPATIAL.nc TEMP.nc spdeSPATIAL_1.nc
rm -rf TEMP.nc
rm -rf spdeSPATIAL.nc

#sommo aod
cdo mulc,${beta_aod} aod550.s_daily_utm.nc TEMP2.nc
cdo add spdeSPATIAL_1.nc TEMP2.nc spdeSPATIAL_2.nc
rm -rf TEMP2.nc
rm -rf spdeSPATIAL_1.nc

#sommo log.pbl00
cdo mulc,${beta_logpbl00} log.pbl00.s_daily_utm.nc TEMP3.nc
cdo add spdeSPATIAL_2.nc TEMP3.nc spdeSPATIAL_3.nc
rm -rf TEMP3.nc
rm -rf spdeSPATIAL_2.nc

#sommo log.pbl12
cdo mulc,${beta_logpbl12} log.pbl12.s_daily_utm.nc TEMP4.nc
cdo add spdeSPATIAL_3.nc TEMP4.nc spdeSPATIAL_4.nc
rm -rf TEMP4.nc
rm -rf spdeSPATIAL_3.nc

#sommo sp
cdo mulc,${beta_sp} sp.s_daily_utm.nc TEMP5.nc
cdo add spdeSPATIAL_4.nc TEMP5.nc spdeSPATIAL_5.nc
rm -rf TEMP5.nc
rm -rf spdeSPATIAL_4.nc

#sommo t2m
cdo mulc,${beta_t2m} t2m.s_daily_utm.nc TEMP6.nc
cdo add spdeSPATIAL_5.nc TEMP6.nc spdeSPATIAL_6.nc
rm -rf TEMP6.nc
rm -rf spdeSPATIAL_5.nc

#sommo tp
cdo mulc,${beta_tp} tp.s_daily_utm.nc TEMP7.nc
cdo add spdeSPATIAL_6.nc TEMP7.nc spdeSPATIAL_7.nc
rm -rf TEMP7.nc
rm -rf spdeSPATIAL_6.nc

#sommo ptp
cdo mulc,${beta_ptp} ptp.s_daily_utm.nc TEMP8.nc
cdo add spdeSPATIAL_7.nc TEMP8.nc spdeSPATIAL_8.nc
rm -rf TEMP8.nc
rm -rf spdeSPATIAL_7.nc

#Infine sommo il rumore IID dovuto all'effetto centralina
#cdo add IDCENTRALINA_sim${SIM}.nc  spdeSPATIAL_8.nc spdeSPATIAL_9.nc

cdo -setname,PM10 -settaxis,2015-01-01,12:00:00,1day -exp -addc,${SigmaQuadro05} spdeSPATIAL_8.nc noiid_mappa_gennaio${SIM}.nc

done
