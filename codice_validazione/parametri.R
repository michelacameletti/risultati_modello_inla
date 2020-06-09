#nome del file di input
"../archivio/pm10_analisi_28marzo2020_standardizzazioneGlobale.csv"->>nomeFile

#Parametri piu importanti da fissare
#Salvare output di inla?
SAVE_OUTPUT<<-FALSE

#Mese (integer)
MESE<<-c(1,2,3,4,5,6,7,8,9,10,11,12)[1]
MESE<-NULL

#numero dei giorni (serve per spde/control.group)
if(!is.null(MESE)){
  n_giorni<<-c(31,28,31,30,31,30,31,31,30,31,30,31)[MESE]
  if(MESE!=1){n_giorni<<-n_giorni+2} #2 giorni del mese precedente
}

#mas.daily.na: parametro da passare alla funzione "leggi"
#Il numero massimo di NA ammessi in un mese
MAX.DAILY.NA<<-19 #< 20

#Se leggo lo shapefile dell'Italia intera, includere la Sardegna?
SARDEGNA<<-TRUE

#eliminare le stazioni appartenenti a una stessa regione che distano meno di distanzaMinima km?
distanzaMinima<<-1000

#percentuale centraline per validation dataset
percValidation<-0.0

#Altri parametri
SOGLIA<<-1200 #INUTILIZZATO
STAGIONE<<-1 #COME SOPRA

###########################
#Parametri per RMarkdown
###########################

#NUMERO DELLE STAZIONI CASUALI DI CUI FARE I GRAFICI
SIZECAMPIONE<<-10

#Giorni campione per variogrammi
SIZECAMPIONEGIORNI<<-10

