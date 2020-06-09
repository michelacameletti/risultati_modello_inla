library("vroom")
library("tidyverse")

#restituisce info sulla directory
getArea<-function(){
  
  getwd()->nomeDir
  
  if(grepl("[Ss]ardegna",nomeDir)){
    REGIONI<-c("Sardegna")
    AREA<-REGIONI
  }else if(grepl("padana",getwd())){
    REGIONI<-c("Veneto","Lombardia","Piemonte","Emilia-Romagna")  
    AREA<-"Pianura Padana"
  }else if(grepl("centro",getwd())){
    REGIONI<-c("Lazio","Campania")  
    AREA<-"Centro"
  }else if(grepl("italia",getwd())){
    REGIONI<-c("tutte")  
    AREA<-"Italia"
  }
  
  return(list(reg=REGIONI,area=AREA))
  
}#fine getArea

#legge shapefile italia e filtra in base alle regioni

"../archivio/gadm36_ITA_1_sf_originale.rds"->GADM
leggiItalia<-function(regioni=NULL,sardegna=FALSE,nomeFile=GADM,buffSize=0){
  
  readRDS(nomeFile)->italia
  
  if(!is.null(regioni)) { 
    
    #se sardegna==FALSE la elimino da Italia
    if((regioni=="tutte") && !sardegna){
      
      filter(italia,NAME_1 != "Sardegna")->italia    
      
    #se regioni e' uguale a una regione specifica, allora prendo quella regione  
    }else if((regioni!="tutte")){    

      filter(italia,NAME_1 %in% regioni)->italia       
      
    }

  }
  
  st_transform(italia,crs=32632)->italia
  italia->shRegioni #serve soloperlamesh
  st_union(italia)->italia
  if(!is.null(buffSize)) {
    st_buffer(italia,dist=buffSize)->italia
    st_buffer(shRegioni,dist=buffSize)->shRegioni
  }
  
  return(list("italia"=italia,"shRegioni"=shRegioni))
  
}#fine leggiItalia



#x: nome del file di input
#soglia: le stazioni con distanza reciproca inferiore a "soglia" vengono eliminate
#max.daily.na: massimo numero di giorniNA tollerati in un mese
leggi<-function(x,mese,max.daily.na,soglia){
  
    vroom(x,delim=";",col_names=TRUE)->stazioni
  
    ###################################################################
    #soglia: elimino stazioni con distanza reciproca <= soglia
    ###################################################################
  
    if(!missing(soglia) && is.numeric(soglia)){
      
      vroom("../archivio/distanzeStazioniStessaRegione.csv",delim=";",col_names=TRUE)->dfDis
      
      dfDis %>% filter(distanza<=soglia)->daEliminare

      stazioni %>% filter(!(id_centralina %in% daEliminare$codice))->stazioni
      print("------->>> ATTENZIONE: i dati di input sono stati filtrati rispetto alla distanza (parametro soglia in leggi)!")
       
    }#fine if su distanza
  
    ###################################################################
    #qui aggiusto alcune variabili e creo lpm10 (il logaritmo del pm10)
    ###################################################################
  
    stazioni %>%
      mutate(lpm10=log(pm10.orig+1)) %>%
      mutate(d_a1=ifelse(d_a1>35000,35000,d_a1)) %>%
      mutate(mm=as.integer(lubridate::month(yymmdd))) %>%
      mutate(dust=as.integer(dust)) %>%
      mutate(Intercept=1)->subDati

    #Filtro su mese
    if(!is.null(mese) && length(mese)==1 && (mese %in% seq(1:12))){
      
      unique(subDati[subDati$mm==mese,]$banda)->BANDA
      min(BANDA)->banda0
      max(BANDA)->bandaLast
      
      #voglio recuperare i primi due giorni del mese precedente
      if(banda0!=1){(banda0-2)->banda0}
      
      #filtra per mese, utilizzando banda (sequenza da 1 a 365)
      #correggi banda inmodo che inizi sempr da 1 come viene richiesto da INLA
      subDati %>%
        filter(banda %in% seq(banda0,bandaLast,1))%>%
        mutate(banda=(banda-banda0+1))->subDati

    }else{ #fine controllo su mese
      print("------->>> ATTENZIONE: i dati di input non sono stati filtrati per mese, elaboro tutto l'anno!")
    }  
   
    rm(stazioni)
    ###################################################################
    #trasformo wday in una variabile qualitativa: feriale/festivo
    ###################################################################
    
    FESTIVI<-as.Date(c( "2015-01-01","2015-01-06","2015-04-25","2015-05-01",
                        "2015-02-14","2015-02-15","2015-02-17","2015-04-05",
                        "2015-04-06","2015-06-02","2015-08-15","2015-11-01",
                        "2015-11-02","2015-12-08","2015-12-24","2015-12-25",
                        "2015-12-26","2015-12-31"))
    
if(1==0){    
    #sabato e domenica->festivo (1): sabato per lubridate e' 7, domenica e' 1
    subDati %>%
      mutate(wday=lubridate::wday(yymmdd)) %>%
      mutate(wday=case_when(wday==7 | wday==1 ~1,
                            TRUE~0)) %>%
      mutate(wday=ifelse(yymmdd %in% FESTIVI,1,wday)) %>%
      mutate(wday=as.integer(wday))->subDati
}#su 1==0
    
    ###################################################################
    #il file pm10_metadati contiene:
    # -info su st_tipo (tipo di centralina: urbana, suburbana)
    # -numero di giorni mancanti in un mese: questa info ci serve per lavorare solo su
    #serie complete o abbastanza complete
    ###################################################################
    
    #max.daily.na: se non e' null, eliminiamo le stazioni con numero di giorni mancanti
    #superiori a max.daily.na in almeno un mese (cioe' voglio tenere solo le centraline che rispetto
    #a max.daily.na hanno tutti e i 12 mesi validi)
    if(!missing(max.daily.na) && is.numeric(max.daily.na)){
      
      read_delim("../archivio/pm10_metadati.csv",delim=";",col_names = TRUE,col_types = cols(mm=col_integer()))->pm10_meta
      
      pm10_meta %>%
        filter(giorniNA<=max.daily.na) %>%
        group_by(id_centralina) %>%
        summarise(numeroMesiValidi=n()) %>%
        ungroup() %>%     
        filter(numeroMesiValidi==12)->stazioniValide
      
      #tengo solo le stazioni che rispetto a max.daily.na hanno tutti e i 12 mesi validi
      subDati %>%
        filter(id_centralina %in% stazioniValide$id_centralina)->subDati
      

    }
    
    #non c'e bisogno di restituire tutte le variabili
    subDati %>%
      dplyr::select(yymmdd,mm,banda,id_centralina,x,y,lpm10,t2m.s,sp.s,
                    log.pbl00.s,log.pbl12.s,tp.s,ptp.s,q_dem.s,d_a1.s,
                    nh3_diff.s,cl_shrb.s,i_surface.s,aod550.s,Intercept,
                    dust)
    
    
    
    
}#fine funzione leggi    
