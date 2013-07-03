library(smaa)
library(hitandrun)
library(MASS)

wrap.result <- function(result, description) {
    list(data=result, description=description, type=class(result))
}

wrap.matrix <- function(m) {
  l <- lapply(rownames(m), function(name) { m[name,] })
  names(l) <- rownames(m)
  l
}


smaa <- function(params) {
  allowed <- c('scales', 'smaa')
  if(params$method %in% allowed) {
    do.call(paste("run", params$method, sep="_"), list(params))
  }
}

sample <- function(measurement, N) {
  if (measurement$performance$type == 'dbeta') {
    rbeta(N, measurement$performance$parameters['alpha'], measurement$performance$parameters['beta'])
  } else if (measurement$performance$type == 'relative-logit-normal') {
    perf <- measurement$performance$parameters
    baseline <- perf$baseline
    sampleBase <- function() {
      if (baseline$type == 'dnorm') {
        rnorm(N, baseline$mu, baseline$sigma)
      } else {
        stop(paste("Distribution '", baseline$type, "' not supported", sep=''))
      }
    }
    sampleDeriv <- function(base) {
      if(perf$relative$type == 'dmnorm') {
        varcov <- perf$relative$cov
        covariance <- matrix(unlist(varcov$data),
                              nrow=length(varcov$rownames),
                              ncol=length(varcov$colnames))
        mvrnorm(N, perf$relative$mu, covariance) + base
      } else {
        stop(paste("Distribution '", perf$relative$type, "' not supported", sep=''))
      }
    }
    sampleDeriv(sampleBase())
  }
}

run_scales <- function(params) {
  N <- 1000
  crit <- names(params$criteria)
  alts <- names(params$alternatives)
  n <- length(params$criteria)
  m <- length(params$alternatives)
  meas <- array(dim=c(N,m,n), dimnames=list(NULL, alts, crit))
  for (m in params$performanceTable) {
    if (m$performance$type == 'dbeta') {
      meas[, m$alternative, m$criterion] <- sample(m, N)
    } else if (m$performance$type == 'relative-logit-normal') {
      meas[, ,m$criterion] <- sample(m, N)
    } else {
      stop(paste("Performance type '", m$performance$type, "' not supported.", sep=''))
    }
  }
  list(wrap.matrix(t(apply(meas, 3, function(e) { quantile(e, c(0.025, 0.975)) }))))
}

run_smaa <- function(params) {
  N <- 10000
  n <- length(params$criteria)
  m <- length(params$alternatives)
  crit <- names(params$criteria)
  alts <- names(params$alternatives)

  harSample <- function(constr, n , N) {
    transform <- simplex.createTransform(n)
    constr <- simplex.createConstraints(transform, constr)
    seedPoint <- createSeedPoint(constr, homogeneous=TRUE)
    har(seedPoint, constr, N=N * (n-1)^3, thin=(n-1)^3, homogeneous=TRUE, transform=transform)$samples
  }

  partialValue <- function(worst, best) {
    if (best > worst) {
      function(x) {
        (x - worst) / (best - worst)
      }
    } else {
      function(x) {
        (worst - x) / (worst - best)
      }
    }
  }

  pvf <- lapply(params$criteria, function(criterion) {
    range <- criterion$pvf$range
    if (criterion$pvf$type == 'linear-increasing') {
      return(partialValue(range[1], range[2]))
    } else if (criterion$pvf$type == 'linear-decreasing') {
      return(partialValue(range[2], range[1]))
    } else {
      stop(paste("PVF type '", criterion$pvf$type, "' not supported.", sep=''))
    }
  })

  ilogit <- function(x) {
    1 / (1 + exp(-x))
  }

  meas <- array(dim=c(N,m,n), dimnames=list(NULL, alts, crit))
  for (m in params$performanceTable) {
    if (m$performance$type == 'dbeta') {
      meas[, m$alternative, m$criterion] <- pvf[[m$criterion]](sample(m, N))
    } else if (m$performance$type == 'relative-logit-normal') {
      meas[, ,m$criterion] <- pvf[[m$criterion]](ilogit(sample(m, N)))
    } else {
      stop(paste("Performance type '", m$performance$type, "' not supported.", sep=''))
    }
  }

  # parse preference information
  constr <- do.call(mergeConstraints, lapply(params$preferences,
    function(statement) {
      i1 <- which(crit == statement$criteria[1])
      i2 <- which(crit == statement$criteria[2])
      if (statement$type == "ordinal") {
        ordinalConstraint(n, i1, i2)
      } else if (statement['type'] == "ratio bound") {
        l <- statement$bounds[1]
        u <- statement$bounds[2]
        mergeConstraints(
          lowerRatioConstraint(n, i1, i2, l),
          upperRatioConstraint(n, i1, i2, u)
        )
      }
    })
  )

  weights <- harSample(constr, n, N)

  utils <- smaa.values(meas, weights)
  ranks <- smaa.ranks(utils)

  cw <- smaa.cw(ranks, weights)
  colnames(cw) <- crit


  results <- list(
    results = list(
             "cw"=wrap.matrix(cw),
             "ranks"=wrap.matrix(smaa.ra(ranks))),
    descriptions = list("Central Weights", "Rank acceptabilities")
  )

  mapply(wrap.result,
          results$results,
          results$descriptions,
          SIMPLIFY=F)
}