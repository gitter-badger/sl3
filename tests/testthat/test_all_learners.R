#define test dataset
data(mtcars)
task=sl3_Task$new(mtcars,covariates=c("cyl", "disp", "hp", "drat", "wt", "qsec", "vs", "am", "gear", "carb"),outcome="mpg")
task2=sl3_Task$new(mtcars,covariates=c("cyl", "disp", "hp", "drat", "wt", "qsec", "vs", "am", "gear", "carb"),outcome="mpg")


test_learner=function(learner, task){

	#test learner definition
  #this requires that a learner can be instantiated with only default arguments. Not sure if this is a reasonable requirement
	learner_obj=learner$new()
	print(sprintf("Testing Learner: %s",learner_obj$name))

	#test learner training
  fit_obj=learner_obj$train(task)
  test_that("Learner can be trained on data",expect_true(fit_obj$is_trained))

	#test learner prediction
  train_preds=fit_obj$predict()
  test_that("Learner can generate training set predictions",expect_equal(length(train_preds),nrow(task$X)))

  holdout_preds=fit_obj$predict(task2)
  test_that("Learner can generate holdout set predictions",expect_equal(train_preds,holdout_preds))

  #test learner chaining
  chained_task=fit_obj$chain()
  test_that("Chaining returns a task",expect_true(is(chained_task,"sl3_Task")))
  test_that("Chaining returns the correct number of rows",expect_equal(nrow(chained_task$X),nrow(task$X)))
}

test_learner(Lrnr_glm, task)
