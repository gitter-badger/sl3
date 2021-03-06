## ------------------------------------------------------------------------
## Faster GLM with h2o
## todo: add tests for 'offset_column' and 'weights_column' with h2o.glm()
## ------------------------------------------------------------------------

## Replace any arg in mainArgs if it also appears in userArgs
## Add any arg from userArgs that also appears in formals(fun) of function
replace_add_user_args <- function(mainArgs, userArgs, fun) {
  replaceArgs <- intersect(names(mainArgs), names(userArgs)) # captures main arguments that were overridden by user
  if(length(replaceArgs) > 0) {
    mainArgs[replaceArgs] <- userArgs[replaceArgs]
    userArgs[replaceArgs] <- NULL
  }
  newArgs <- intersect(names(formals(fun)), names(userArgs)) # captures any additional args given by user that are not in mainArgs
  if (length(newArgs) > 0) {
    mainArgs <- c(mainArgs, userArgs[newArgs])
  }
  return(mainArgs)
}

## Upload input data as h2o.Frame
## Allows to subset the taks$X data.table by a smaller set of covariates if spec'ed in params
define_h2o_X = function(task, covariates, params) {
  op <- options("h2o.use.data.table"=TRUE)
  # op <- options("datatable.verbose"=TRUE, "h2o.use.data.table"=TRUE)
  X <- h2o::as.h2o(task$data[,c(covariates, task$nodes$outcome), with=FALSE, drop=FALSE])
  # X <- fast.load.to.H2O(data$get.dat.sVar(subset_idx, covars = load_var_names), destination_frame = destination_frame)
  # self$outfactors <- as.vector(h2o::h2o.unique(X[, task$nodes$outcome]))
  # if (classify && length(self$outfactors) > 2L) stop("Cannot run binary regression/classification for outcome with more than 2 categories")
  # if (classify) X[, task$nodes$outcome] <- h2o::as.factor(X[, task$nodes$outcome])\
  options(op)
  return(X)
}

#' @importFrom assertthat assert_that is.count is.flag
#' @export
#' @rdname undocumented_learner
Lrnr_h2o_glm <- R6Class(classname = "Lrnr_h2o_glm", inherit = Lrnr_base, portable = TRUE, class = TRUE, private = list(
  .covariates = NULL,

  .train = function(task) {
    params <- self$params
    if ("family" %in% names(params)) {
      if (is.function(params[["family"]])) {
        params[["family"]] <- params[["family"]]()[["family"]]
      }
    } else {
      params[["family"]] <- "gaussian"
    }

    if (inherits(connectH2O <- try(h2o::h2o.getConnection(), silent = TRUE), "try-error")) {
        # if (gvars$verbose)
        message("No active connection to an H2O cluster has been detected.
Will now attempt to initialize a local h2o cluster.
In the future, please run `h2o::h2o.init()` prior to model training with h2o.")
        h2o::h2o.init()
    }

    private$.covariates <- task$nodes$covariates
    if ("covariates" %in% names(params)) {
      private$.covariates <- intersect(private$.covariates, params$covariates)
    }
    X <- define_h2o_X(task, private$.covariates, params)
    # if (gvars$verbose) h2o::h2o.show_progress() else h2o::h2o.no_progress()
    mainArgs <- list(x = private$.covariates,
                     y = task$nodes$outcome,
                     training_frame = X,
                     intercept = TRUE,
                     standardize = TRUE,
                     lambda = 0L,
                     max_iterations = 100,
                     ignore_const_cols = FALSE,
                     missing_values_handling = "Skip")

    mainArgs <- replace_add_user_args(mainArgs, params, fun = h2o::h2o.glm)
    fit_object <- do.call(h2o::h2o.glm, mainArgs)

    ## assign the fitted coefficients in correct order (same as predictor order in x)
    ## NOT USED FOR NOW
    # out_coef <- vector(mode = "numeric", length = length(x)+1)
    # out_coef[] <- NA
    # names(out_coef) <- c("Intercept", x)
    # out_coef[names(fit_object@model$coefficients)] <- fit_object@model$coefficients

    return(fit_object)
  },

  .predict = function(task = NULL) {
    X <- define_h2o_X(task, private$.covariates, self$params)
    predictions <- h2o::h2o.predict(private$.fit_object, X)
    if ("p1" %in% colnames(predictions)) {
      predictions <- as.vector(predictions[,"p1"])
    } else {
      predictions <- as.vector(predictions[,"predict"])
    }
    # predictions <- as.data.table(predictions)
    return(predictions)
}
), )