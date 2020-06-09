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
library("gganimate")
#library("ggspatial")
library("gifski")
library("raster")
library("rasterVis")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=-2,error=recover)

nomeBrick<-"exp_pm10.tif"
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
readRDS("iset.RDS")->iset
readRDS("mesh.RDS")->mesh

#riporto le coordinate in km
mesh$loc[,1]<-mesh$loc[,1]*1000
mesh$loc[,2]<-mesh$loc[,2]*1000 


###### QUESTA PARTE SERVE PER FILTRARE LE STAZIONI PER REGIONI, INVECE DI FARE GIRARE IL MODELLO SU TUTTA ITALIA
leggiItalia(regioni=REGIONI,buffSize = 0)->listaItalia #italia ora rappresenta solo REGIONI
listaItalia[["italia"]]->italia
as_Spatial(italia)->italia #serve per mask
listaItalia[["shRegioni"]]->shRegioni

#estensione
st_bbox(italia)->estensione

#lettura e preparazione dati PM10
readRDS("idTraining.RDS")->idTraining
leggi(x=nomeFile,soglia=distanzaMinima)->stazioni

#numero sequenziale dei giorni (BANDA: valori possibili da 1 a 365)
unique(stazioni$banda)->BANDA

#Giorni: anno mese giorno
unique(stazioni$yymmdd)->YYMMDD

stazioni %>%
  filter(id_centralina %in% idTraining) %>%
  group_by(id_centralina,mm) %>%
  summarise(mpm10=mean(lpm10,na.rm=TRUE)) %>%
  ungroup()->subTraining





#######################
#Ora disegno le mappe
#######################

brick(nomeBrick)->mybrick
#brick(glue::glue("std_{nomeBrick}"))->mybrickStd


stazioni[!duplicated(stazioni$id_centralina),]->sfStazioni
left_join(subTraining,sfStazioni,by=c("id_centralina"="id_centralina"))->sfStazioni
st_as_sf(sfStazioni,coords=c("x","y"),crs=32632)->sfStazioni
st_transform(sfStazioni,crs=crs(mybrick))->sfStazioni
raster::subset(mybrick,subset=1:31)->brickMese
as.data.frame(brickMese,xy=TRUE,na.rm=F)->dfGiorni
dfGiorni %>%
  gather(key="layer",value="pm10",-x,-y) %>%
  separate(layer,into=c("label","banda"),sep="\\.") %>%
  dplyr::select(x,y,banda,pm10)->dfGiorni

dfGiorni %>%
  mutate(banda=as.integer(banda))->dfGiorni

  ggplot(data=dfGiorni  ,aes(x=x,y=y,group=banda))+
    geom_raster(aes(fill=pm10))+
    transition_manual(banda)+
    view_follow()+
    #gg(mesh,edge.color = "#33333322",lwd=0.001)+
    #geom_sf(data=sfStazioni,fill="firebrick",pch=21)+
    scale_fill_viridis_c(na.value = "transparent")+
    #labs(title="Giorno: {currante_frame} gennaio")+
    theme_void()->animazione
  
  

gganimate::animate(animazione,duration=60,width=640,height=768,renderer=gifski_renderer())->animazione
gganimate::anim_save("gennaio.gif",animazione)



