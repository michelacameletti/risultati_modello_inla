#modello.R genera una variabile globale inla.out
#I file .Rmd se trovono questa variabile globale NON rileggono result.RDS, lettura che pu risultare 
#molto onerosa in termini di tempo
source("modello.R")

rmarkdown::render("variogrammi.Rmd","html_document","variogrammi.html")
rmarkdown::render("variogrammiResidui.Rmd","html_document","variogrammiResidui.html")
#rmarkdown::render("spatioTemporalVariogram.Rmd","html_document","spatioTemporalVariogram.html")

rmarkdown::render("modello.Rmd","html_document","modello.html")
rmarkdown::render("spde.Rmd","html_document","spde.html")
rmarkdown::render("residui.Rmd","html_document","residui.html")
#rmarkdown::render("pit.Rmd","html_document","pit.html")
rmarkdown::render("modelloValidazione.Rmd","html_document","modelloValidazione.html")
rmarkdown::render("autocorrelation.Rmd","html_document","autocorrelation.html")

rmarkdown::render("missingData.Rmd","html_document","missingData.html")
rmarkdown::render("codice.Rmd","html_document","codice.html")


rmarkdown::render("index.Rmd","html_document","index.html")



