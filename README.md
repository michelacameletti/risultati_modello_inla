# Risultati modello INLA

Risultati per il modello del PM10


## Reviewer 1: 

*The paper describes a nice application of statistical modelling to generate high resolution PM maps across Italy, which is difficult to obtain with other approaches (such as chemistry transport modelling).  I am positive about this paper and would advise to accept it with minor revisions. Below I list some of the issues I like to see addressed in the final version, complemented by a list of small suggestions.*

First of all, I would like to advise to structure the paper a bit further by grouping al methodology aspects in to the methods section. Now they are partly still in sections with results. Second, I have the following questions and suggestions:

- PM10 is measured with different techniques. Could you detect the impact of different techniques in the study? Or are the networks so well organized they use the same procedures?

- What is the impact of isolated stations in data sparse regions like in Sicily?

- I am wondering if the evaluation on annual means would remove a lot of the effects of the daily noise. Did you try this? In the same direction, you calculated the number of chance of exceeding the annual number of days above 50 ug/m3. Could you provide evaluation statistics in comparison to the stations you left out in the training?

- Concerning the choice of predictors one could also use of gridded PM emissions instead of imperviousness or modelled PM10/2.5 distributions the CAMS regional air quality service or a single CTM. Could you add a little discussion on potential further options to improve the predictor set? Now there are few lines on it.

List of small suggestions:

-Line 11: It would be stronger to mention the result of the study here. Fine or coarse? Can be used as a motivation why the focus on PM10 in stead of PM2.5.

- Line 46: I don't understand the term "frequentist". Could you explain what is meant by it?

- Line 76: this is not a start of a new paragraph

- Lin 97-98: could you move the code availability to the methodology section?

- Line 128: in stead of with positive trend write "with concentrations decreasing towards the north"?

- Line 129: does the gradient have an health impact? 😉

- Line 134: Is ISPRA the institute? It is a bit confusing with JRC being in Ispra (town). If the acronym is ISPRA is the real one please use it.

- Line 139: Does the mentioned criteria mean that you use a different set of observations for each month in the mapping procedure? Or did you remove the annual time series for every station with a missing month? The monthly time step in the training procedure is not introduced yet at this point (except the abstract).  Can you phrase the sentence a bit more concise?
You talk about observations per month, but the daily means are composed of averaged hourly or half-hourly values. Better to talk about "valid daily mean concentrations" or so (see line 142)? In line 143 use the term "monitoring stations" (in stead of "measurements" are located)
Did you include al types of stations? Especially traffic/industrial are impacted by local source increments and I am curious how you treated those.

- Line 147-148 you say twice the same thing in the on the one hand/other hand. Maybe remove the whole sentence as it does not add so much to the story

- Line 163: How do these high values impact the results? Were they single station events or regional phenomena?

- Line 266-269 belongs to the methodology section above

- Line 287: could you try to explain/interpret this behavior accounting for urban emissions and mixing conditions?

- Line 311: same here, there are good reasons why summer time PM10 levels are correlated across larger areas when you connect the emission situation, orography and mixing layer height.

## Section on validation: 

*the first lines reflect the methodology. Could you integrate that to the method section? Until this point, I was wondering whether you performed an evaluation on a subset of the data. How did you select the 10 % validation set?*

- Line 363: Are the mentioned spikes regional phenomena of effects of local activities/events (festival, fireworks, …)?

- Line 443: the method for population exposure could go up

- Figure 3: when the captions of the figures reflect the long variable name the figure would be more easy to read.

- Figure 5: using a lower range would provide more contrast in the plots. They are very blue now

- Figure 6: it would be nice to know which stations are shown and where they are located.  Please adjust the range of the scale
