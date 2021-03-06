context("Test h2o GLM")

if(FALSE) {
  setwd(".."); setwd(".."); getwd()
  library("devtools")
  document()
  load_all("./") # load all R files in /R and datasets in /data. Ignores NAMESPACE:
  setwd("..");
  install("sl3", build_vignettes = FALSE, dependencies = FALSE) # INSTALL W/ devtools:
  Sys.setenv(JAVA_HOME="/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/")
}


library(testthat)
library(sl3)
library(h2o)
h2o.init(nthread = 1)
# library(data.table)
# library(origami)
library(SuperLearner)
set.seed(1)

data(cpp)
cpp <- cpp[!is.na(cpp[, "haz"]), ]
covars <- c("apgar1", "apgar5", "parity", "gagebrth", "mage", "meducyrs", "sexn")
cpp[is.na(cpp)] <- 0
outcome <- "haz"

task <- sl3_Task$new(cpp, covariates = covars, outcome = outcome)
task$nodes$covariates

test_that("Lrnr_glm and Lrnr_h2o_glm learners give the same predictions", {
  h2o::h2o.no_progress()
  glm_learner <- Lrnr_glm$new()
  h2o_glm <- Lrnr_h2o_glm$new()
  GLM_fit <- glm_learner$train(task)
  glm_preds <- GLM_fit$predict()
  h2oGLM_fit <- h2o_glm$train(task)
  h2oGLM_preds <- h2oGLM_fit$predict()
  expect_true(is.vector(h2oGLM_preds))
  # print(sum(glm_preds-h2oGLM_preds))
  expect_true(all.equal(as.vector(glm_preds), as.vector(h2oGLM_preds)))
})

test_that("Lrnr_h2o_glm trains based on a subset of covariates (predictors)", {
  h2o::h2o.no_progress()
  h2o_glm <- Lrnr_h2o_glm$new(covariates = c("apgar1", "apgar5"))
  h2oGLM_fit <- h2o_glm$train(task)
  # print(h2oGLM_fit)
  # str(h2oGLM_fit$params)
  h2oGLM_preds_2 <- h2oGLM_fit$predict()
  expect_true(is.vector(h2oGLM_preds_2))

  glm.fit <- glm(haz ~ apgar1 + apgar5, data = cpp, family = stats::gaussian())
  glm_preds_2 <- as.vector(predict(glm.fit))

  # print(sum(glm_preds_2-h2oGLM_preds_2))
  expect_true(sum(h2oGLM_preds_2 - glm_preds_2) < 10^(-10), )
  expect_true(all.equal(as.vector(glm_preds_2), as.vector(h2oGLM_preds_2)))
})

test_that("Lrnr_h2o_glm defines interactions", {
  h2o::h2o.no_progress()
  h2o_glm <- Lrnr_h2o_glm$new(covariates = c("apgar1", "apgar5", "parity"),
                                      interactions = c("apgar1", "apgar5"))

  h2oGLM_fit <- h2o_glm$train(task)
  # print(h2oGLM_fit)
  # str(h2oGLM_fit$params)
  h2oGLM_preds_3 <- h2oGLM_fit$predict()
  expect_true(is.vector(h2oGLM_preds_3))

  glm.fit <- glm(haz ~ apgar1 + apgar5 + parity + apgar1:apgar5, data = cpp, family = stats::gaussian())
  # print(glm.fit)
  glm_preds_3 <- as.vector(predict(glm.fit))

  expect_true(sum(h2oGLM_preds_3 - glm_preds_3) < 10^(-10))
  expect_true(all.equal(as.vector(glm_preds_3), as.vector(h2oGLM_preds_3)))
})

test_that("Lrnr_h2o_glm works with screener", {
  h2o::h2o.no_progress()
  # example of learner chaining
  slscreener <- Lrnr_pkg_SuperLearner_screener$new("screen.glmnet")

  ## FAILS, because screener currently renames the covariates
  # h2o_glm <- Lrnr_h2o_glm$new(covariates = c("apgar1", "meducyrs"),
  #                                     interactions = list(c("apgar1", "meducyrs")))
  h2o_glm <- Lrnr_h2o_glm$new()
  screen_and_glm <- Pipeline$new(slscreener, h2o_glm)
  sg_fit <- screen_and_glm$train(task)
  # print(sg_fit)
})

test_that("Lrnr_h2o_glm works with stacking", {
  h2o::h2o.no_progress()
  glm_learner <- Lrnr_glm$new()
  h2o_glm <- Lrnr_h2o_glm$new()
  screen_and_glm <- Pipeline$new(Lrnr_pkg_SuperLearner_screener$new("screen.glmnet"), h2o_glm)
  SL.glmnet_learner <- Lrnr_pkg_SuperLearner$new(SL_wrapper = "SL.glmnet")

  # now lets stack some learners
  learner_stack <- Stack$new(glm_learner, h2o_glm, screen_and_glm, SL.glmnet_learner)
  stack_fit <- learner_stack$train(task)
  # print(stack_fit)
  preds <- stack_fit$predict()
  # print(head(preds))
})

## quasibinomial is broken is all recent releases of h2o
# test_that("Lrnr_h2o_glm works with quasibinomial and continuous outcomes in (0,1)", {
#   h2o::h2o.no_progress()
#   cpp_haz_01range <- cpp
#   cpp_haz_01range[["haz_01range"]] <- rep_len(c(.1,.2,.3,.4,.5,.6,.7,.8,.9), nrow(cpp))
#   task_01range <- sl3_Task$new(cpp_haz_01range, covariates = covars, outcome = "haz_01range")

#   h2o_glm <- Lrnr_h2o_glm$new(family = "quasibinomial")
#   h2oGLM_fit <- h2o_glm$train(task_01range)
#   preds_1 <- h2oGLM_fit$predict()
#   # print(h2oGLM_fit)

#   fglm_learner <- Lrnr_glm_fast$new(family = "quasibinomial")
#   fglm_fit <- fglm_learner$train(task_01range)
#   fglm_preds_2 <- fglm_fit$predict()

#   h2o_glm <- Lrnr_h2o_glm$new(family = "binomial")
#   expect_error(
#     h2oGLM_fit <- h2o_glm$train(task_01range)
#   )
# })

## quasibinomial is broken is all recent releases of h2o
test_that("Lrnr_h2o_glm works with binomial families for binary outcome and gives the same result as speedglm", {
  h2o::h2o.no_progress()
  cpp_hazbin <- cpp
  cpp_hazbin[["haz_bin"]] <- rep_len(c(0L,1L), nrow(cpp))
  task_bin <- sl3_Task$new(cpp_hazbin, covariates = covars, outcome = "haz_bin")

  # h2o_glm <- Lrnr_h2o_glm$new(family = "quasibinomial")
  # h2oGLM_fit <- h2o_glm$train(task_bin)
  # preds_1 <- h2oGLM_fit$predict()
  # # print(h2oGLM_fit)

  fglm_learner <- Lrnr_glm_fast$new(family = "quasibinomial")
  fglm_fit <- fglm_learner$train(task_bin)
  fglm_preds_2 <- fglm_fit$predict()

  h2o_glm <- Lrnr_h2o_glm$new(family = "binomial")
  h2oGLM_fit <- h2o_glm$train(task_bin)
  preds_2 <- h2oGLM_fit$predict()

  expect_true(all.equal(fglm_preds_2, preds_2))
  # print(h2oGLM_fit)
  # expect_true(all.equal(preds_1, preds_2))
})

test_that("Lrnr_h2o_glm works with different solvers", {
  h2o::h2o.no_progress()
  cpp_hazbin <- cpp
  cpp_hazbin[["haz_bin"]] <- rep_len(c(0L,1L), nrow(cpp))
  task_bin <- sl3_Task$new(cpp_hazbin, covariates = covars, outcome = "haz_bin")

  h2o_glm <- Lrnr_h2o_glm$new(family = "binomial", solver = "L_BFGS")
  h2oGLM_fit <- h2o_glm$train(task_bin)
  preds_1 <- h2oGLM_fit$predict()
  # print(h2oGLM_fit)

  h2o_glm <- Lrnr_h2o_glm$new(family = "binomial", solver = "IRLSM")
  h2oGLM_fit <- h2o_glm$train(task_bin)
  preds_1 <- h2oGLM_fit$predict()
  # print(h2oGLM_fit)

  h2o_glm <- Lrnr_h2o_glm$new(family = "binomial", solver = "COORDINATE_DESCENT")
  h2oGLM_fit <- h2o_glm$train(task_bin)
  preds_1 <- h2oGLM_fit$predict()
  # print(h2oGLM_fit)

  h2o_glm <- Lrnr_h2o_glm$new(family = "binomial", solver = "COORDINATE_DESCENT_NAIVE")
  h2oGLM_fit <- h2o_glm$train(task_bin)
  preds_1 <- h2oGLM_fit$predict()
  # print(h2oGLM_fit)
})


test_that("Lrnr_h2o_glm works with regularized regression and internal CV for lambda", {
  h2o::h2o.no_progress()
  cpp_hazbin <- cpp
  cpp_hazbin[["haz_bin"]] <- rep_len(c(0L,1L), nrow(cpp))
  task_bin <- sl3_Task$new(cpp_hazbin, covariates = covars, outcome = "haz_bin")
  h2o_glm <- Lrnr_h2o_glm$new(family = "binomial", alpha = 0.5, lambda_search = TRUE, nlambdas = 20,  nfolds = 5)
  h2oGLM_fit <- h2o_glm$train(task_bin)
  preds_1 <- h2oGLM_fit$predict()
  # print(h2oGLM_fit)
})

h2o::h2o.shutdown(prompt = FALSE)
