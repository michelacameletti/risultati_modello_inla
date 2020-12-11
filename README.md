# Risultati modello INLA

Risultati per il modello del PM10


## Reviewer 1: 

*The paper describes a nice application of statistical modelling to generate high resolution PM maps across Italy, which is difficult to obtain with other approaches (such as chemistry transport modelling).  I am positive about this paper and would advise to accept it with minor revisions. Below I list some of the issues I like to see addressed in the final version, complemented by a list of small suggestions.*

First of all, I would like to advise to structure the paper a bit further by grouping al methodology aspects in to the methods section. Now they are partly still in sections with results.

**The structure of the "Materials and Methods" section was slightly changed. Now, it includes a "Software" subsection where the code and software details are explained. Originally, these  pieces of informations were included in the "Results" section".** 

Second, I have the following questions and suggestions:

- PM10 is measured with different techniques. Could you detect the impact of different techniques in the study? Or are the networks so well organized they use the same procedures? **Chiesto a Giorgio**

- What is the impact of isolated stations in data sparse regions like in Sicily

**Guido: The impact of the isolated stations can be desumed by the relative width of the posterior interquartile range maps (lower maps of Figure 7 and 8), which show the relative uncertainty of the predicted concentrations surface. Both daily and monthly maps highlight that the uncertainty is lower (white areas) where the network of the monitoring sites is denser and higher (brown areas) otherwise. This is particularly apparent in mountainous areas like the Alps in the North, the Appennine across the centre of Italy, and in the west-central Sicily which is covered by an irregular range (Sicanian Mountains).**

- I am wondering if the evaluation on annual means would remove a lot of the effects of the daily noise. Did you try this? 

**Guido: No, we did not try this. As explained in the paper, our model is a monthly model, that is to say a model with the same set of covariates whose effect on the target variable (PM10) has been estimated on a monthly basis. For this reason, it was straightforward to calculate the monthly uncertainty maps (Figure 8). On the contrary, the uncertainty associated to the annual means would require a unique annual model (namely, to estimate the overall effect of the covariates on the PM10 pooling all the months) which is not the object of our study.**

In the same direction, you calculated the number of chance of exceeding the annual number of days above 50 ug/m3. Could you provide evaluation statistics in comparison to the stations you left out in the training?

**Guido: We are not able to provide such statistics as the exceedance maps were created to illustrate a potential application of the final model. In such model , the parameters were estimated using all the available input stations. Conversely, the input dataset was split into a training and validation dataset in the validation stage of our analysis, with the purpose of evaluating the predictive performances of the model with respect to the daily PM10 mean concentrations.**   

- Concerning the choice of predictors one could also use of gridded PM emissions instead of imperviousness or modelled PM10/2.5 distributions the CAMS regional air quality service or a single CTM. Could you add a little discussion on potential further options to improve the predictor set? Now there are few lines on it.

**We reviewed the "Conclusions" section, including a comment about the use of gridded PM emissions products to improve the predictive model performance**



## List of small suggestions:


- Line 11: It would be stronger to mention the result of the study here. Fine or coarse? **<---QUESTA NON LA CAPISCO PROPRIO**

Can be used as a motivation why the focus on PM10 in stead of PM2.5. 

**Chiesto a Giorgio**

- Line 76: this is not a start of a new paragraph 

**We have modified the sentence position.**

- Lin 97-98: could you move the code availability to the methodology section? **As explained above, the code availability now belongs to the "Software" section in "Materials and Methods".**

- Line 128: in stead of with positive trend write "with concentrations decreasing towards the north"? **Thanks for the suggestion, we have included this in the paper.**

- Line 129: does the gradient have an health impact? 😉 **Chiesto a Giorgio**

- Line 134: Is ISPRA the institute? It is a bit confusing with JRC being in Ispra (town). If the acronym is ISPRA is the real one please use it. **ISPRA is the acronym for the Italian Institute for Environmental Protection and Research (Rome), so we have left it in the paper.**

- Line 139: Does the mentioned criteria mean that you use a different set of observations for each month in the mapping procedure? Or did you remove the annual time series for every station with a missing month? The monthly time step in the training procedure is not introduced yet at this point (except the abstract).  Can you phrase the sentence a bit more concise?

You talk about observations per month, but the daily means are composed of averaged hourly or half-hourly values. Better to talk about "valid daily mean concentrations" or so (see line 142)? 

**The model was run using the same set of stations for every month in order to keep constant in time the station density. To make the text more clear, we have changed the original sentence 'we have removed all stations with less than 10 valid observations per month' into 'we have kept only stations that had at least 10 valid daily mean concentrations per each month'**

- Line 147-148 you say twice the same thing in the on the one hand/other hand. Maybe remove the whole sentence as it does not add so much to the story

**Frase originale:**
145 This situation is not unexpected:  if on the one hand monitoring networks are designed to ensure
146 observational measures being representative of both high and low polluted areas, 
147 on the other hand contaminated areas (located particularly within urban areas)
148 typically require denser networks (EU, 2002).

**Proposta Guido/Sara:**
145 This bias is not unexpected, as contaminated areas typically require denser networks (EU, 2002).

We have modified this sentence

- Line 163: How do these high values impact the results?  

**In the section 3.2 (Validation section ) we have underlined that the  model  fails  to  reproduce  very  high  PM10 concentrations (i.e., above  150 μg/m3). As an example, Figure 6 (urban time series, July) illustrates a situation where the model underestimates such high observations. However, the validation results  indicate that, overall,our model provides a realistic description of the spatio-temporal variability of the PM10 concentrations. Specifically, our results show that the monthly  models  perform  well  both  in the training  and  in  the  validation  stage, with performance measures (credible interval, RMSE, correlation) having sensible results."** 

 Were they single station events or regional phenomena? **Chiesto a Giorgio**

- Line 266-269 belongs to the methodology section above **As already explained (see the comment to Lines 97-98), the code availability now belongs to the "Software" section in "Materials and Methods".** 

- Line 287: could you try to explain/interpret this behavior accounting for urban emissions and mixing conditions? **Chiesto a Giorgio**

- Line 311: same here, there are good reasons why summer time PM10 levels are correlated across larger areas when you connect the emission situation, orography and mixing layer height.

**We have included in the text a short explaination of why in summer time PM10 levels are correlated across larger areas. The original sentence was "*There is a clear tendency for the range to be larger in summer corresponding to a spatially smoother particulate matter field; the same behaviour holds for the posterior sd.*".The new sentence reads "*There is a clear tendency for the SPDE range to be larger in summer,corresponding to a spatially smoother particulate matter field; the same behaviour holds for the posterior sd. This result reflects the fact that, in summer time, the PM10 concentrations are characterized by low spatial variability [most of which is/which is mostly] explained by the model predictors*."**



## Section on validation: 

*the first lines reflect the methodology. Could you integrate that to the method section? **See the answers to the comments to "Line 97-98" and "Line 266-269"**.  Until this point, I was wondering whether you performed an evaluation on a subset of the data. How did you select the 10 % validation set?*

**At the beginning of the validation section, we provide details about the selection of the validation set. Specifically,first we stratified the input stations into three groups according to their area type category (urban, suburban and rural). Then we sampled, without replacement, 10% of the stations from each group. The sampling process was repeated three times (trials), with the result of three validation and training datasets.**

- Line 363: Are the mentioned spikes regional phenomena of effects of local activities/events (festival, fireworks, …)? **GIORGIO**

# Revisioni


### List of small suggestions:

- Line 46: I don't understand the term "frequentist". Could you explain what is meant by it?

**"Frequentist" is  a term, much used in the statistical community, that indicates all inferential techniques that assume the parameters to be fixed, although unknown, quantities. This is in contrast with the Bayesian approach that considers model parameters as stochastic variables with their own probability density. It could maybe be substituted by "classical" but we believe that frequentist is the most common term. The paper of Rodriguez et al. (2019) provides an example of the use of the term "frequentist" in relation with air quality issues.**

*NOX and PM10 Bayesian concentration estimates using high-resolution numerical simulations and ground measurements over Paris, France,
Atmospheric Environment: X,Volume 3, 2019, 100038,mISSN 2590-1621, https://doi.org/10.1016/j.aeaoa.2019.100038.*

Vogliamo fornire un riferimento? Ad esempio: **Hastie, T., Tibshirani R.,, Friedman J. The Elements of Statistical Learning.**

*The Bayesian approach differs from the standard (“frequentist”) method for inference in its use of a prior distribution to express the uncertainty present before seeing the data, and to allow the uncertainty remaining after seeing the data to be expressed in the form of a posterior distribution.(pagina 289)*

- In line 143 use the term "monitoring stations" (in stead of "measurements" are located) Did you include al types of stations? Especially traffic/industrial are impacted by local source increments and I am curious how you treated those.

**We have changed "measurements" with "monitoring stations" as suggested by the reviewer. As for the monitoring stations included in the study: yes we have included all kinds of stations, the only criteria we have used to exclude a station is the presence of too many missing data as explained in the paper.
For validation purposes, we have stratified the input stations according to their environment type classification: urban (294 stations), suburban (131) and rural (70). Our analysis did not consider the sources of local air pollution as a further classification criteria of the input stations. However, we know that the urban stations include:	background stations (146),	industrial stations (8) and traffic stations (140). As for the the suburban stations, most of them are classified as foreground (77) and industrial (41) stations. Finally, most of the rural stations are background stations (54).  **
**

**Giorgio ci fornisce il numero di stazioni di traffico, industriali etc in modo di poter dire al reviewr che noi utilizziamo solo la distinzione delle stazioni in base al tipo di area (urban, suburban, rural) ma fornirgli anche un numero di stazioni che sono industriali, di traffico etc**


### Section on validation:

- Line 443: the method for population exposure could go up

**Guido: ho spostato il paragrafo "*population exposure*" prima delle "exceedence probability maps*" (con il risultato di avere ora le figure nel pdf incasinate :-) ), Non sono sicuro di cosa volesse il reviewer con questo commento!**

- Figure 3: when the captions of the figures reflect the long variable name the figure would be more easy to read. 

  - [figura articolo](./figure_originali/ggRidgePatchwork.png) e e [figura con nuovi titoli covariate](./nuove_figure/ggRidgePatchwork.png)
  
  **The captions of the figures now report the long variable name as suggested by the reviewer**
  
- Figure 5: using a lower range would provide more contrast in the plots. They are very blue now 

**The scatterplot now represents the number of points of each hexbin on a logairthmic scale, with the result of a lower range and a more contrasted plot**
 

- Figure 6: **it would be nice to know which stations are shown and where they are located**.  Please adjust the range of the scale
 
    - [figura articolo](./figure_originali/graficiSerieValidazione_urbanJanuary.png) 
    
    - [figura con nuovo asse y e posizione stazione: stazione urban](./nuove_figure/graficiSerieValidazione_urbanJanuary.png)

    - [figura con posizione stazione: stazione suburban](./nuove_figure/graficiSerieValidazione_suburbanJanuary.png)
    
    - [figura con posizione stazione: stazione rural](./nuove_figure/graficiSerieValidazione_ruralJanuary.png)
    
  **Following the reviewer's suggestions, we have changed the range of the scale for the urban station for the January series. In addition, we have added an inset to each January time series to show the position of the corresponding station. In addition, the caption reports the stations names."**


- Figura 7 e 8 [SARA] cambiare la scala della mappa per la varianza: 

**We have slightly modified the range of the scale for the variance maps of Figure 7 and 8. The final result is a set of maps more readable**

  - January 26 (giornaliera): [figura articolo](./figure_originali/giornaliera26GennaioRocv_palettabilbao.png) e [figura con nuova scala](./nuove_figure/giornaliera26GennaioRocv_palettabilbao.png)

  - July 21 (giornaliera): [figura articolo](./figure_originali/giornaliera21LuglioRocv_palettabilbao.png) e [figura con nuova scala](./nuove_figure/giornaliera21LuglioRocv_palettabilbao.png)
  
   - January 26 (mensile): [figura articolo](./figure_originali/mensileGennaioRocv_palettabilbao.png) e [figura con nuova scala](./nuove_figure/mensileGennaioRocv_palettabilbao.png)

  - July 21 (mensile): [figura articolo](./figure_originali/mensileLuglioRocv_palettabilbao.png) e [figura con nuova scala](./nuove_figure/mensileLuglioRocv_palettabilbao.png)

