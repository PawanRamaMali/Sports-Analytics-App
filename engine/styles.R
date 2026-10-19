# Player types: k-means on each player's shot diet (the share of attempts
# from each diet group), for players with at least `min_fga` attempts per
# game. Clusters are named after the diet group they lean on most compared
# with the league; a cluster close to the league everywhere is "Balanced".

type_names <- c(rim = "Rim runners", paint = "Paint scorers", mid = "Mid-range creators",
                corner3 = "Corner specialists", atb3 = "Perimeter shooters")

share_cols <- paste0("share_", names(diet_groups))

name_types <- function(centers, league) {
  ratio <- sweep(centers, 2, league, "/")
  top <- apply(ratio, 1, function(r) names(diet_groups)[order(-r)][1:2])
  lean <- apply(ratio, 1, max)
  nm <- ifelse(lean < 1.15, "Balanced", type_names[top[1, ]])
  # Of the clusters leaning on the same group, the one leaning most keeps
  # the name; the others are named by their top two groups.
  for (g in setdiff(unique(nm[duplicated(nm)]), "Balanced")) {
    same <- which(nm == g)
    rest <- same[-which.max(lean[same])]
    nm[rest] <- paste(diet_groups[top[1, rest]], "+", diet_groups[top[2, rest]])
  }
  make.unique(unname(nm), sep = " ")
}

player_types <- function(metrics, k = 4, min_fga = 3, seed = 42) {
  q <- metrics[metrics$fga >= min_fga & stats::complete.cases(metrics[share_cols]), ]
  x <- as.matrix(q[share_cols])
  if (nrow(unique(x)) <= k) return(NULL)

  # A fixed seed keeps the clusters stable between renders, without
  # changing the caller's random stream.
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv())
          else assign(".Random.seed", old, globalenv()))
  set.seed(seed)
  km <- stats::kmeans(x, centers = k, nstart = 25)

  # Order clusters from rim-heavy to perimeter-heavy, so names and colours
  # do not depend on k-means' arbitrary numbering.
  ord <- order(-(km$centers[, "share_rim"] + km$centers[, "share_paint"]))
  centers <- km$centers[ord, , drop = FALSE]
  cluster <- match(km$cluster, ord)
  colnames(centers) <- names(diet_groups)
  labels <- name_types(centers, stats::setNames(colMeans(x), names(diet_groups)))

  q$type <- factor(labels[cluster], levels = labels)
  rownames(q) <- NULL
  list(players = q,
       centers = data.frame(type = factor(labels, levels = labels),
                            players = as.integer(table(cluster)), centers,
                            row.names = NULL, check.names = FALSE))
}
