#15 maggio
rm(list=objects())
library("tidyverse")
library("INLA")
library("RPostgreSQL")
library("rpostgis")
library("inlabru")
library("rosm")
library("sf")
library("sp")
library("ggspatial")
library("raster")
library("furrr")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=2,error=recover)

plan(multicore)

furrr::future_map(5:12,.f=function(MESE){

nomeBrick<-glue::glue("exp_pm10_mese{MESE}.tif")
nomeBrickPDF<-stringr::str_replace(nomeBrick,"tif","pdf")
nomeFileMediaOutput<-paste0("media_",nomeBrickPDF)
nomeFileDailyOutput<-paste0("daily_",nomeBrickPDF)


#calendario<-seq.Date(from=as.Date("2015-01-01",format="%Y-%m-%d"),to=as.Date("2015-02-28",format="%Y-%m-%d"),by="day")
#calendario<-data.frame(yymmdd=calendario)

#legge la directory e desume la regione o area su cui fare l'analisi
getArea()->info
info$reg->REGIONI
info$area->AREA


#La mesh
#readRDS(glue::glue("iset{MESE}.RDS"))->iset
readRDS("mesh.RDS")->mesh

#riporto le coordinate in km
mesh$loc[,1]<-mesh$loc[,1]*1000
mesh$loc[,2]<-mesh$loc[,2]*1000 


###### QUESTA PARTE SERVE PER FILTRARE LE STAZIONI PER REGIONI, INVECE DI FARE GIRARE IL MODELLO SU TUTTA ITALIA
leggiItalia(regioni=REGIONI,buffSize = 0)->listaItalia #italia ora rappresenta solo REGIONI
listaItalia[["italia"]]->italia
as_Spatial(italia)->italia #serve per mask
listaItalia[["shRegioni"]]->shRegioni

#lettura e preparazione dati PM10
giornoI<-as.Date(glue::glue("2015-{MESE}-01"),format="%Y-%m-%d")
giornoF<-giornoI+(lubridate::days_in_month(giornoI)-1)

if(MESE!=1) giornoI<-giornoI-2
#Tramite YYMMDD e lubridate vogliamo ricavare quale indice (tra 1 e 365) assume ogni giorno dell'anno.
YYMMDD<-seq.Date(from=giornoI,to=giornoF,by="day")


#######################

brick(nomeBrick)->mybrick


###medie mensili
cairo_pdf(nomeFileMediaOutput,width=8,height=12,onefile=TRUE)
purrr::walk(MESE,.f=function(mm){

  which(lubridate::month(YYMMDD)==mm)->quali
  mean(mybrick[[quali]],na.rm=TRUE)->media

  ggplot()+
    layer_spatial(data=media)+
    #gg(mesh,edge.color = "#33333322",lwd=0.001)+
    #geom_sf(data=sfStazioni,fill="firebrick",pch=21)+
    scale_fill_viridis_c(na.value = "transparent")+
    labs(main=glue::glue("Mese: {mm}"))+
    theme_void()->grafico
    print(grafico)

  
})
dev.off()



cairo_pdf(nomeFileDailyOutput,width=8,height=12,onefile=TRUE)
which(lubridate::month(YYMMDD)==MESE)->quali
purrr::walk(quali,.f=function(giorno){
  
   
  mybrick[[giorno]]->rasterGiorno

try({
  ggplot()+
    layer_spatial(data=rasterGiorno)+
    #gg(mesh,edge.color = "#33333322",lwd=0.001)+
    #geom_sf(data=sfStazioni,fill="firebrick",pch=21)+
    scale_fill_viridis_c(na.value = "transparent")+
    labs(main=glue::glue("Giorno: {giorno}"))+
    theme_void()->grafico
    print(grafico)
})
  
})
dev.off()



})# fine purrr::walk su MESE
