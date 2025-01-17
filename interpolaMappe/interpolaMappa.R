#revisione 9 giugno
rm(list=objects())
library("tidyverse")
library("INLA")
library("assertthat")
library("inlabru")
library("sf")
library("sp")
library("furrr")
library("raster")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=2,error=recover)

plan(multicore)

furrr::future_map(5:12,.f=function(MESE){

#lettura parametri per standardizzare i raster
read_delim("../parametriPerStandardizzareRaster_5giugno2020/rasters_parametri.csv",delim=";",col_names=TRUE)->parametri

#nome del file di output in cui salvare i risultati dell'interpolazione
nomeBrick<-glue::glue("exp_pm10_mese{MESE}.tif")

########################################################################################
#nomiSpatial: variabili solo spaziali da utilizzare per le mappe (non spazio temporali)
#
#attenzione: per ogni variabilequi elencata deve essere aggiustato il codice che estrae i
#raste da postgis e il codice che somma i rate spatiali con intercetta. Il fatto che qui una
#variabile sia qui elencata garantisce solo che il codice tra gli "if" venga eseguito
########################################################################################
nomiSpatial<-c("i_surface","q_dem","d_a1")

########################################################################################
#nomiRasters: variabili spazio-temporali (essenzialmente le variabili meteoclimatiche)
########################################################################################

#In nomiRasters riportare i nomi delle variabili meteoclimatiche (senza suffisso s, nel databse le variabili sono
#standardizzate cella per cella, quando invece vogliamo una standardizzazione globale)

#In nomiRasters riportare SOLO tp sia che che si voglia tp che si voglia ptp o entrambe
c("aod550.s","log.pbl00.s","log.pbl12.s","tp.s","sp.s","t2m.s","dust")->nomiRasters

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
if(!file.exists(glue::glue("result{MESE}.RDS"))) stop(glue::glue("Non trovo il file result{MESE}.RDS"))
readRDS(glue::glue("result{MESE}.RDS"))->inla.out

#leggo il layer vuoto
raster("../archivio_tif/meteoLayer.tif")->meteoLayer
extent(meteoLayer)->estensione

#intercetta: e' il layer su cui sommiamo poi tutte le altre componenti
#Inizializzo spatial layer con l'intercetta
inla.out$summary.fixed["Intercept",]$mean->INTERCETTA
setValues(meteoLayer,INTERCETTA)->spatialLayer

purrr::walk(nomiSpatial,.f=function(covariataSpaziale){
 
  nomeFileRaster<-glue::glue("../archivio_tif/{covariataSpaziale}.tif")
  assert_that(file.exists(nomeFileRaster))
  raster(nomeFileRaster)->myRaster
  extend(myRaster,estensione)->myRaster
  
  #scalo myRaster
  parametri[parametri$covariata==covariataSpaziale,]$mean->MEDIA
  parametri[parametri$covariata==covariataSpaziale,]$sd->SD
  (myRaster-MEDIA)/SD->myRaster.s
  inla.out$summary.fixed[glue::glue("{covariataSpaziale}.s"),]$mean->BETA
  spatialLayer+(BETA*myRaster.s)->>spatialLayer
  
})



purrr::map(nomiRasters,.f=function(nomeRaster){
  
  list.files(pattern=glue::glue("{nomeRaster}.+tif$"),path = "../archivio_tif/",full.names = TRUE)->nomeFile
  stopifnot(length(nomeFile)==1)  

  brick(nomeFile)->xx
  raster::subset(xx,lubridate::yday(YYMMDD))->xx
  nlayers(xx)->NUMERO.LAYERS
  if(NUMERO.LAYERS!=length(YYMMDD)) stop("I file .tif hanno un numero di layers diverso dal numero di giorni")
  
  return(xx)
  
})->listaRasters

names(listaRasters)<-nomiRasters



#se PTP==TRUE vuol dire che devo prendere TP e trasformarla in PTP
if(PTP){
  
  #se voglio ptp come "nomiRasters" deve elencare "tp". Poi partendo dalla pioggia
  #ricostruisco ptp
  if(!("tp.s" %in% nomiRasters)) stop("tp non trovato in nomiRasters")
  
  listaRasters[["tp.s"]]->pioggia
  nlayers(pioggia)->numeroLivelli
  pioggia[[numeroLivelli]]->ultimoRaster
  setValues(ultimoRaster,NA)->ultimoRaster
  stack(ultimoRaster,pioggia[[1:(numeroLivelli-1)]])->ptp
  suppressWarnings(brick(ptp)->ptp)
  listaRasters$ptp.s<-ptp
  rm(ptp)
  rm(pioggia)
  rm(ultimoRaster)
  
}

#SE TP == FALSE allora vuole dire che l'ho presa solo per creare ptp, la elimino da listaRasters
if(!TP){listaRasters$tp.s<-NULL}


#AGGIORNO nomiRasters in modo di tener conto dell'effettiva presenza di tp.s e ptp.s
nomiRasters<-names(listaRasters)


#La mesh mi serve per proiettare il latent field
readRDS(glue::glue("iset{MESE}.RDS"))->iset

#la mesh non varia con i mesi
readRDS("mesh.RDS")->mesh

#riporto le coordinate in km
mesh$loc[,1]<-mesh$loc[,1]*1000
mesh$loc[,2]<-mesh$loc[,2]*1000 

tryCatch({
  RPushbullet::pbPost(type="note",title=glue::glue("{AREA}"),body="Ho iniziato interpolazione")
},error=function(e){
  glue::glue("{AREA}: ho iniziato interpolazione!")
})


#Calcolo la mappa con le variabili spazio-temporali+SPDE
purrr::map(1:length(YYMMDD),.f=function(qualeGiorno){


  if((qualeGiorno==1) && PTP) return(NULL)
  #se uso ptp il primo giorno avra' ptp tuttto NA
  #e quindi una stima di pm10 tutta NA...quindi non posso fare il trim!
  #Restituisco NULL (vedi dopo)
  

  #INIZIALIZZO (giorno x giorno) metoLayer con la componente spaziale
  spatialLayer->meteoLayer
  
  #nomiRasters adesso contiene anche ptp.s e tp.s se richiesti
  purrr::walk(nomiRasters,.f=function(nomeCovariata){
    
    print(glue::glue("Covariata {nomeCovariata}"))
    inla.out$summary.fixed[nomeCovariata,]$mean->MEDIA
    
    listaRasters[[nomeCovariata]][[qualeGiorno]]->xx
    extend(xx,estensione)->xx
    crop(xx,meteoLayer)->xx
    
    meteoLayer+(MEDIA*xx)->>meteoLayer
 
  })  
  
 
  #spde (media)
  inla.out$summary.random$i[iset$i.group==qualeGiorno,"mean"]->campo
  inla.mesh.projector(mesh,xlim=c(estensione@xmin,estensione@xmax),ylim=c(estensione@ymin,estensione@ymax),dims = c(1287,999))->myproj
  inla.mesh.project(myproj,campo)->campoProj
  raster(list(x=myproj$x,y=myproj$y,z=campoProj))->myraster
  crs(myraster)<-CRS("+init=epsg:32632")
  
  projectRaster(myraster,meteoLayer)->SPDE #spde medio per giorno yymmdd
  rm(myraster)  
  rm(campo)

  crop(extend(SPDE,meteoLayer),meteoLayer)->SPDE

  #questa e' la media della variabile su scala logaritmica (meteoLayer gia include spatialLayer)
  meteoLayer+SPDE->finaleLog 

  #Variance of the Gaussian observations 
  inla.emarginal(fun=function(x){(1/exp(x))},inla.out$internal.marginals.hyperpar$`Log precision for the Gaussian observations`)->mean_var_GO

 
  #campo medio di PM10
  exp(finaleLog+0.5*mean_var_GO)-1->pm10
  mask(pm10,italia)->pm10 

  trim(pm10)
    
    
})->listaMediaPM10


if(PTP){
  
  which(is.null(listaMediaPM10))->qualeNULL
  stopifnot(qualeNULL==1) #deve essere solo il primo elemento nella lista
  purrr::compact(listaMediaPM10)->listaMediaPM10
  brick(listaMediaPM10)->mybrick
  
  mybrick[[1]]->primoRaster
  primoRaster[primoRaster> -9999]<-NA
  brick(stack(primoRaster,mybrick))->mybrick
  
  #il fatto di mantenere il primo raster di NA mi serve per mantenere validi gli indici
  #ricavati da BANDA e YYMMDD
  
}else{
  
  brick(listaMediaPM10)->mybrick
  
}

rm(listaMediaPM10)
if(file.exists(nomeBrick)) file.remove(nomeBrick)
writeRaster(mybrick,nomeBrick)

})#FINE PURRR WALK SU MESE
