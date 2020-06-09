#grafico densita distribuzioni a posteriori
graficoDensita<-function(x,nome,scala=NULL,...){
  x[[nome]]->xx
  xx[,1]->asseX
  xx[,2]->asseY
  if(!is.null(scala)){asseX<-asseX/scala}
  plot(asseX,asseY,type="l",...)
}

#trasforma le marginali
# function(nomeVar){ 
  #   inla.tmarginal(fun=function(x){exp(x)-1 },marginal = inla.out$marginals.fixed[[nomeVar]])->xx
  # 
  #   as.data.frame(xx)->xx
  #   xx$variabile<-nomeVar
  #   
  #   xx
  #   
  # }
