#15 maggio
rm(list=objects())
library("tidyverse")
library("INLA")
library("assertthat")
library("inlabru")
library("sf")
library("sp")
library("ggspatial")
library("raster")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=2,error=recover)


purrr::walk(12:12,.f=function(MESE){
#MESE<-1

#lettura parametri per standardizzare i raster
read_delim("../parametriPerStandardizzareRaster_5giugno2020/rasters_parametri.csv",delim=";",col_names=TRUE)->parametri

#nome del file di output in cui salvare i risultati dell'interpolazione
nomeBrick<-glue::glue("exp_pm10_mese{MESE}.tif")

#che tipo di mappa plottare?
#Quattro opzioni: covariate piu' spde (in scala log), covariate spde (scala esponenziale), 
#solo spde (scala log), solo covariate (scala log)
qualeMappa<-c("completaLog","completaExp","spde","covariate")[2]

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

# if(file.exists("spatialLayer.RDS")){file.remove("spatialLayer.RDS")}
# #lo salviamo su disco in modo di non avere troppi oggetti in memoria
# saveRDS(spatialLayer,"spatialLayer.RDS")
# rm(spatialLayer)

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


  if((qualeGiorno==1) && PTP) return(list(media=NULL,std=NULL))
  #se uso ptp il primo giorno avra' ptp tuttto NA
  #e quindi una stima di pm10 tutta NA...quindi non posso fare il trim!
  #Restituisco NULL (vedi dopo)
  
  print(qualeGiorno)

  #meteoLayer e' un raster di 0 laddove il dem esiste, altrimenti NA
  #uso meteoLayer come base per le somme.
  VARIANZA.FIXED<-0

  #INIZIALIZZO metoLayer con la componente spaziale
  spatialLayer->meteoLayer
  
  #nomiRasters adesso contiene anche ptp.s e tp.s se richiesti
  purrr::walk(nomiRasters,.f=function(nomeCovariata){
    
    print(glue::glue("Covariata {nomeCovariata}"))
    inla.out$summary.fixed[nomeCovariata,]$mean->MEDIA
    
    listaRasters[[nomeCovariata]][[qualeGiorno]]->xx
    extend(xx,estensione)->xx
    crop(xx,meteoLayer)->xx
    
    meteoLayer+(MEDIA*xx)->>meteoLayer
    (inla.out$summary.fixed[nomeCovariata,]$sd^2)->varFixed
    varFixed*(listaRasters[[nomeCovariata]][[qualeGiorno]]^2)+VARIANZA.FIXED->>VARIANZA.FIXED

  })  
  

  #effetto ID_CENTRALINA
  #inla.out$summary.random$id_centralina$mean->ID_CENTRALINA
  
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

  #Ora voglio ottenere il pm10 (passando da scala logaritmica a scala esponenziale)
  #Ho bisogno della varianza della lognormale, che qui otteniamo in modo approssimativo
  #sommando le varianze dei singoli componenti del predittore lineare (in realta' le varianze non sono
  #tra di loro indipendenti)
  
  #spde (sd)
  inla.out$summary.random$i[iset$i.group==qualeGiorno,"sd"]->campo
  inla.mesh.projector(mesh,xlim=c(estensione@xmin,estensione@xmax),ylim=c(estensione@ymin,estensione@ymax),dims = c(1287,999))->myproj
  inla.mesh.project(myproj,campo)->campoProj
  raster(list(x=myproj$x,y=myproj$y,z=campoProj))->myraster
  crs(myraster)<-CRS("+init=epsg:32632")
  
  projectRaster(myraster,meteoLayer)->SD.SPDE
  SD.SPDE^2->VAR.SPDE
  rm(SD.SPDE)
  rm(myraster) 
  rm(campo)
  
  crop(extend(VAR.SPDE,meteoLayer),meteoLayer)->VAR.SPDE
  crop(extend(VARIANZA.FIXED,meteoLayer),meteoLayer)->VARIANZA.FIXED

  #varianza for wday
  #inla.out$summary.random$wday$sd[weekDay]^2->mean_var_WDAY
  #varianza for Gaussian observations: possiamo ignorarla se 
  #vogliamo ignorare l'errore di misurazione
  inla.emarginal(fun=function(x){(1/exp(x))},inla.out$internal.marginals.hyperpar$`Log precision for the Gaussian observations`)->mean_var_GO
  #varianza di fixed effects: x*beta->x^2*Var(beta)
  
  #varianza della log normale (plug-in)
  VAR.SPDE+VARIANZA.FIXED->varLognormale #+mean_var_GO
  
  #campo medio di PM10
  exp(finaleLog+0.5*varLognormale)-1->pm10
  mask(pm10,italia)->pm10 
  trim(pm10)->pm10


  
  exp(2*(finaleLog+varLognormale))-exp(varLognormale+2*finaleLog)->varpm10
  mask(varpm10,italia)->varpm10 #elimino Sardegna
  trim(varpm10)->varpm10
  
  
  if(qualeMappa=="completaExp"){
  
    return(list(media=pm10,std=sqrt(varpm10)))
    
  }else if(qualeMappa=="completaLog"){
    
    return(list(media=finaleLog,std=sqrt(varLognormale)))  
    
  }else if(qualeMappa=="spde"){
    
    return(list(media=SPDE,std=sqrt(VAR.SPDE)))  
    
  }else if(qualeMappa=="covariate"){
    
    return(list(media=meteoLayer,std=sqrt(VARIANZA.FIXED)))  
    
    
  } else{
    
    stop("qualeMappa?")
    
  }#fine if 
  
})->listaRastersPM10


#Nel caso in cui PTP==TRUE, la stima del primo giorno sara' NULL!!!
#Questo non  solo in inverno: se faccio una stima per un mese, comunque
#non avro' il primo giorno (in realta' per un mese diverso fa gennaio questo valore lo potrei ottenere ma sarebbe piu' complicato)
purrr::map(listaRastersPM10,"media")->listaMediaPM10

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
rm(mybrick)


purrr::map(listaRastersPM10,"std")->listaStdPM10

if(PTP){
  
  which(is.null(listaStdPM10))->qualeNULL
  stopifnot(qualeNULL==1) #deve essere solo il primo elemento nella lista
  purrr::compact(listaStdPM10)->listaStdPM10
  brick(listaStdPM10)->mybrick
  
  mybrick[[1]]->primoRaster
  primoRaster[primoRaster> -9999]<-NA
  brick(stack(primoRaster,mybrick))->mybrick
  
  #il fatto di mantenere il primo raster di NA mi serve per mantenere validi gli indici
  #ricavati da BANDA e YYMMDD
  
}else{
  
  brick(listaStdPM10)->mybrick
  
}

rm(listaStdPM10)
if(file.exists(glue::glue("std_{nomeBrick}"))) file.remove(glue::glue("std_{nomeBrick}"))
writeRaster(mybrick,glue::glue("std_{nomeBrick}"))
rm(mybrick)


#elimino la lista
rm(listaRastersPM10)

})#FINE PURRR WALK SU MESE