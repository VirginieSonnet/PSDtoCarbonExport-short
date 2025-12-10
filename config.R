# configutation file = links to major repositories to be used within the project

#path_root = "/home/onyxia/work/PSDtoCarbonExport-short"
path_root = "/remote/complex/home/vsonnet/projects/complex/2025_proj_DTO-Bioflow/PSDtoCarbonExport-short"

cfg <- list(
  # ---- project-local paths ----
  # project = list(
  #  root      = "~/complex/projects/complex/2025_proj_DTO-Bioflow/PSDtoCarbonExport-short",
  # ),
  
  # ---- project-local paths ----
  project = list(
    data      = file.path(path_root,"data"),
    functions = file.path(path_root,"functions")
  )
)



#path_cephalopod <- file.path(cfg$project$functions,"CEPHALOPOD")
path_cephalopod <- "/remote/complex/home/vsonnet/shared/methods/modeling/CEPHALOPOD"

#path_cephaloplot <- file.path(cfg$project$functions,"Cephaloplot")
path_cephaloplot <- "/remote/complex/home/vsonnet/packages/visualization/Cephaloplot"
