#cluster.functions = makeClusterFunctionsInteractive()
cluster.functions = makeClusterFunctionsLSF(file.path(module_file(), 'LSF.tmpl'))
mail.start = "none"
mail.done = "none"
mail.error = "first"
mail.from = "<lsf@ebi.ac.uk>"
mail.to = paste0("<", Sys.info()[["user"]], "@ebi.ac.uk>")
mail.control = list(smtpServer="mx1.ebi.ac.uk")

default.resources = list(
    queue = "research-rh6", 
    walltime = "10080",
#    memory = 1024
#    memory = 2048
    memory = "4096"
#    memory = "10240"
#    memory = "20480"
#    memory = "40960"
#    memory = "102400"
)

db.driver = "SQLite"
db.options = list(synchronous=2) #, cache_size=-102400)

#debug = TRUE
#staged.queries = FALSE

#raise.warnings = TRUE # treat warnings as errors
#max.concurrent.jobs = 900

