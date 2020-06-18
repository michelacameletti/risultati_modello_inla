#CREARE netCDF per campo SPDE delle 1000 simulazioni
rm(list=objects())
library("tidyverse")
library("INLA")
library("assertthat")
library("inlabru")
library("sf")
library("sp")
library("furrr")
library("raster")
library("ncdf4")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=-2,error=recover)
options(future.globals.maxSize= '+Inf')


plan(multicore,workers=28)

simI<<-501
simF<<-1000

purrr::map(1:1,.f=function(MESE){

#Fissare a TRUE o FALSE le due variabili per includerle o escluderle: in base a queste due variabili
#verra' mantenuta o meno TP ed inclusa o meno PTP. Per PTP usiamo il medesimo raster standardizzato
#di TP: PTP e TP differiscono solo per un giorno, conviene usare il raster standardizzato di TP
TP<-TRUE
PTP<-TRUE

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

#lettura e preparazione dati PM10
giornoI<-as.Date(glue::glue("2015-{MESE}-01"),format="%Y-%m-%d")
giornoF<-giornoI+(lubridate::days_in_month(giornoI)-1)

if(MESE!=1) giornoI<-giornoI-2
#Tramite YYMMDD e lubridate vogliamo ricavare quale indice (tra 1 e 365) assume ogni giorno dell'anno.
YYMMDD<-seq.Date(from=giornoI,to=giornoF,by="day")

#leggo risultati modello
#if(!file.exists(glue::glue("result{MESE}.RDS"))) stop(glue::glue("Non trovo il file result{MESE}.RDS"))

#readRDS(glue::glue("result{MESE}.RDS"))->inla.out

#inla.out$misc$configs$contents->contents
#rm(inla.out)

effect<-"i" #nome del latent field
#which(contents$tag==effect)->id.effect #id.effect mi da la posizione di "i" in contents

#dentro length ho la dimensione di ciascun effetto
#contents$length[id.effect]/length(YYMMDD)->lunghezzaEffettoi #corrisponde a mesh$n
lunghezzaEffettoi<-2506
indice0<-42664

readRDS(glue::glue("inlaSampleOut_mese{MESE}.RDS"))->simulazione.out


#prendiamo le componenti latent da ciascuno dei 1000 samples: quidentro trovo gli effetti fissi
#e random per costruire il linear predictor delle simulazioni
purrr::map(simulazione.out,"latent")->latentComponent
rm(simulazione.out)

#leggo il layer vuoto
raster("../archivio_tif/meteoLayer.tif")->meteoLayer
extent(meteoLayer)->estensione


#se PTP==TRUE vuol dire che devo prendere TP e trasformarla in PTP

#La mesh mi serve per proiettare il latent field
readRDS(glue::glue("iset{MESE}.RDS"))->iset

#la mesh non varia con i mesi
readRDS("mesh.RDS")->mesh

#riporto le coordinate in km
mesh$loc[,1]<-mesh$loc[,1]*1000
mesh$loc[,2]<-mesh$loc[,2]*1000 

tryCatch({
  RPushbullet::pbPost(type="note",title=glue::glue("{AREA}"),body="Ho iniziato interpolazione latent field")
},error=function(e){
  glue::glue("{AREA}: ho finito interpolazione latent field!")
})

#simulation.out lista di 1000 elemnti, ogni elemento contiene una matrice latent
#utilizzando la posizione "id.effect" individua precedentemente mediante contents
#so dove trovare gli elementi "i" (latent field) di ciascuno dei 31 giorni del mese
#a cui sommare i fixed effects7
furrr::future_map(simI:simF,.f=function(SIM){
  
 
  #questa e' la posizione iniziale dell'effetto "i" latent field dentro
  #la componente "latent" in ciascuno dei samples
 
 extract


#Calcolo la mappa con le variabili spazio-temporali+SPDE

purrr::map(seq(indice0,by=lunghezzaEffettoi,length.out = 31),.f=function(qualeGiorno){


  #start mi dice la posizione di partenza dell'effetto in nell'elemento "latent" di ciascuno
  #dei 1000 samples prodotti da inla.posterior.sample
  (qualeGiorno:(qualeGiorno+lunghezzaEffettoi-1))->indiciEffettoi
  #print(indice0)
  
  #if((qualeGiorno==indice0) && PTP) return(NULL)
  #se uso ptp il primo giorno avra' ptp tuttto NA
  #e quindi una stima di pm10 tutta NA...quindi non posso fare il trim!
  #Restituisco NULL (vedi dopo)
  
  #spde (media)
  #questo il latent field del sample che poi vado a riproiettare
  latentComponent[[SIM]][indiciEffettoi,]->campo
  #le righe devono essere identificate danomi del tipo i:numero
  assert_that(all(grepl("^i:[0-9]+",rownames(latentComponent[[SIM]])[indiciEffettoi])))
  
  inla.mesh.projector(mesh,xlim=c(estensione@xmin,estensione@xmax),ylim=c(estensione@ymin,estensione@ymax),dims = c(1287,999))->myproj
  inla.mesh.project(myproj,campo)->campoProj
  raster(list(x=myproj$x,y=myproj$y,z=campoProj))->myraster
  crs(myraster)<-CRS("+init=epsg:32632")
  
  projectRaster(myraster,meteoLayer)->SPDE #spde medio per giorno yymmdd
  #rm(myraster)  
  #rm(campo)

  crop(extend(SPDE,meteoLayer),meteoLayer)->SPDE
  mask(SPDE,italia)->SPDE2

  trim(SPDE2) 

    
})->listaMediaPM10 #fine furrr su YYMMDD

if(PTP){
  
  #which(is.null(listaMediaPM10))->qualeNULL
  #stopifnot(qualeNULL==1) #deve essere solo il primo elemento nella lista
  #purrr::compact(listaMediaPM10)->listaMediaPM10
  brick(listaMediaPM10)->mybrick
  
  #mybrick[[1]]->primoRaster
  #primoRaster[primoRaster> -9999]<-NA
  #brick(stack(primoRaster,mybrick))->mybrick
  
  #il fatto di mantenere il primo raster di NA mi serve per mantenere validi gli indici
  #ricavati da BANDA e YYMMDD
  
}else{
  
  brick(listaMediaPM10)->mybrick
  
}


mybrick


})->listaOut #fine walk su SIM

purrr::iwalk(listaOut,.f=function(.x,.y){

	.z<-.y+simI-1
	writeRaster(.x,filename=glue::glue("SPDE_sim{.z}.nc"),format="CDF")

})

list
tryCatch({
  RPushbullet::pbPost(type="note",title=glue::glue("{AREA}"),body="Ho finito interpolazione latent field")
},error=function(e){
  glue::glue("{AREA}: ho finito interpolazione latentfield!")
})



})#FINE PURRR WALK SU MESE


