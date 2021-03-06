#' @rdname MIN_return
MIN_return<-function(x){
  return(min(x[x>0]))
}

#' @rdname Global_Zcut
Global_Zcut<-function(MAT) {
  VEC<-apply(MAT, 1, MIN_return)
  set.seed(123)
  VEC<-VEC+rnorm(length(VEC),0,0.0001)
  Zcut_univ<-0
  tryCatch({
    set.seed(123)
    MIN_fit = normalmixEM(log(VEC),k = 2)
    INTER<-Intersect2Mixtures(Mean1 = MIN_fit$mu[1],SD1 = MIN_fit$sigma[1],Weight1 = MIN_fit$lambda[1],
                              Mean2 = MIN_fit$mu[2],SD2 = MIN_fit$sigma[2],Weight2 = MIN_fit$lambda[2])
    Zcut_univ<-INTER$CutX
  }, error=function(e){})

  return(exp(Zcut_univ))
}

#' @rdname BIC_LTMG
BIC_LTMG <- function(y, rrr, Zcut) {
  n <- length(y)

  nparams <- nrow(rrr) * 3-1
  w <- rrr[, 1]
  u <- rrr[, 2]
  sig <- rrr[, 3]
  y0 <- y[which(y >= Zcut)]

  cc <- c()
  for (i in 1:nrow(rrr)) {
    c <- dnorm(y0, u[i], sig[i]) * w[i]
    cc <- rbind(cc, c)
  }
  d <- apply(cc, 2, sum)
  e <- sum(log(d))
  f <- nparams * log(n)-e*2
  return (f)
}

#' @rdname BIC_ZIMG
BIC_ZIMG <-function(y,rrr,Zcut){
  y<-y[y>Zcut]
  n<-length(y)
  nparams <- nrow(rrr) * 3-1
  w <- rrr[, 1]
  u <- rrr[, 2]
  sig <- rrr[, 3]
  y0 <- y[which(y >= Zcut)]
  cc <- c()
  for (i in 1:nrow(rrr)) {
    c <- dnorm(y0, u[i], sig[i]) * w[i]
    cc <- rbind(cc, c)
  }
  d <- apply(cc, 2, sum)
  e <- sum(log(d))
  f <- nparams * log(n)-e*2
  return (f)
}

#' @rdname Pure_CDF
Pure_CDF<-function(Vec){
  ### Vec should be sorted ###
  TEMP<-sort(Vec)
  TOTAL<-length(Vec)
  CDF<-rep(0,length = length(TEMP))
  m<-TEMP[1]
  KEEP<-c(1)
  if(length(TEMP)>1){
    for (i in 2:length(TEMP)) {
      if (TEMP[i]==m) {
        KEEP<-c(KEEP,i)
      }else{
        m<-TEMP[i]
        CDF[KEEP]<-(i-1)/TOTAL
        KEEP<-c(i)
      }
    }
  }
  CDF[KEEP]<-1
  return(CDF)
}

#' @rdname KS_LTMG
KS_LTMG<-function(y,rrr,Zcut){
  y<-sort(y)
  num_c<-nrow(rrr)
  y[which(y<Zcut)]<-Zcut-2
  y0<-y[which(y>=Zcut)]
  p_x<-rep(0,length(y0))

  for(j in 1:num_c){
    p_x<-p_x+pnorm(y0,mean=rrr[j,2],sd=rrr[j,3])*rrr[j,1]
  }

  p_uni_x<-Pure_CDF(y)
  p_uni_x<-p_uni_x[which(y>=Zcut)]
  return(max(abs(p_x-p_uni_x)))
}

#' @rdname KS_ZIMG
KS_ZIMG<-function(y,rrr,Zcut){
  num_c<-nrow(rrr)
  y0<-y[which(y>=Zcut)]
  y0<-sort(y0)
  p_x<-rep(0,length(y0))

  for(j in 1:num_c){
    p_x<-p_x+pnorm(y0,mean=rrr[j,2],sd=rrr[j,3])*rrr[j,1]
  }

  p_uni_x<-Pure_CDF(y0)
  return(max(abs(p_x-p_uni_x)))
}

#' @rdname State_return
State_return<-function(x){
  return(order(x,decreasing = T)[1])
}

#' @rdname MINUS
MINUS<-function(x,y){
  if(x<y){
    return(0)
  }else{
    return(x-y)
  }
}

#' @rdname Fit_LTMG
# Fit_LTMG(y,100,Zcut,K)
Fit_LTMG<- function(x, n, q, k, err = 1e-10) {
  q <- max(q, min(x))
  c <- sum(x < q)
  x <- x[which(x >= q)]
  if (length(x) <= k) {
    warning(sprintf("The length of x is %i. Sorry, too little conditions\n", length(x)))
    return(cbind(0, 0, 0))
  }
  mean <- c()
  for (i in 1:k) {
    mean <- c(mean, sort(x)[floor(i * length(x) / (k + 1))])
  }
  mean[1] <- min(x) - 1  # What is those two lines for?
  mean[length(mean)] <- max(x) + 1  # Without them the result of mean[1] is slightly different.
  p <- rep(1 / k, k)
  sd <- rep(sqrt(var(x)), k)
  pdf.x.portion <- matrix(0, length(x), k)

  for (i in 1:n) {
    p0 <- p
    mean0 <- mean
    sd0 <- sd

    pdf.x.all <- t(p0 * vapply(x, function(x) dnorm(x, mean0, sd0), rep(0, k)))
    pdf.x.portion <- pdf.x.all / rowSums(pdf.x.all)
    cdf.q <- pnorm(q, mean0, sd0)
    cdf.q.all <- p0 * cdf.q
    cdf.q.portion <- cdf.q.all / sum(cdf.q.all)
    cdf.q.portion.c <- cdf.q.portion * c
    denom <- colSums(pdf.x.portion) + cdf.q.portion.c
    p <- denom / (nrow(pdf.x.portion) + c)
    im <- dnorm(q, mean0, sd0) / cdf.q * sd0
    im[is.na(im)] <- 0
    mean <- colSums(crossprod(x, pdf.x.portion) + (mean0 - sd0 * im) * cdf.q.portion.c) / denom
    sd <- sqrt((colSums((x - matrix(mean0, ncol = length(mean0), nrow = length(x),
                                    byrow = TRUE)) ^ 2 * pdf.x.portion) + sd0 ^ 2 * (1 - (q - mean0) / sd0 * im) *
                  cdf.q.portion.c) / denom)
    if (!is.na(match(NaN, sd))) {
      break
    }
    if ((mean(abs(p - p0)) <= err) && (mean(abs(mean - mean0)) <= err) &&
        (mean(abs(sd - sd0)) <= err)) {
      break
    }
  }
  return(cbind(p, mean, sd))
}

#' @rdname LTMG
LTMG<-function(VEC,Zcut_G,k=5){
  y<-log(VEC)
  y<-y+rnorm(length(y),0,0.0001)
  Zcut<-min(log(VEC[VEC>0]))
  if(Zcut<Zcut_G){
    Zcut<-Zcut_G
  }


  if(all(VEC>Zcut_G)){
    rrr<-matrix(c(1,mean(y[y>=Zcut]),sd(y[y>=Zcut])),nrow = 1,ncol = 3)
    MARK<-BIC_ZIMG(y,rrr,Zcut)
    rrr_LTMG<-rrr
    for (K in 2:(k-1)) {
      tryCatch({
        mixmdl<-normalmixEM(y[y>Zcut],K)
        rrr<-cbind(mixmdl$lambda,mixmdl$mu,mixmdl$sigma)
        TEMP<-BIC_ZIMG(y,rrr,Zcut)
        if(TEMP<MARK){
          rrr_LTMG<-rrr
          MARK<-TEMP
        }
      }, error=function(e){})
    }
    rrr_LTMG<-rbind(c(0,-Inf,0.0001),rrr_LTMG)
  }else{
    MARK<-Inf
    rrr_LTMG<-NULL
    for (K in 2:k){
      tryCatch({
        rrr<-Fit_LTMG(y,100,Zcut,K)
        rrr<-matrix(as.numeric(rrr[!is.na(rrr[,2]),]),ncol=3,byrow=F)
        TEMP<-BIC_LTMG(y,rrr,Zcut)
        #print(TEMP)
        if(TEMP<MARK){
          rrr_LTMG<-rrr
          MARK<-TEMP
        }
      }, error=function(e){})
    }
  }

  rrr_LTMG<-rrr_LTMG[order(rrr_LTMG[,2]),]
  rrr_use<-matrix(as.numeric(rrr_LTMG),ncol=3,byrow=F)

  return(rrr_LTMG)
}



# Run LTMG function --------------------------------------------------------------------
#' RunLTMG
#'
#' @param object
#' @param Gene_use using X numebr of top variant gene. input a number, recommend 2000.
#' @name RunLTMG
#' @return
#' @importFrom AdaptGauss Intersect2Mixtures
#' @importFrom mixtools normalmixEM
#' @importFrom stats sd
#' @examples
.RunLTMG <- function(object,Gene_use = NULL, seed = 123, k = 5){
  MAT <- as.matrix(object@InputData)
  MAT <- ifelse(is.na(MAT),0,MAT)
  MAT<- MAT[rowSums(MAT)>0,colSums(MAT)>0]
  set.seed(123)
  Zcut_G <- log(Global_Zcut(MAT))
  LTMG_Res<-c()
  gene_name<-c()
  if (is.null(Gene_use)|| grepl("all", Gene_use, ignore.case = T) ){

    message("using all genes.")
    Gene_use_name <- rownames(MAT)
  } else{
    Gene_use_name <-rownames(MAT)[order(apply(MAT, 1, var),decreasing = T)[1:Gene_use]]
  }

  LTMG_Res<-c()
  SEQ<-floor(seq(from = 1,to = length(Gene_use_name),length.out = 11))

  set.seed(123)
  for (i in 1:length(Gene_use_name)) {
    if(i %in% SEQ){
      cat(paste0("Progress:",(grep("T",SEQ==i)-1)*10,"%\n" ))
    }

    VEC<-MAT[Gene_use_name[i],]
    gene_name <- c(gene_name, Gene_use_name[i])
    y<-log(VEC)
    y<-y+rnorm(length(y),0,0.0001)
    Zcut<-min(log(VEC[VEC>0]))
    if(Zcut<Zcut_G){
      Zcut<-Zcut_G
    }

    if(all(VEC>Zcut_G)){
      rrr<-matrix(c(1,mean(y[y>=Zcut]),sd(y[y>=Zcut])),nrow = 1,ncol = 3)
      MARK<-BIC_ZIMG(y,rrr,Zcut)
      rrr_LTMG<-rrr
      for (K in 2:(k-1)) {
        tryCatch({
          mixmdl<-normalmixEM(y[y>Zcut],K)
          rrr<-cbind(mixmdl$lambda,mixmdl$mu,mixmdl$sigma)
          TEMP<-BIC_ZIMG(y,rrr,Zcut)
          if(TEMP<MARK){
            rrr_LTMG<-rrr
            MARK<-TEMP
          }
        }, error=function(e){})
      }
      rrr_LTMG<-rbind(c(0,-Inf,0.0001),rrr_LTMG)
    }else{
      MARK<-Inf
      rrr_LTMG<-NULL
      for (K in 2:k){
        tryCatch({
          rrr<-Fit_LTMG(y,100,Zcut,K)
          rrr<-matrix(as.numeric(rrr[!is.na(rrr[,2]),]),ncol=3,byrow=F)
          TEMP<-BIC_LTMG(y,rrr,Zcut)
          #print(TEMP)
          if(TEMP<MARK){
            rrr_LTMG<-rrr
            MARK<-TEMP
          }
        }, error=function(e){})
      }
    }
    if(is.null(rrr_LTMG)){
      y_state<-rep(0,length(y))
    }else if(min(dim(rrr_LTMG))==1){
      y_state<-rep(0,length(y))
    }else{
      rrr_LTMG<-rrr_LTMG[order(rrr_LTMG[,2]),]
      rrr_use<-matrix(as.numeric(rrr_LTMG),ncol=3,byrow=F)

      y_use<-y[y>Zcut]
      y_value<-NULL
      for (k in 1:nrow(rrr_use)) {
        TEMP<-dnorm(y_use,mean = rrr_use[k,2],sd = rrr_use[k,3])*rrr_use[k,1]
        y_value<-rbind(y_value,TEMP)
      }
      y_state<-rep(0,length(y))
      y_state[y>Zcut]<-apply(y_value,2,State_return)-1
    }


    LTMG_Res<-rbind(LTMG_Res,y_state)

  }
  rownames(LTMG_Res)<-gene_name
  colnames(LTMG_Res) <- colnames(MAT)
  LTMG_Res<-as.matrix(LTMG_Res)
  object@OrdinalMatrix <- LTMG_Res
  return(object)
}

#' @export
#' @rdname RunLTMG
setMethod("RunLTMG","LTMG", .RunLTMG)

