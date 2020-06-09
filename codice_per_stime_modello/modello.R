#4giugno: il modello utilizza il dataset training e validazione identificato da Sara per
#a cross validation.
#Implementiamo il caso in cui il file di Sara non vada letto e il modello vada fatto girare una sola
#volta su tutti i mesi su tutte le stazioni per le sole covariate prescelte (il modello era gia'
#stato fatto girare su tutti i mesi per fare i ridge plots e capire quali covariate ci interessano.
#In quel caso si erano tenute le stazioni con al piu' 15 NA per ogni mese. Adesso, che sappiamo quali covariate vogliamo tenere,
#facciamo rigirare il modello su tutti i mesi e su tutte le stazioni per ottenere le stime definitive delle covariate.
#Adesso pero' si ammettono stazioni con al piu' 19 giorni mancanti per i 12 mesi, che porta a identificare un set di 410 stazioni)
rm(list=objects())
library("tidyverse")
library("janitor")
library("INLA")
library("sf")
library("sp")
library("raster")
library("assertthat")
source("parametri.R")
source("utility.R")
source("leggi.R")
options(warn=-2)

set.seed(1)
inla.setOption(pardiso.license="~/pardiso/licenza.txt")

#legge la directory e desume la regione o area su cui fare l'analisi
getArea()->info
info$reg->REGIONI
info$area->AREA

###### QUESTA PARTE SERVE PER FILTRARE LE STAZIONI PER REGIONI, INVECE DI FARE GIRARE IL MODELLO SU TUTTA ITALIA
# Il filtro avviene mediante st_intersects tra lo shapefile dell'Italia e i punti stazione
#Se sardegna==TRUE lo shapefile utilizzato per filtrare le stazioni contiene anche la Sardegna
leggiItalia(regioni=REGIONI,sardegna=SARDEGNA,buffSize = 25000)->listaItalia #italia ora rappresenta solo REGIONI
listaItalia[["italia"]]->italia
listaItalia[["shRegioni"]]->shRegioni

#estensione
st_bbox(italia)->estensione


####Priors:
list(theta1=list(prior="pc.prec",param=c(0.2,0.2)),theta2=list(prior="pc.cor1",param=c(0.6,0.9)))->rho_hyper
list(theta = list(prior="pc.prec", param=c(1,0.1)))->prec_hyper #all'inizio era 0.01
list(prior="pc.cor1",param=c(0.8,0.318))->theta_hyper
####

######################## FORMULA MODELLO: la parte random (spde, etc) va aggiunta prima del comando inla()
as.formula(lpm10~Intercept+dust+aod550.s+log.pbl00.s+log.pbl12.s+sp.s+t2m.s+tp.s+ptp.s+q_dem.s+i_surface.s+d_a1.s-1)->myformula
terms(myformula)->termini
attr(termini,which="term.labels")->VARIABILI
########################

#Tre cicli corrispondenti a tre diversi set di training e validazione, set che NONmutano di mese in mese e che sono stati
#gia' fissati a priori stratificando rispetto alla tipologia della stazione (urban, suburban, altro)
purrr::walk(1:NUMERO.RUNS,.f=function(qualeTrial){
  
#leggo file con info su training e validation (selezione fatta da Sara). Questo file elenca solo le 410 stazioni
#che soddisfano il criterio di completezza delle serie (sono state prese le serie che hanno meno di 20 giorni NA (<20))
#La lettura dello shapefile per intersecare i punti stazione con l'Italia ha un buffer scelto appositamente per acchiappare
#proprio queste 410 stazioni..hard cording! Quindi: se si cambiasseroi criteri di completezza bisognerebbe rigenerare
#il file che qui di seguito si legge ed essere sicuro che l'intersezione tra i punti stazione e l'Italia contenga le
#centraline elencate in questo file
read_delim("../archivio/trainingValidation.csv",delim=";",col_names=TRUE) %>%
    filter(trial==qualeTrial)->infoTrainingValidation
  
purrr::walk(5:12,.f=function(MESE){

    #numero dei giorni (serve per spde/control.group)
    n_giorni<<-c(31,28,31,30,31,30,31,31,30,31,30,31)[MESE]
    if(MESE!=1){n_giorni<-n_giorni+2} #2 giorni del mese precedente
      
      
    #lettura e preparazione dati PM10
    leggi(x=nomeFile,mese=MESE,max.daily.na=MAX.DAILY.NA,soglia=NULL)->stazioni

    #associo a stazioni il tipo di centralina (info che vogliamo mantenere nei risultati della validazione)
    left_join(stazioni, infoTrainingValidation[!duplicated(infoTrainingValidation$id_centralina),] %>% dplyr::select(id_centralina,tipo_new))->stazioni

    #prendo solo un dato per centralina
    #sfStazioni contiene tutte le centraline che soddisfano i criteri di completezza mensile (sia training che validation)
    
    #Utilizzo sfStazioni per costruire la mesh (cioe' la mesh la costruisco utilizzando anche i punti per la validazione)
    stazioni->sfStazioni
    sfStazioni[!duplicated(sfStazioni$id_centralina),]->sfStazioni
    st_as_sf(sfStazioni,coords = c("x","y"),crs=32632)->sfStazioni
    
    #Interseco con Italia: volendo prendere solo un sottoinsieme delle stazioni
    st_intersects(italia,sfStazioni)->righe
    sfStazioni[unlist(righe),]->sfStazioni
    
    #ho esattamente le 410 stazioni scelte secondo i criteri di completezza ede elencate in infoTrainingValidation?
    assert_that(nrow(sfStazioni)==nrow(infoTrainingValidation))
    
    if(REGIONI=="tutte" && SARDEGNA){
      
      shRegioni[shRegioni$NAME_1=="Sardegna",]->shSardegna
      st_intersection(shSardegna,sfStazioni)->sfStazioniSardegna
      sfStazioniSardegna$id_centralina->CENTRALINE_SARDEGNA
      
    }#fine if su REGIONI && SARDEGNA
    
    
    #elimino le stazioni in stazioni che non hanno id_centralina in sfStazioni (ovvero le stazioni
    #che non intersecano lo shapefile "italia", dove italia puo' essere l'intera penisola con o senza Sardegna,
    #oppure una regione specifica)
    
    #Questa operazione ha senso quando vogliamo estrarre i dati per una zona dell'Italia, una regione
    #o un insieme di regioni
    stazioni %>%
      filter(id_centralina %in% sfStazioni$id_centralina)->subDati
    rm(stazioni) 
    ######
    
    ######################## Definizione dataset di training/validation
    if(!FAI.GIRARE.IL.MODELLO.CON.TUTTE.LE.STAZIONI){
      infoTrainingValidation[infoTrainingValidation$training==1,]$id_centralina->idTraining
      infoTrainingValidation[infoTrainingValidation$training==0,]$id_centralina->idValidation    
    }else{
      infoTrainingValidation$id_centralina->idTraining
      assert_that(length(idTraining)==410)
      infoTrainingValidation[!(infoTrainingValidation$id_centralina %in% idTraining),]$id_centralina->idValidation
      assert_that(length(idValidation)==0) #deve essere vuoto!
    }  
    assert_that(length(idTraining)>0)
    
    saveRDS(idTraining,glue::glue("idTraining{qualeTrial}.RDS"))
    
    #assegno a subTrainingDati solo le centraline/dati in idTraining
    subDati %>%
      filter(id_centralina %in% idTraining)->subTrainingDati
    
    st_as_sf(subTrainingDati,coords=c("x","y"),crs=32632)->puntiTraining
    st_transform(puntiTraining,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->puntiTraining
    as.matrix(sf::st_coordinates(puntiTraining))->coordinatePuntiTraining
    #st_write(puntiTraining,"stazioniTraining","stazioniTraining",driver="ESRI Shapefile",append=FALSE)
    
    
    if(length(idValidation)){
      
      saveRDS(idValidation,glue::glue("idValidation{qualeTrial}.RDS"))
      
      subDati %>%
        filter(id_centralina %in% idValidation)->subValidationDati
      
      st_as_sf(subValidationDati,coords=c("x","y"),crs=32632)->puntiValidation
      st_transform(puntiValidation,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->puntiValidation
      as.matrix(sf::st_coordinates(puntiValidation))->coordinatePuntiValidation
      #st_write(puntiValidation,"stazioniValidation","stazioniValidation",driver="ESRI Shapefile",append=FALSE)
      
    }#fine if su validation dataset
    
    rm(subDati)
    
    ########################
    #Mesh    
    ########################

    st_transform(italia,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->italia
    as_Spatial(italia)->italiasp
    
    #importante trasformare in km sfStazioni: altrimenti non posso usare convex=90 (dovrei indicare in metri)
    st_transform(sfStazioni,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->sfStazioni
    
    #SE sto considerando anche la Sardegna, devo costruire la mesh utilizzando due set di dati
    if(exists("CENTRALINE_SARDEGNA")){
      
      as_Spatial(sfStazioni %>% filter(!(id_centralina %in% CENTRALINE_SARDEGNA)))->puntiTerraferma
      as_Spatial(sfStazioni %>% filter((id_centralina %in% CENTRALINE_SARDEGNA)))->puntiIsola

      inla.nonconvex.hull(points =  puntiTerraferma,convex = 90)->terraferma
      inla.nonconvex.hull(points = puntiIsola,convex=90)->isola 
      mesh<-inla.mesh.2d(boundary =list(list(terraferma,isola)), max.edge = c(30,150),cutoff=5,offset=c(10),min.angle = 25)

    }else{
      
      inla.nonconvex.hull(points = coordinatePuntiMesh)->pts
      mesh<-inla.mesh.2d(boundary = pts, max.edge = c(30,100),cutoff=5,offset=c(5))
      
    }#fine if
    
    
    # Il sistema di coordinate va trasformato da epsg 32632 in metri a km
    st_transform(shRegioni,crs=CRS("+proj=utm +zone=32 +datum=WGS84 +units=km +no_defs"))->shRegioni
    
    png(glue::glue("./images/mesh{qualeTrial}.png"),width=502,height=502)
    plot(mesh)
    plot(st_geometry(shRegioni),add=TRUE,lwd=2) #shRegioni mi serve solo per disegnare ogni regione con i suoi confini
    plot(st_geometry(puntiTraining),add=TRUE,bg="red",pch=21)
    if(length(idValidation)){plot(st_geometry(puntiValidation),add=TRUE,bg="green",pch=21)}
    dev.off()
    saveRDS(mesh,"mesh.RDS")

    
    rm(shRegioni)
    
    ########################
    
    ######################## SPDE: Priors & more
    
    #spde
    inla.spde2.pcmatern(mesh=mesh,alpha=2,constr=FALSE,prior.range = c(150,0.8),prior.sigma = c(0.8,0.2))->spde
    saveRDS(spde,"spde.RDS")
    
    inla.spde.make.index(name="i",n.spde=spde$n.spde,n.group = n_giorni)->iset
    saveRDS(iset,glue::glue("iset{MESE}.RDS"))
  
    #training
    inla.spde.make.A(mesh=mesh,loc=coordinatePuntiTraining,group =subTrainingDati$banda,n.spde=spde$n.spde,n.group =n_giorni )->A.training
    inla.stack(data=list(lpm10=subTrainingDati$lpm10),A=list(A.training,1),effects=list(iset,subTrainingDati[c("id_centralina",attr(termini,"term.labels"))]),tag="training")->stack.training
    saveRDS(stack.training,"stack.training.RDS")
    
    #validation
    if(length(idValidation)){
      inla.spde.make.A(mesh=mesh,loc=coordinatePuntiValidation,group =subValidationDati$banda,n.spde=spde$n.spde,n.group =n_giorni )->A.validation
      inla.stack(data=list(lpm10=NA),A=list(A.validation,1),effects=list(iset,subValidationDati[c("id_centralina",attr(termini,"term.labels"))]),tag="validation")->stack.validation
      saveRDS(stack.validation,"stack.validation.RDS")
    }
    
    
    #creo stack
    if(length(idValidation)){
      inla.stack(stack.training,stack.validation)->mystack
    }else{
      stack.training->mystack
    }
    
    saveRDS(mystack,"mystack.RDS")

    ########################
    update(myformula,.~.+f(id_centralina,model="iid")+f(i,model=spde,group = i.group,control.group = list(model="ar1",hyper=list(theta=theta_hyper))))->myformula
    
    ######################## Inizio INLA
    tryCatch({
      RPushbullet::pbPost(type="note",title=glue::glue("{AREA}-{MESE}"),body="Ho iniziato")
    },error=function(e){
      glue::glue("{AREA}: ho iniziato!")
    })
    
    ######################## INLA stanca
    
    inla(myformula,
         data=inla.stack.data(mystack,spde=spde),
         family ="gaussian",
         verbose=TRUE,
         control.compute = list(openmp.strategy="pardiso.parallel",cpo=TRUE,waic=TRUE,dic=TRUE,config=TRUE),
         control.fixed = list(prec.intercept = 0.001, prec=1,mean.intercept=0),
         control.predictor =list(A=inla.stack.A(mystack),compute=TRUE) )->>inla.out
if(1==0){
    ########################
    # Risultati per validazione modello  
    ###############################
    mystack$data$index$training->righeTraining
    
    #valori fittati su dataset di training
    inla.out$summary.fitted.values$mean[righeTraining]->subTrainingDati$lfitted
    inla.out$summary.fitted.values$sd[righeTraining]->subTrainingDati$lfitted.sd
    #numero del trial
    subTrainingDati$trial<-qualeTrial
    #mese del trial: non basta mm. trial.month ==MESE non solo per le stazioni che hanno mese di calendario
    # uguale a MESE. trial.month=MESE viene assegnato anche ai due giorni precedenti al 1 giorno di MESE
    #Quindi: la colonna mm riguarda il mese del calendario, trial.month riguarda il mese del calendario (ad esempio marzo)
    #e i due giorni precedenti al primo marzo (27 e 28 febbraio che avranno in trial.month marzo)
    subTrainingDati$trial.month<-MESE
    
    #stage: training o validation
    subTrainingDati$stage<-"training"
    
    #Stesse info per la validazione:
    subValidationDati$trial<-qualeTrial
    
    #valori fittati su dataset di validazione
    mystack$data$index$validation->righeValidation
    inla.out$summary.fitted.values$mean[righeValidation]->subValidationDati$lfitted
    inla.out$summary.fitted.values$sd[righeValidation]->subValidationDati$lfitted.sd
     
    #stage: training o validation
    subValidationDati$stage<-"validation"
    
    #trial.month
    subValidationDati$trial.month<-MESE
    
    bind_rows(subTrainingDati %>% dplyr::select(yymmdd,id_centralina,tipo_new,x,y,q_dem.s,trial,trial.month,stage,lpm10,lfitted,lfitted.sd),
              subValidationDati %>% dplyr::select(yymmdd,id_centralina,tipo_new,x,y,q_dem.s,trial,trial.month,stage,lpm10,lfitted,lfitted.sd))->daScrivere
    
    ifelse(file.exists("risultatiValidazione.csv"),FALSE,TRUE)->NOMI.COLONNE
    write_delim(daScrivere,"risultatiValidazione.csv",delim=";",col_names=NOMI.COLONNE,append=TRUE)
}#fine 1==0 Risultati per validazione modello    
    
########################
# Effetti covariate: questa parte di codice e' stata utilizzata per valutare gli effetti delle covariate 
# nel corso dei mesi e decidere quali covariate tenere o meno. I risultati tra if(1==0) sono stati salvati
# per tutti i mesi, utilizzando tutte le stazioni disponibili e lastessa mesh nel corso dei mesi. I risultati
#sono poi stati visualizzati come ridge plots    
###############################    
if(1==0){
    #####
    ###scrivo data.frame effetti fissi
    #####
    
    as.data.frame(inla.out$summary.fixed)->dfFixed
    rownames(dfFixed)->dfFixed$covariate
    rownames(dfFixed)<-NULL
    dfFixed$mm<-MESE
    
    ifelse(file.exists("effettiFissi.csv"),FALSE,TRUE)->NOMI_COLONNE  
    write_delim(dfFixed,"effettiFissi.csv",delim=";",col_names = NOMI_COLONNE,append = TRUE)
    rm(NOMI_COLONNE)
    
    purrr::map_dfc(VARIABILI,.f=function(vv){
      

      as.data.frame(inla.out$marginals.fixed[[vv]])->df
      names(df)<-paste(names(df),vv,sep="_")
      
      df
      
    })->dfFixedMarginals
    
    dfFixedMarginals$mm<-MESE
    ifelse(file.exists("marginaliFissi.csv"),FALSE,TRUE)->NOMI_COLONNE  
    write_delim(dfFixedMarginals,"marginaliFissi.csv",delim=";",col_names = NOMI_COLONNE,append = TRUE)
    rm(NOMI_COLONNE)
    ##
    
    ########################
    # SPDE results
    
    inla.spde.result(inla.out,name="i",spde=spde,do.transform=TRUE)->spdeResults
    data.frame(range=exp(spdeResults$summary.log.range.nominal$mean),mm=MESE)->dfRange
    ifelse(file.exists("rangeSpde.csv"),FALSE,TRUE)->NOMI_COLONNE  
    write_delim(dfRange,"rangeSpde.csv",delim=";",col_names = NOMI_COLONNE,append = TRUE)
    rm(NOMI_COLONNE)
    
    as.data.frame(spdeResults$marginals.range.nominal$range.nominal.1)->dfRangeMarginal
    dfRangeMarginal$mm<-MESE
    
    ifelse(file.exists("rangeMarginal.csv"),FALSE,TRUE)->NOMI_COLONNE  
    write_delim(dfRangeMarginal,"rangeMarginal.csv",delim=";",col_names = NOMI_COLONNE,append = TRUE)
    rm(NOMI_COLONNE)
    
}#fine 1==0    
########################
# Effetti covariate:  fine
#    
###############################        
    
    
    #######################
    ###salvo output?
    if(SAVE_OUTPUT){saveRDS(inla.out,glue::glue("result{MESE}.RDS"))}

    rm(inla.out)
    
    ######################## Mandami un sms x dirmi che ho finito
    tryCatch({
      RPushbullet::pbPost(type="note",title=glue::glue("{AREA}-{MESE}"),body="Ho terminato")
    },error=function(e){
      glue::glue("{AREA}: ho terminato!")
    })
    

})#fine purrr::walk su MESE
})#fine purrr::wal qualeTrial
