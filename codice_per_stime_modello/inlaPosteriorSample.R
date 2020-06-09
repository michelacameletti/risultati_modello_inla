rm(list=objects())
library("INLA")
library("tidyverse")
library("tictoc")

MESE<-1

inla.setOption(pardiso.license="~/pardiso/licenza.txt")


readRDS(glue::glue("result{MESE}.RDS"))->inla.out
tic()
inla.posterior.sample(n=1000,result=inla.out,num.threads = 3)->inlaSampleOut
toc()