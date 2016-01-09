infuser = import_package('infuser')

#' A template string used to submit jobs
template = "#BSUB-J {{ job_name }}        # name of the job / array jobs
#BSUB-g {{ job_group | /rzmq }}           # group the job belongs to
#BSUB-o {{ log_file | /dev/null }}        # output is sent to logfile, stdout + stderr by default
#BSUB-P research-rh6                      # Job queue
#BSUB-W 10080                             # Walltime in minutes
#BSUB-M {{ memory | 4096 }}               # Memory requirements in Mbytes
#BSUB-R rusage[mem={{ memory | 4096  }}]  # Memory requirements in Mbytes
#BSUB-R select[panfs_nobackup_research]

R --no-save --no-restore --args {{ args }} < '{{ rscript }}'
"

#' Number submitted jobs consecutively
job_num = 1
job_group = NULL

#' Submits one job to the queuing system
#' @param address     An rzmq-compatible address to connect the worker to
#' @param memory      The amount of memory (megabytes) to request
#' @param log_worker  Create a log file for each worker
submit_job = function(address, memory, log_worker=FALSE) {
    if (!is.null(get("job_group", envir=parent.env())))
        stop("job_group already set")
    group_id = rev(strsplit(address, ":")[[1]])[1]

    values = list(
        job_name = paste0("rzmq", group_id, "-", job_num),
        job_group = paste("/rzmq", group_id, sep="/"),
        rscript = module_file("worker.r"),
        args = paste(address, memory)
    )

    assign("job_group", values$job_group, envir=parent.env())

    if (log_worker)
        values$log_file = paste0(values$job_name, ".log")

    job_input = infuser$infuse(template, values)
    system("bsub", input=job_input, ignore.stdout=TRUE)
    job_num = job_num + 1
}

#' Will be called when exiting the `hpc` module's main loop, use to cleanup
cleanup = function() {
    job_group = get("job_group", envir=parent.env())
    system(paste("bkill -g", job_group, "0"), ignore.stdout=TRUE)
}
