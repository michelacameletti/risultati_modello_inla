#nome del file di input
"../archivio/pm10_analisi_28marzo2020_standardizzazioneGlobale.csv"->>nomeFile

#Parametri piu importanti da fissare
#Salvare output di inla?
SAVE_OUTPUT<<-TRUE

#Utilizzare tutte le stazioni disponibili elencate nel file pm10_metadati per far girare il modello (senza
#distinguere tra training e validation) o filtrare le stazioni in training e in validation secondo la stratificazione
#identificata da Sara e basata su tre diversi run del modello sui 12 mesi? In entrambi i casi la mesh viene creata
#utilizzando tuute le stazioni del file pm10_metadati (410 in base a MAX.DAILY.NA<-19) ovvero utilizzando sia
#le stazioni di training che quelle di validazione
FAI.GIRARE.IL.MODELLO.CON.TUTTE.LE.STAZIONI<<-TRUE

if(FAI.GIRARE.IL.MODELLO.CON.TUTTE.LE.STAZIONI){
  NUMERO.RUNS<<-1 #il modello gira una sola volta su tutti e i 12 mesi
}else{
  NUMERO.RUNS<<-3  #il modello gira 3 volte sui 12 mesi, ogni volta cambia il dataset di training e di validazione
}


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

