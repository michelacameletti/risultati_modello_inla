#25 aprile. shapefile semplificato con rmapshaper
rm(list=objects())
library("tidyverse")
library("janitor")
library("INLA")
library("Hmisc")
library("isoband")
library("sf")
library("sp")
library("raster")
source("parametri.R")
source("utility.R")
source("leggi.R")

set.seed(1)
inla.setOption(pardiso.license="~/pardiso/licenza.txt")

calendario<-seq.Date(from=as.Date("2015-01-01",format="%Y-%m-%d"),to=as.Date("2015-02-28",format="%Y-%m-%d"),by="day")
calendario<-data.frame(yymmdd=calendario)

#legge la directory e desume la regione o area su cui fare l'analisi
getArea()->info
info$reg->REGIONI
info$area->AREA

###### QUESTA PARTE SERVE PER FILTRARE LE STAZIONI PER REGIONI, INVECE DI FARE GIRARE IL MODELLO SU TUTTA ITALIA
leggiItalia(regioni=REGIONI,buffSize = 0)->listaItalia #italia ora rappresenta solo REGIONI
listaItalia[["italia"]]->italia
listaItalia[["shRegioni"]]->shRegioni

#estensione
st_bbox(italia)->estensione

#lettura e preparazione dati PM10
leggi(x=nomeFile,soglia=distanzaMinima)->stazioni

#eliminiamo stazioni con troppi NA
contaMancanti<-function(x){
  length(which(is.na(x)))
}

stazioni %>%
  dplyr::group_by(id_centralina) %>%
  summarise(pm10NA=contaMancanti(pm10)) %>%
  ungroup() %>%
  mutate(percMissing=pm10NA/nrow(calendario)*100) %>%
  filter(percMissing>50)->serieIncomplete #piu del 50%

stazioni %>%
  filter(!(id_centralina %in% serieIncomplete$id_centralina))->stazioni

stazioni->sfStazioni

#prendo solo un dato per centralina
sfStazioni[!duplicated(sfStazioni$id_centralina),]->sfStazioni
st_as_sf(sfStazioni,coords = c("x","y"),crs=32632)->sfStazioni
st_intersects(italia,sfStazioni)->righe
sfStazioni[unlist(righe),]->sfStazioni

#elimino le stazioni in stazioni che non hanno id_centralina in sfStazioni
stazioni %>%
  filter(id_centralina %in% sfStazioni$id_centralina)->subDati
rm(stazioni)
######


subDati %>%
  mutate(banda2=banda) %>%
  mutate(settimana=lubridate::week(yymmdd))->subDati


######################## Definizione dataset di training/validation

unique(subDati$id_centralina)->CENTRALINE
length(CENTRALINE)->numeroCentraline

unique(subDati$banda)->GIORNI
length(GIORNI)->n_giorni

#numero di centraline per validation dataset
floor(numeroCentraline*percValidation)->numeroCentralineValidation
#
sample(CENTRALINE,size=numeroCentralineValidation)->idValidation
CENTRALINE[!(CENTRALINE %in% idValidation)]->idTraining

saveRDS(idTraining,"idTraining.RDS")
saveRDS(idValidation,"idValidation.RDS")
# a questo punto: assegno a subDati solo le centraline/dati in idTraining
# creo subValidationDati

subDati %>%
  filter(id_centralina %in% idValidation)->subValidationDati

subDati %>%
  filter(!(id_centralina %in% idValidation))->subTrainingDati

rm(subDati)

######################## Mesh: due tipi di mesh, una creata semplificando gadm con rmapshaper, alternativa 
# quella proposta da Sara, chenon utilizza shapefile

# Entrambe le mesh le creo utilizzando solo subTrainingDati

st_as_sf(subTrainingDati,coords=c("x","y"),crs=32632)->puntiTraining
st_transform(puntiTraining,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->puntiTraining
as.matrix(sf::st_coordinates(puntiTraining))->coordinatePuntiTraining

#Stessa cosa per il validation dataset
st_as_sf(subValidationDati,coords=c("x","y"),crs=32632)->puntiValidation
st_transform(puntiValidation,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->puntiValidation
as.matrix(sf::st_coordinates(puntiValidation))->coordinatePuntiValidation

st_transform(italia,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->italia
as_Spatial(italia)->italiasp


subTrainingDati %>%
  group_by(id_centralina,mm) %>%
  summarise(media_pm10=mean(pm10,na.rm=TRUE)) %>%
  ungroup()->trainingMedia




st_transform(puntiTraining,crs=4326)->puntiTraining
st_transform(italia,crs=4326)->italia
st_coordinates(puntiTraining)[,1]->puntiTraining$lon
st_coordinates(puntiTraining)[,2]->puntiTraining$lat

ggplot()+
  geom_sf(data=italia)+
  geom_sf(data=puntiTraining %>% 
            filter(mm==1) %>% 
            filter(lat >=44.8  & lat<=45.4) %>%
            filter(lon >= 7 & lon<=8.8),aes(fill=pm10),pch=21)+
  scale_y_continuous(limits = c(44.8,45.4))+
  scale_x_continuous(limits=c(7,8.8))+
  scale_fill_viridis_c()+
  facet_wrap(~banda)
