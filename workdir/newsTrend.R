#파일 경로

pop.path<-"../colectedData/bigpop"
notpop.path<-"../colectedData/notpop"
poptest.path<-"../colectedData/bigpoptest"
notpoptest.path<-"../colectedData/notpoptest"

#라이브러리 설정

library(ggplot2)
library(tm)
library(KoNLP)

#함수들

get.msg<-function(path){
   con<-file(path, open="rt", encoding="UTF-8")
   text<-readLines(con)
   text<-noquote(text)
   text<-gsub(",","",text)
   text<-gsub("“","",text)
   text<-gsub("”","",text)
   text<-gsub("‘","",text)
   text<-gsub("’","",text)
   text<-gsub("·","",text)
   text<-gsub("ᄮix","",text)
   text<-gsub("곸쑝濡","",text)
   text<-gsub("있다”고","",text)
   text<-gsub("湲곗옄","",text)
   text<-gsub("寃껋쑝濡","",text)
   text<-gsub("寃껋씠","",text)
   Noun<-extractNoun(text)
   text<-c(Noun)
   close(con)
   return(paste(text,collapse="\n"))
}

get.tdm<-function(doc.vec){
   doc.corpus<-Corpus(VectorSource(doc.vec))
   control<-list(removePunctuation=TRUE, removeNumbers=TRUE, minDocFreq=2)
   doc.dtm<-TermDocumentMatrix(doc.corpus,control)
   return(doc.dtm)
}
classify.email<-function(path, training.df, prior=0.5, c=1e-5){
   msg<-get.msg(path)
   msg.tdm<-get.tdm(msg)
   msg.matrix<-as.matrix(msg.tdm)
   msg.freq<-rowSums(as.matrix(msg.matrix))
   msg.match<-intersect(names(msg.freq),training.df$term)
   if(length(msg.match)<1){
      return (prior*c^(length(msg.freq)))
   }
   else{
      match.probs<-training.df$occurrence[match(msg.match, training.df$term)]
      return (prior*prod(match.probs)*c^(length(msg.freq)-length(msg.match)))
   }
}
pop.classifier <-function(path){
  pr.pop<-classify.email(path,pop.df)
  pr.notpop<-classify.email(path, notpop.df)
  return(c(pr.notpop, pr.pop, ifelse(pr.pop > pr.notpop, 1, 0)))
}
#인기 뉴스 학습

pop.docs<-dir(pop.path)
all.pop<-sapply(pop.docs, function(p) get.msg(paste(pop.path,p,sep="/")))
pop.tdm<-get.tdm(all.pop)
pop.matrix<-as.matrix(pop.tdm)
pop.counts<-rowSums(pop.matrix)
pop.df<-data.frame(cbind(names(pop.counts),as.numeric(pop.counts)),stringsAsFactors=FALSE)
names(pop.df)<-c("term", "frequency")
pop.df$frequency<-as.numeric(pop.df$frequency)
pop.occurrence<-sapply(1:nrow(pop.matrix), function(i){
     length(which(pop.matrix[i,]>0))/ncol(pop.matrix)
})
pop.density<-pop.df$frequency/sum(pop.df$frequency)
pop.df<-transform(pop.df, density=pop.density,occurrence=pop.occurrence)
pop.df <- subset(pop.df, nchar(term) >= 2)
pop.df<-tail(pop.df, n = nrow(pop.df) - 50)
pop.df<-subset(pop.df, pop.df$occurrence<0.18)
head(pop.df[with(pop.df, order(-occurrence)),], n = 50)

#비인기 뉴스 학습

notpop.docs<-dir(notpop.path)
all.notpop<-sapply(notpop.docs, function(p) get.msg(paste(notpop.path,p,sep="/")))
notpop.tdm<-get.tdm(all.notpop)
notpop.matrix <- as.matrix(notpop.tdm)
notpop.counts<-rowSums(notpop.matrix)
notpop.df<-data.frame(cbind(names(notpop.counts),as.numeric(notpop.counts)),stringsAsFactors=FALSE)
names(notpop.df)<-c("term", "frequency")
notpop.df$frequency<-as.numeric(notpop.df$frequency)
notpop.occurrence<-sapply(1:nrow(notpop.matrix), function(i){
   length(which(notpop.matrix[i,]>0))/ncol(notpop.matrix)
})
notpop.density<-notpop.df$frequency/sum(notpop.df$frequency)
notpop.df<-transform(notpop.df, density=notpop.density,occurrence=notpop.occurrence)
notpop.df <- subset(notpop.df, nchar(term) >= 2)
notpop.df<-subset(notpop.df, notpop.df$occurrence<0.18)
head(notpop.df[with(notpop.df, order(-occurrence)),], n = 50)

#검증 데이터로 분류기 검증

notpoptest.docs <- dir(notpoptest.path)

poptest.docs <- dir(poptest.path)

notpoptest.class <- suppressWarnings(lapply(notpoptest.docs,
  function(p)
  {
   pop.classifier(file.path(notpoptest.path, p))
  }))


poptest.class <- suppressWarnings(lapply(poptest.docs,
  function(p)
  {
    pop.classifier(file.path(poptest.path, p))
  }))

notpoptest.matrix <- do.call(rbind, notpoptest.class)
notpoptest.final <- cbind(notpoptest.matrix, "notpop")


poptest.matrix <- do.call(rbind, poptest.class)
poptest.final <- cbind(poptest.matrix, "pop")

class.matrix <- rbind(notpoptest.final, poptest.final)
class.df <- data.frame(class.matrix, stringsAsFactors = FALSE)
names(class.df) <- c("Pr.notpop" ,"Pr.pop", "Class", "Type")
class.df$Pr.pop <- as.numeric(class.df$Pr.pop)
class.df$Pr.notpop <- as.numeric(class.df$Pr.notpop)
class.df$Class <- as.logical(as.numeric(class.df$Class))
class.df$Type <- as.factor(class.df$Type)

# 오류 들여다 보기

notpop.False<-subset(class.df, Type=="notpop" & Class=="FALSE")
notpop.FalseCount<-nrow(notpop.False)

notpop.True<-subset(class.df, Type=="notpop" & Class=="TRUE")
notpop.TrueCount<-nrow(notpop.True)

pop.False<-subset(class.df, Type=="pop" & Class=="FALSE")
pop.FalseCount<-nrow(pop.False)

pop.True<-subset(class.df, Type=="pop" & Class=="TRUE")
pop.TrueCount<-nrow(pop.True)
notpop.row <- c(notpop.FalseCount, notpop.TrueCount)

pop.row<-c(pop.FalseCount, pop.TrueCount)

allarticle<-rbind(notpop.row, pop.row)

colnames(allarticle) = c("False", "True")

# 그래프 그리기

class.plot <- ggplot(class.df, aes(x = log(Pr.pop), log(Pr.notpop))) +
    geom_point(aes(shape = Type, alpha = 0.5)) +
    geom_abline(intercept = 0, slope = 1) +
    scale_shape_manual(values = c("pop" = 2,
                                  "notpop" = 3),
                       name = "news Type") +
    scale_alpha(guide = "none") +
    xlab("log[Pr(pop)]") +
    ylab("log[Pr(notpop)]") +
    theme_bw() +
    theme(axis.text.x = element_blank(), axis.text.y = element_blank())
ggsave(plot = class.plot,
       filename = file.path("./", "newPopGraph.pdf"),
       height = 10,
       width = 10)
get.results <- function(bool.vector)
{
         results <- c(length(bool.vector[which(bool.vector == FALSE)]) / length(bool.vector),
              length(bool.vector[which(bool.vector == TRUE)]) / length(bool.vector))
 return(results)
}
