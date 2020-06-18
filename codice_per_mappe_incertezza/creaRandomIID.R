#CREARE netCDF per IIDCENTRALINA RANDOM EFFECT delle 1000 simulazioni
rm(list=objects())
library("tidyverse")
library("INLA")
library("furrr")
library("raster")
library("sf")
library("sp")
library("ncdf4")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=-2,error=recover)
options(future.globals.maxSize= '+Inf')


plan(multicore,workers=30)

simI<<-1
simF<<-500

purrr::map(1:1,.f=function(MESE){


#legge la directory e desume la regione o area su cui fare l'analisi
getArea()->info
info$reg->REGIONI
info$area->AREA

###### QUESTA PARTE SERVE PER FILTRARE LE STAZIONI PER REGIONI, INVECE DI FARE GIRARE IL MODELLO SU TUTTA ITALIA
# Il filtro avviene mediante st_intersects tra lo shapefile dell'Italia e i punti stazione
#Se sardegna==TRUE lo shapefile utilizzato per filtrare le stazioni contiene anche la Sardegna
#7giugno 2020:nel file leggi.R aggiornato il file gadm per leggere lo shapefile non semplificato
leggiItalia(regioni=REGIONI,sardegna=SARDEGNA,buffSize = 0)->listaItalia #italia ora rappresenta solo REGIONI
listaItalia[["italia"]]->italia
listaItalia[["shRegioni"]]->shRegioni
as_Spatial(italia)->italia

readRDS(glue::glue("inlaSampleOut_mese{MESE}.RDS"))->simulazione.out


#prendiamo le componenti latent da ciascuno dei 1000 samples: quidentro trovo gli effetti fissi
#e random per costruire il linear predictor delle simulazioni
purrr::map(simulazione.out,"hyperpar")->hyperparComponent
rm(simulazione.out)

#leggo il layer vuoto
raster("../archivio_tif/q_dem.s.nc")->meteoLayer
meteoLayer[meteoLayer> -9999]<-0
mask(meteoLayer,italia)->meteoLayer

trim(meteoLayer)->meteoLayer 


furrr::future_map(simI:simF,.f=function(SIM){
  
  as.numeric(hyperparComponent[[SIM]]["Precision for id_centralina"])->precisione
  sqrt(1/precisione)->stdIID
  rnorm(n=1146852,mean=0,sd=stdIID)->valoriCelle

  setValues(meteoLayer,values = valoriCelle)->meteoLayer
 
  meteoLayer

    
})->listaOut #fine walk su SIM

purrr::iwalk(listaOut,.f=function(.x,.y){

	.z<-.y+simI-1
	writeRaster(.x,filename=glue::glue("IDCENTRALINA_sim{.z}.nc"),format="CDF")
	
})

})#FINE PURRR WALK SU MESE


