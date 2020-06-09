#15 maggio
rm(list=objects())
library("tidyverse")
library("INLA")
library("RPostgreSQL")
library("rpostgis")
library("inlabru")
library("sf")
library("sp")
library("ggspatial")
library("raster")
library("rasterVis")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=2,error=recover)

#nome del file di output in cui salvare i risultati dell'interpolazione
nomeBrick<-"exp_pm10.tif"

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
nomiSpatial<-c("clc_lwdv","dem")

########################################################################################
#nomiRasters: variabili spazio-temporali (essenzialmente le variabili meteoclimatiche)
########################################################################################

#In nomiRasters riportare i nomi delle variabili meteoclimatiche (senza suffisso s, nel databse le variabili sono
#standardizzate cella per cella, quando invece vogliamo una standardizzazione globale)

#In nomiRasters riportare SOLO tp sia che che si voglia tp che si voglia ptp o entrambe
c("aod550","lnpbl00","lnpbl12","tp")->nomiRasters

#Fissare a TRUE o FALSE le due variabili per includerle o escluderle: in base a queste due variabili
#verra' mantenuta o meno TP ed inclusa o meno PTP. Per PTP usiamo il medesimo raster standardizzato
#di TP: PTP e TP differiscono solo per un giorno, conviene usare il raster standardizzato di TP
TP<-TRUE
PTP<-TRUE

set.seed(1)
inla.setOption(pardiso.license="~/pardiso/licenza.txt")

#calendario<-seq.Date(from=as.Date("2015-01-01",format="%Y-%m-%d"),to=as.Date("2015-02-28",format="%Y-%m-%d"),by="day")
#calendario<-data.frame(yymmdd=calendario)

#legge la directory e desume la regione o area su cui fare l'analisi
getArea()->info
info$reg->REGIONI
info$area->AREA

###### QUESTA PARTE SERVE PER FILTRARE LE STAZIONI PER REGIONI, INVECE DI FARE GIRARE IL MODELLO SU TUTTA ITALIA
leggiItalia(regioni=REGIONI,buffSize = 0)->listaItalia #italia ora rappresenta solo REGIONI
listaItalia[["italia"]]->italia
as_Spatial(italia)->italia #serve per mask
listaItalia[["shRegioni"]]->shRegioni

#estensione
st_bbox(italia)->estensione

#lettura e preparazione dati PM10
leggi(x=nomeFile,soglia=distanzaMinima)->stazioni

#numero sequenziale dei giorni (BANDA: valori possibili da 1 a 365)
unique(stazioni$banda)->BANDA
#Giorni: anno mese giorno
unique(stazioni$yymmdd)->YYMMDD

#ELIMINARE,serve solo per testare il modello
#BANDA[1:6]->BANDA
#YYMMDD[1:6]->YYMMDD

rm(stazioni)

#leggo risultati modello
if(!file.exists("result.RDS")) stop("Non trovo il file result.RDS")

readRDS("result.RDS")->inla.out

#intercetta
inla.out$summary.fixed["Intercept",]$mean->spatialLayer

dbDriver("PostgreSQL")->mydrv
dbConnect(mydrv,user="guido",password="guidofioravanti",port=5432,host="localhost",dbname="asiispra")->mycon

#dem lo estraggo in ogni caso, perche' uso dem come raster base per fare le varie somme su 
#meteoLayer
rpostgis::pgGetRast(mycon,name = c("rgriglia","dem"))->dem
mask(dem,italia)->dem
dem->meteoLayer
meteoLayer[meteoLayer> -9999]<-0
crop(meteoLayer,extent(italia))->meteoLayer

if("dem" %in% nomiSpatial){
  raster::scale(dem)->dem.s
  spatialLayer+(inla.out$summary.fixed["q_dem.s",]$mean*dem.s)->spatialLayer
}

rm(dem)

if("clc_lwdv" %in% nomiSpatial){
  rpostgis::pgGetRast(mycon,name = c("rgriglia","clc_lwdv"))->cl_lwdv
  mask(cl_lwdv,italia)->cl_lwdv
  raster::scale(cl_lwdv)->cl_lwdv.s
  rm(cl_lwdv)
  spatialLayer+(inla.out$summary.fixed["cl_lwdv.s",]$mean*cl_lwdv.s)->spatialLayer
}

#spatialLayer potrebbe essere anche solo l'intercetta del modello, devo verificarlo (is.numeric)
#Se spatialLayer e' un raster, faccio il crop
if(!is.numeric(spatialLayer)) crop(spatialLayer,extent(meteoLayer))->spatialLayer

#lo salviamo su disco in modo di non avere troppi oggetti in memoria
saveRDS(spatialLayer,"spatialLayer.RDS")
rm(spatialLayer)

purrr::map(nomiRasters,.f=function(nomeRaster){
  
  #I file tif gi sono salvati su disco? 
  #Ovviamente la directory non deve avere file .tif non validi (numero di giorniminori di quelli inesame, diversa area geografica), 
  #altrimenti si leggono dati sbagliati per le covariate meteoclimatiche
  if(file.exists(glue::glue("{nomeRaster}.s.tif"))){
    brick(glue::glue("{nomeRaster}.s.tif"))->xx
    #controllo sul numero dei giorni, ma nessun controllo sull'area geografica in esame!
    if(nlayers(xx)!=length(BANDA)) stop("I file .tif hanno un numero di layers diverso dal numero di giorni")
  }else{
    rpostgis::pgGetRast(mycon,name=c("rgriglia",nomeRaster),bands = BANDA)->myrast
    stopifnot(nlayers(myrast)==length(BANDA))
    mask(myrast,italia)->myrast
    as.array(myrast)->valoriRaster
    mean(valoriRaster,na.rm=TRUE)->media
    sd(valoriRaster,na.rm=TRUE)->deviazioneStandard
    rm(valoriRaster)
    ((myrast-media)/deviazioneStandard)->xx
    rm(myrast)
    crop(extend(xx,meteoLayer),meteoLayer)->xx #per non avere errori, funziona se spatialLayer non contiene solo l'intercetta
    writeRaster(xx,glue::glue("{nomeRaster}.s.tif"),overwrite=TRUE)
  }
  
  return(xx)
  
})->listaRasters

names(listaRasters)<-nomiRasters



#se PTP==TRUE vuol dire che devo prendere TP e trasformarla in PTP
if(PTP){
  
  #se voglio ptp come "nomiRasters" deve elencare "tp". Poi partendo dalla pioggia
  #ricostruisco ptp
  if(!("tp" %in% nomiRasters)) stop("tp non trovato in nomiRasters")
  
  listaRasters[["tp"]]->pioggia
  nlayers(pioggia)->numeroLivelli
  pioggia[[numeroLivelli]]->ultimoRaster
  ultimoRaster[ultimoRaster> -9999]<-NA
  stack(ultimoRaster,pioggia[[1:(numeroLivelli-1)]])->ptp
  brick(ptp)->ptp
  listaRasters$ptp<-ptp
  rm(ptp)
  rm(pioggia)
  rm(ultimoRaster)
  
}

#SE TP == FALSE allora vuole dire che l'ho presa solo per creare ptp, la elimino da listaRasters
if(!TP){listaRasters$tp<-NULL}

#La mesh mi serve per proiettare il latent field
readRDS("iset.RDS")->iset
readRDS("mesh.RDS")->mesh

#riporto le coordinate in km
mesh$loc[,1]<-mesh$loc[,1]*1000
mesh$loc[,2]<-mesh$loc[,2]*1000 

tryCatch({
  RPushbullet::pbPost(type="note",title=glue::glue("{AREA}"),body="Ho iniziato interpolazione")
},error=function(e){
  glue::glue("{AREA}: ho iniziato interpolazione!")
})

#
purrr::map(1:length(YYMMDD),.f=function(qualeGiorno){
 
  if((qualeGiorno==1) && PTP) return(list(media=NULL,std=NULL))
  #se uso ptp il primo giorno avra' ptp tuttto NA
  #e quindi una stima di pm10 tutta NA...quindi non posso fare il trim!
  #Restituisco NULL (vedi dopo)
  
  print(qualeGiorno)
  
  YYMMDD[qualeGiorno]->yymmdd
  
  lubridate::yday(yymmdd)->banda
  lubridate::wday(yymmdd)->weekDay
  
  #meteoLayer e' un raster di 0 laddove il dem esiste, altrimenti NA
  #uso meteoLayer come base per le somme.
  VARIANZA.FIXED<-0
  
  try({
    meteoLayer+(inla.out$summary.fixed["aod550.s",]$mean)*(listaRasters[["aod550"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["aod550.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["aod550"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })
  
  try({
    meteoLayer+(inla.out$summary.fixed["tp.s",]$mean*listaRasters[["tp"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["tp.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["tp"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })
  
  try({
    meteoLayer+(inla.out$summary.fixed["ptp.s",]$mean*listaRasters[["ptp"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["ptp.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["ptp"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })
  
  try({
    meteoLayer+(inla.out$summary.fixed["log.pbl00.s",]$mean*listaRasters[["lnpbl00"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["log.pbl00.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["lnpbl00"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })
  
  try({
    meteoLayer+(inla.out$summary.fixed["log.pbl12.s",]$mean*listaRasters[["lnpbl12"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["log.pbl12.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["lnpbl12"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })  
  
  try({
    meteoLayer+(inla.out$summary.fixed["t2m.s",]$mean*listaRasters[["t2m"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["t2m.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["t2m"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })  
  
  
  try({
    meteoLayer+(inla.out$summary.fixed["wspeed.s",]$mean*listaRasters[["wspeed"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["wspeed.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["wspeed"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })   
  
  try({
    meteoLayer+(inla.out$summary.fixed["sp.s",]$mean*listaRasters[["sp"]][[qualeGiorno]])->meteoLayer
    (inla.out$summary.fixed["sp.s",]$sd^2)->varFixed
    varFixed*(listaRasters[["sp"]][[qualeGiorno]]^2)+VARIANZA.FIXED->VARIANZA.FIXED
    rm(varFixed)
  })     
  
  
  #effetto per il giorno weekDati (da 1 a 7)
  inla.out$summary.random$wday[weekDay,]$mean->WEEKDAY
  
  #spde (media)
  inla.out$summary.random$i[iset$i.group==qualeGiorno,"mean"]->campo
  inla.mesh.projector(mesh,xlim=c(estensione["xmin"],estensione["xmax"]),ylim=c(estensione["ymin"],estensione["ymax"]),dims = c(1287,999))->myproj
  inla.mesh.project(myproj,campo)->campoProj
  raster(list(x=myproj$x,y=myproj$y,z=campoProj))->myraster
  crs(myraster)<-CRS("+init=epsg:32632")
  
  
  projectRaster(myraster,meteoLayer)->SPDE #spde medio per giorno yymmdd
  rm(myraster)  
  rm(campo)

  readRDS("spatialLayer.RDS")->spatialLayer
  
  crop(extend(SPDE,meteoLayer),meteoLayer)->SPDE

  #questa e' la media della variabile su scala logaritmica
  spatialLayer+meteoLayer+SPDE+WEEKDAY->finaleLog 

  #Ora voglio ottenere il pm10 (passando da scala logaritmica a scala esponenziale)
  #Ho bisogno della varianza della lognormale, che qui otteniamo in modo approssimativo
  #sommando le varianze dei singoli componenti del predittore lineare (in realta' le varianze non sono
  #tra di loro indipendenti)
  
  #spde (sd)
  inla.out$summary.random$i[iset$i.group==qualeGiorno,"sd"]->campo
  inla.mesh.projector(mesh,xlim=c(estensione["xmin"],estensione["xmax"]),ylim=c(estensione["ymin"],estensione["ymax"]),dims = c(1287,999))->myproj
  inla.mesh.project(myproj,campo)->campoProj
  raster(list(x=myproj$x,y=myproj$y,z=campoProj))->myraster
  crs(myraster)<-CRS("+init=epsg:32632")
  
  projectRaster(myraster,meteoLayer)->SD.SPDE
  SD.SPDE^2->VAR.SPDE
  rm(SD.SPDE)
  rm(myraster) 

  #varianza for wday
  inla.out$summary.random$wday$sd[weekDay]^2->mean_var_WDAY
  #varianza for Gaussian observations: possiamo ignorarla se 
  #vogliamo ignorare l'errore di misurazione
  inla.emarginal(fun=function(x){(1/exp(x))},inla.out$internal.marginals.hyperpar$`Log precision for the Gaussian observations`)->mean_var_GO
  #varianza di fixed effects: x*beta->x^2*Var(beta)
  
  crop(extend(VAR.SPDE,meteoLayer),meteoLayer)->VAR.SPDE
  crop(extend(VARIANZA.FIXED,meteoLayer),meteoLayer)->VARIANZA.FIXED
  
  
  #varianza della log normale (plug-in)
  mean_var_WDAY+VAR.SPDE+VARIANZA.FIXED->varLognormale #+mean_var_GO
  
  #campo medio di PM10
  exp(finaleLog+0.5*varLognormale)-1->pm10
  mask(pm10,italia)->pm10 #elimino Sardegna
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

dbDisconnect(mycon)

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
