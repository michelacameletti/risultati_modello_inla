rm(list=objects())
library("raster")
library("tidyverse")
library("ggspatial")
library("patchwork")
library("scico")
library("sf")
library("latex2exp")
library("furrr")

plan(multicore,workers=30)

list.files(pattern="^.+\\.nc$")->ffile

readRDS("gadm36_ITA_1_sf_originale_senzaIsolette_dissolved_32632.rds")->ITALIA

raster(ffile[2])->mappa26
raster(ffile[1])->mappa21


creaMappa<-function(x,titolo,paletta){
  
  crs(x)<-CRS("+init=epsg:32632")
  
  ggplot()+
    layer_spatial(data=x)+
    geom_sf(data=ITALIA,fill="transparent",colour="#333333",lwd=0.25)+
    scale_fill_scico(na.value="transparent",palette=paletta,name=TeX("$PM_{10}(\\mu g/m^3)$"),limits=c(0,120),breaks=seq(0,120,20))+
    guides(fill=guide_colourbar(frame.colour = "#333333"))+
    labs(title=titolo)+
    theme_bw()+
    theme(text = element_text(family="Lato"))+
    coord_sf(crs = 32632)
  
  
}#fine creaMappa


furrr::future_map(scico_palette_names(),.f=function(nome){


creaMappa(x=mappa26,titolo="January 26th",paletta=nome)->grafico26
creaMappa(x=mappa21,titolo="July 21st",paletta=nome)->grafico21


png(glue::glue("mappeGiornaliere_paletta{nome}.png"),1024,768)
print(grafico26+grafico21+plot_layout(guides="collect")+plot_annotation(title=glue::glue("Paletta: {nome}")))
dev.off()
#expression("Prob"("PM"[10]>"50"~mu*g/m^3)

})