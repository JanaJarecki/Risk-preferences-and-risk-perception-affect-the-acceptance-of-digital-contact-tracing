# ==========================================================================
# File: statistical-analysis
# Analyzes the fitted models
# Author: Jana B. Jarecki & Rebecca Albrecht
# ==========================================================================
if (!require(pacman)) install.packages("pacman")
pacman::p_load(data.table, brms, projpred, bayesplot, standardize, mice, BayesFactor)
if (rstudioapi::isAvailable()) { setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) }


# Load data ---------------------------------------------------------------
d <- fread("../../data/processed/data.csv")

# Factors -------------------------------------------------------------------
fac <- c("has_work", "income_loss", "is_infected", "was_infected")
d[, (fac) := lapply(.SD, factor, labels=c("no", "yes")), .SDcols = fac]
d[, homeoffice := factor(homeoffice, labels = c("no", "yes", "partially"))]
d[, female := factor(female, labels = c("male", "female", "no response"))]


# Model predictor selection --------------------------------------------------
dep_var <- "accept_index"
dep_var <- "comply_index"
indep_vars <- c("perc_risk_health", "perc_risk_data", "perc_risk_econ", "seek_risk_general", "seek_risk_health", "seek_risk_data", "seek_risk_economy", "honhum_score", "svo_angle", "iwah_community", "iwah_swiss", "iwah_world")
# Note: only uing 'has_work', not 'had_work', because correlation = 0.80
contr_vars <- c("safebehavior_score", "know_health_score", "know_econ", "female", "age", "education", "community_imputed", "household", "was_infected", "is_infected", "has_symptoms", "income_imputed", "wealth_imputed", "has_work", "income_loss", "homeoffice", "policy_score", "mhealth_score", "tech_score", "compreh_score")
d <- d[, .SD, .SDcols = c(dep_var, indep_vars, contr_vars)]


# Impute missing income and wealth variables ----------------------------------
d[, summary(.SD), .SDcols = c("income_imputed", "wealth_imputed")] #140, 175 NA
d[, income_imputed := fifelse(is.na(income_imputed), median(income_imputed, na.rm=T), income_imputed)]
d[, wealth_imputed := fifelse(is.na(wealth_imputed), median(wealth_imputed,na.rm=T), income_imputed)]
# @todo use 'mic' package to do imputation based on better stats technique


# Standardize variables -------------------------------------------------------
formula <- reformulate(
  termlabels = c(indep_vars, contr_vars),
  response = dep_var)
sobj <- standardize(formula = formula, d)
# Important:
# 'sobj$data' must be used as data from here on



# Variable selection procedure -----------------------------------------------
# using leave-one-out cross-validation and Lasso (L1) penalization
# 1. Setup
n <- nrow(sobj$data) # 757
nc <- ncol(sobj$data) # 33
# Piironen and Vehtari (2017): the prior for the global shrinkage parameter is defined from the prior guess for the number of variables that matter
p0 <- length(indep_vars) # prior guess: number of relevant variables
tau0 <- p0/(nc-p0) * 1/sqrt(n) # scale for tau (notice that stan_glm will automatically scale this by sigma)
prior_coeff <- set_prior(horseshoe(scale_global = tau0, scale_slab = 1)) # regularized horseshoe prior


# 2. Fit full model
# file.remove("fit_full.rds") # if you want to re-fit the model, run this
fit <- brm(formula = formula, family = gaussian(), data = sobj$data,
  prior = prior_coeff, save_all_pars = TRUE, sample_prior = "yes",
  file = paste0("fitted_models/", dep_var, "_fit_full"), iter = 8000)
# @todo update model fitting because of errors!
# @body
# Warning messages:     
# 1: In system(paste(CXX, ARGS), ignore.stdout = TRUE, ignore.stderr = TRUE):
#   'C:/rtools40/usr/mingw_/bin/g++' not found
# 2: There were 101 divergent transitions after warmup. See                                               
# http://mc-stan.org/misc/warnings.html#divergent-transitions-after-warmup
# to find out why this is a problem and how to eliminate them.                                            
# 3: Examine the pairs() plot to diagnose sampling problems


# 3.a) Perform variable selection on training data
# Penalty of 0 = var is selected first, Inf = var is never selected
#   * 0 for independent vars that are theoretically motivated
#   * 1 for control vars
betas <- grep("^b", parnames(fit), value=TRUE)[-1]
penalty <- rep(1, length(betas))
penalty[match(indep_vars, gsub("b_", "", betas))] <- 0

# Optional
# Forward search & Lasso L1-penalty to find variable order (Tran et al., 2012)
# vs <- varsel(fit,
#   method = "L1",
#   penalty = penalty)
# vs$vind # variables ordered as they enter during the search


# 3.b) Perform variable selection using cross-validation
cvs <- cv_varsel(fit,
  method = "L1",
  penalty = penalty)
saveRDS(cvs, paste0("fitted_models/", dep_var, "_variable_selection.rds"))

# model size suggested by the program
nvar <- suggest_size(cvs)

# Correlation acceptance vs. compliance
library(BayesFactor)
plot(d$accept_index, d$comply_index)
mean(d$comply_index)
sd(d$comply_index)
mean(d$accept_index)
sd(d$accept_index)
mean(d$comply_index>=3)
mean(d$comply_index>=4)
mean(d$accept_index>=3)
mean(d$accept_index>=4)
cor(d$accept_index, d$comply_index)
