rm(list=objects())
library("raster")
library("magick")
library("imager")
library("av")
library("tidyverse")
library("gganimate")
library("ggspatial")


nomeFile<-"exp_pm10_mese5.tif"
giornoI<-2
giornoF<-9

brick(nomeFile)->mybrick
nlayers(mybrick)->quantiLayers
subset(mybrick,3:quantiLayers)->mybrick
subset(mybrick,giornoI:giornoF)->xx

summary(xx)

purrr::walk(giornoI:giornoF,.f=function(ii){

ggplot()+
  layer_spatial(data=mybrick[[ii]])+
  scale_fill_viridis_c(na.value = "transparent",name="")+
  expand_limits(fill=c(0,90))+
  labs(title=glue::glue("2015-05-{str_pad(ii,width=2,pad='0',side='left')}"))+
  theme_void()->grafico

png(glue::glue("grafico{ii}.png"),width=768,height=1024)
print(grafico)
dev.off()

})


image_read(list.files(pattern="^grafico.+png$"))->grafici
image_animate(grafici,delay=25000,loop=1,dispose = "background")->mygif
image_write_gif(mygif,"evento_4maggio.gif")

#image_read_video("2015050412-3H_SDSWAS_NMMB-BSC-v2_OPER-OD550_DUST--loop-.gif")->myvideo
#plot(myvideo[[1]])
