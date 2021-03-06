library(Hmisc)
library(dplyr)
library(tidyr)
library(ggplot2)
library(lubridate)
library(stringr)
library(party)
library(rpart)
library(randomForest)

source(file = "../lib/utils.r", chdir = TRUE)


#Data set

(load("clean/cup98_141203.RData"))


ds.name
ds.path
dim(ds)
id
target
risk
vars.a.ignorar
vars.input


###Semilla

Generamos una secuencia aleatoria y seleccionamos una al azar como la semilla. As� podremos repetir el an�lisis si lo deseamos.

(seed <- sample(1:1000000, 1))
Alternativamente, podemos establecer una semilla por default.

# Este c�digo no hace nada, no se est� ejecutando
seed <- 12345


Variable de salida
Para este estudio, predeciremos la variable target.d.

ds <- as.data.frame(ds)

(outcome <- target[2])

El costo de cada contacto es $0.68 USD.

cost <- 0.68


Prueba y entrenamiento

train.size <- round(num.observaciones*0.7)

test.size <- num.observaciones - train.size

Guardamos las columnas de salida

ds.targets <- ds[, target]

dim(ds.targets)


Eliminamos las variables a ignorar

ds <- ds[,c(vars.input, outcome)]

dim(ds)


table(ds$target.d)



Feature Engineering

Modelos
�rbol de decisi�n

Usaremos, para fines de ilustraci�n, la funci�n rpart() del paquete party. Este �rbol tiene los siguientes par�metros:
  
Minsplit: M�nimo n�mero de instancias en un nodo para considerar su divisi�n.
MinBucket M�nimo n�mero de instancias en el nodo terminal.
MaxSurrogate: N�mero de splits a evaluar.
MaxDepth: Controla la m�xima profundidad del �rbol.

###HASTA AQUI

F�rmula

(form <- formula(paste(outcome, "~ ", paste(vars.input[1:50], collapse = ' + '), sep='')))


Entrenamiento

num.iteraciones <- 5

El entrenamiento consistir� en un hold-out repetido r num.iteraciones veces.

Inicio de entrenamiento: r date()

Tama�o de los datos de entrenamiento: r format(train.size, scientific=FALSE, big.mark=",")

Tama�o de los datos de prueba: r format(test.size, scientific=FALSE, big.mark=",")

Par�metros del �rbol:
  
  model <- 'rpart'

MinSplit <- 1000
MinBucket <- 400
MaxSurrogate <- 4
MaxDepth <- 10
parametros <- paste(MinSplit, MinBucket, MaxSurrogate, MaxDepth, sep="-")

run.donaciones <- matrix(0, nrow=test.size, ncol=num.iteraciones)
run.promedios <- matrix(0, nrow=test.size, ncol=num.iteraciones)
run.percentiles <- matrix(0, nrow=test.size, ncol=num.iteraciones)


for (iteracion in 1:num.iteraciones) {
  cat( "Iteracion: ", iteracion, " iniciada el ", date(), "\n")
  
  ## Dividimos en entrenamiento y prueba
  train.idx <- sample(1:num.observaciones, train.size)
  train <- ds[train.idx,]
  test <- ds[-train.idx,]
  
  train.targets <- ds.targets[train.idx,]
  test.targets <- ds.targets[-train.idx,]
  
  ## Par�metros
  controls <- rpart.control(minsplit = MinSplit, minbucket = MinBucket, maxsurrogate=MaxSurrogate, maxdepth = MaxDepth)
  
  ## Entrenamos un �rbol
  cat("Tiempo para entrenar: ", system.time(arbol <- rpart(form, data=train, control=controls)), "\n\n")
  
  ## Tama�o del �rbol
  cat("Tama�o del modelo en memoria: ", format(object.size(arbol), units="MB"), "\n\n")
  
  ## Guardamos el �rbol
  if (!file.exists("modelos")) dir.create("modelos") # Creamos la carpeta modelos, si no existe
  
  save(arbol, file=paste("modelos", "/", model, "-", parametros, "-iteracion-", iteracion, ".rdata", sep=""))
  
  fig.title <- paste("�rbol ", iteracion)
  
  tryCatch(plot(arbol, main=fig.title, type="simple",
                gp = gpar(fontsize = 4),
                ip_args=list(pval=FALSE),
                ep_args=list(digits=0, abbreviate=TRUE)
  ),
  error = function(e) cat("El �rbol ", iteracion, " no creci� m�s all� del nodo ra�z\n\n\n")
  )
  
  
  ## Test
  pred <- predict(arbol, newdata=test)
  
  #cat(sum(test[outcome][pred > cost] - cost), "\n")
  
  s1 <- sort(pred, decreasing=TRUE, method="quick", index.return=TRUE)
  
  donacion.total <- cumsum(test[,outcome][s1$ix])
  
  donacion.promedio <- donacion.total / (1:test.size)
  
  donacion.percentil <- 100 * donacion.total / sum(test[,outcome])
  
  run.donaciones[, iteracion] <- donacion.total
  
  run.promedios[, iteracion] <- donacion.promedio
  
  run.percentiles[, iteracion] <- donacion.percentil
  
  cat( "Iteracion: ", iteracion, " terminada el ", date(), "\n\n\n\n")
}


cat(date(), ": Terminada las iteraciones\n\n\n")

donacion.final <- rowMeans(run.donaciones)

promedio.final <- rowMeans(run.promedios)

percentil.final <- rowMeans(run.percentiles)

resultados <- data.frame(cbind(run.donaciones, donacion.final))

names(resultados) <- c(paste("run", 1:num.iteraciones), "Promedio")

if (!file.exists("resultados")) dir.create("resultados") # Creamos la carpeta resultados, si no existe
write.csv(resultados, paste("resultados", "/", "evaluacion-donacion-total-", parametros, ".csv", sep=""))

Evaluaci�n

Ap�ndice: Ambiente

sessionInfo()

































#Tarea

Antes de empezar, se observa que existen muchas "categorias", as� que lo que se puede hacer es correr todo
de nuevo pero con outcome <- target[3], en lugar de 2 o volver a crear target.d2 para s�lo obtener 7 categorias

table(ds$target.d)

ds$target.d2 <- cut(ds$target.d, right=FALSE, breaks=c(0,0.1, 10,15,20,25,30,50, max(ds$target.d)))

ds<-ds[,-370]

summary(ds$target.d2)

ds <- ds[!is.na(ds[target[3]]),]

Se eliminan las no donaciones

ds.target  <- ds[ds$target.d2 !="[0,0.1)", ]

(dim(ds.target))




ds$target.d2<- as.character(ds$target.d2)
ds$target.d2<- as.factor(ds$target.d2)

summary(ds.target$target.d2)



Se crean de nuevo los conjuntos de entrenamiento y prueba

train$target.d2 <- cut(train$target.d, right=FALSE, breaks=c(0,0.1, 10,15,20,25,30,50, max(train$target.d)))

entrenamiento<-train[,-370]

test$target.d2 <- cut(test$target.d, right=FALSE, breaks=c(0,0.1, 10,15,20,25,30,50, max(test$target.d)))

prueba<-test[,-370]

dim(entrenamiento)

dim(prueba)


entrenamiento.target  <- entrenamiento[entrenamiento$target.d2 !="[0,0.1)", ]


entrenamiento.target$target.d2<- as.character(entrenamiento.target$target.d2)
entrenamiento.target$target.d2<- as.factor(entrenamiento.target$target.d2)


##Selecci�n de variables

# Fast correlation-based filtering


FCB.filtering <- function(datos, variable, p)
{
  df <- as.data.frame(train[which(sapply(train, is.numeric))]) ##eleminamos variables no numericas
  y <- train[,370]
  corr <- abs(apply(df, 2, cor, y, use = "p"))##se obtiene vector de correlacion
  corr <- sort(corr[names(corr) != 370],decreasing=TRUE)
  vars.quitan <- character(length(corr))
  nvars.quitan <- numeric(length(corr))
  for (i in 1:length(corr)) 
  {if (corr[i] > p) vars.quitan[i] <- names(corr)[i]}
  return(vars.quitan)
}


FCB.filtering(train,370,0.02)

var.cor<-c("lastgift","maxramnt","avggift","hv2","ic5","ic4","hvp1","wealth2","hvp6",
           "hvp2","hvp3","ec8","hv3","mhuc1","income","hvp5","ic21","ic22","ic12",
           "hv4","rp2","numprm12","cluster2","hhas3","ic13","rp1","ec7","wealth1","rp3",
           "ic15","hhd9","ic6","occ11","ic20","occ4","eic15","occ2","pobc2","hhas4",
           "occ1","occ13","ic16","ec3","eic9","lastdate","dma","ec1","ec2")

form3  <- formula(paste(outcome1,"~ ",paste(var.cor,collapse = ' + '), sep=''))


# Random Forest



rf.target <- randomForest(target.d2 ~ ., entrenamiento.target, importance=TRUE,na.action=na.omit)

rf.target <- randomForest(form2, entrenamiento.target, importance=TRUE,na.action=na.omit)

imp.target <- importance(rf.target)

imp.target  <- as.data.frame(imp.target)

rf.vars <- rownames(imp.target[with(imp.target, order(-MeanDecreaseAccuracy)), ])

impvars  <- rf.vars[1:15]



(outcome1 <- target[3])

form2  <- formula(paste(outcome1,"~ ",paste(impvars,collapse = ' + '), sep=''))



modelo.completo <-randomForest(target.d2 ~ ., prueba.target, importance=TRUE,na.action=na.omit)

modelo.cor<-randomForest(form3, prueba.target, importance=TRUE,na.action=na.omit)

modelo.rf<-randomForest(form2, prueba.target, importance=TRUE,na.action=na.omit)




