#' ============================= MASTER SCRIPT =================================
#' For the Blue-Cloud 2026 project workbench
#' A. Schickele 2024, modified by V. Sonnet 2025
#' =============================================================================

# --- 0. Start up and load functions
# All will be called in the config file later
rm(list=ls())
closeAllConnections()
source(here::here("config.R"))
setwd(path_cephalopod)
if(!require("reticulate")){install.packages("reticulate")}
source(file = "./code/00_config.R")
run_name <- "PSD-short"

MAX_CLUSTER = 20

# --- 1. List the available species
# Within the user defined selection criteria
list_bio <- list_bio_wrapper(FOLDER_NAME = run_name,
                             DATA_SOURCE = file.path(cfg$project$data,"cephalopod_power_law_coefficients.csv"), # occurrence ; abundance ; biomass ; MAG; or path to a .csv file
                             SAMPLE_SELECT = list(MIN_SAMPLE = 50, TARGET_MIN_DEPTH = 0, TARGET_MAX_DEPTH = 300, START_YEAR = 1950, STOP_YEAR = 2026))

# ------------------------------------------------------------------------------
# --- USER INPUT: Define the list of species to consider
# To extract all species available in a .csv file
sp_list <- list_bio %>%
  dplyr::select(worms_id) %>% 
  unique() %>% pull() %>% .[!grepl("No match", .)]

# ------------------------------------------------------------------------------

# --- 2. Create the output folder, initialize parallelisation and parameters
# (1) Create an output folder containing all species-level runs, (2) Stores the 
# global parameters in an object, (3) Builds a local list of monthly raster
subfolder_list <- run_init(FOLDER_NAME = run_name,
                           SP_SELECT = sp_list,
                           WORMS_CHECK = FALSE,
                           FAST = FALSE,
                           LOAD_FROM = NULL,
                           DATA_TYPE = "continuous", # presence_only ; continuous ; proportions
                           ENV_VAR = NULL,
                           ENV_PATH = file.path(cfg$project$data,"Schickele_climatologies"), # replace by local path to environmental predictors : https://data.d4science.net/m9WC
                           METHOD_PA = "density",
                           PER_RANDOM = 0,
                           PA_ENV_STRATA = TRUE,
                           OUTLIER = FALSE,
                           RFE = TRUE,
                           ENV_COR = 0.8,
                           NFOLD = 3,
                           FOLD_METHOD = "lon",
                           MODEL_LIST = c("GLM","MLP","BRT","GAM","SVM","RF"), # light version
                           LEVELS = 3,
                           TARGET_TRANSFORMATION = NULL,
                           ENSEMBLE = TRUE,
                           N_BOOTSTRAP = 10,
                           CUT = NULL)

# --- 3. Query biological data
# Get the biological data of the species we wish to model
mcmapply(FUN = query_bio_wrapper,
         FOLDER_NAME = run_name,
         SUBFOLDER_NAME = subfolder_list,
         mc.cores = min(length(subfolder_list), MAX_CLUSTERS), USE.NAMES = FALSE, mc.preschedule = FALSE)

# --- 4. Query environmental data
# This functions returns an updated subfolder_list object to avoid computing
# species with less than the user defined minimum occurrence number
subfolder_list <- mcmapply(FUN = query_env,
                  FOLDER_NAME = run_name,
                  SUBFOLDER_NAME = subfolder_list,
                  mc.cores = min(length(subfolder_list), MAX_CLUSTERS), mc.preschedule = FALSE) %>% 
  unlist() %>% 
  na.omit(subfolder_list) %>% 
  .[grep("Error", ., invert = TRUE)] %>% # to exclude any API error or else
  as.vector()

# --- 5. Generate pseudo-absences if necessary
mcmapply(FUN = pseudo_abs,
         FOLDER_NAME = run_name,
         SUBFOLDER_NAME = subfolder_list,
         mc.cores = min(length(subfolder_list), MAX_CLUSTERS), USE.NAMES = FALSE, mc.preschedule = FALSE)

# --- 6. Outliers, Environmental predictor and MESS check 
# This functions returns an updated subfolder_list with meaningful feature set
subfolder_list <- mcmapply(FUN = query_check,
                           FOLDER_NAME = run_name,
                           SUBFOLDER_NAME = subfolder_list,
                           mc.cores = min(length(subfolder_list), MAX_CLUSTERS), mc.preschedule = FALSE) %>% 
  unlist() %>% 
  na.omit(subfolder_list) %>% 
  as.vector()

# --- 7. Generate split and re sampling folds
mcmapply(FUN = folds,
         FOLDER_NAME = run_name,
         SUBFOLDER_NAME = subfolder_list,
         mc.cores = min(length(subfolder_list), MAX_CLUSTERS), USE.NAMES = FALSE, mc.preschedule = FALSE)

# --- 8. Hyper parameters to train
hyperparameter(FOLDER_NAME = run_name)

# --- 9. Model fit
mcmapply(FUN = model_wrapper,
         FOLDER_NAME = run_name,
         SUBFOLDER_NAME = subfolder_list,
         mc.cores = min(length(subfolder_list), MAX_CLUSTERS), USE.NAMES = FALSE, mc.preschedule = FALSE)

# --- 10. Model evaluation
# Performance metric and variable importance
mcmapply(FUN = eval_wrapper,
         FOLDER_NAME = run_name,
         SUBFOLDER_NAME = subfolder_list,
         mc.cores = min(length(subfolder_list), MAX_CLUSTERS), USE.NAMES = FALSE, mc.preschedule = FALSE)

# ---11. Model projections
mcmapply(FUN = proj_wrapper,
         FOLDER_NAME = run_name,
         SUBFOLDER_NAME = subfolder_list,
         mc.cores = min(length(subfolder_list), MAX_CLUSTERS), USE.NAMES = FALSE, mc.preschedule = FALSE)

# --- 12. Output plots
# --- 12.1. Standard maps per algorithms
mcmapply(FUN = standard_maps,
         FOLDER_NAME = run_name,
         SUBFOLDER_NAME = subfolder_list,
         mc.cores = min(length(subfolder_list), MAX_CLUSTERS), USE.NAMES = FALSE, mc.preschedule = FALSE)

# --- 12.4 User synthesis
user_synthesis(FOLDER_NAME = run_name)

# --- END --- 