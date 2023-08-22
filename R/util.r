#' Construct the ZeroMQ host address
#'
#' @param node   Node or device name
#' @param ports  Range of ports to consider
#' @param n      How many addresses to return
#' @return       The possible addresses as character vector
#' @keywords internal
# @param short  Whether to use unqualified host name (before first dot)
host = function(node=getOption("clustermq.host", Sys.info()["nodename"]),
                ports=6000:9999, n=100) {
    utils::head(sample(sprintf("tcp://%s:%i", node, ports)), n)
}

#' Fill a template string with supplied values
#'
#' @param template  A character string of a submission template
#' @param values    A named list of key-value pairs
#' @param required  Keys that must be present in the template (default: none)
#' @return          A template where placeholder fields were replaced by values
#' @keywords internal
fill_template = function(template, values, required=c()) {
    pattern = "\\{\\{\\s*([^\\s]+)\\s*(\\|\\s*[^\\s]+\\s*)?\\}\\}"
    match_obj = gregexpr(pattern, template, perl=TRUE)
    matches = regmatches(template, match_obj)[[1]]

    no_delim = substr(matches, 3, nchar(matches)-2)
    kv_str = strsplit(no_delim, "|", fixed=TRUE)
    keys = sapply(kv_str, function(s) gsub("\\s", "", s[1]))
    vals = sapply(kv_str, function(s) gsub("\\s", "", s[2]))
    if (! all(required %in% keys))
        stop("Template keys required but not provided: ",
             paste(setdiff(required, keys), collapse=", "))

    upd = keys %in% names(values)
    vals[upd] = unlist(values)[keys[upd]]
    if (any(is.na(vals)))
        stop("Template values required but not provided: ",
             paste(unique(keys[is.na(vals)]), collapse=", "))

    for (i in seq_along(matches))
        template = sub(matches[i], vals[i], template, fixed=TRUE)
    template
}

#' Lookup table for return types to vector NAs
#'
#' @keywords internal
vec_lookup = list(
    "list" = list(NULL),
    "logical" = as.logical(NA),
    "numeric" = NA_real_,
    "integer" = NA_integer_,
    "character" = NA_character_,
    "lgl" = as.logical(NA),
    "dbl" = NA_real_,
    "int" = NA_integer_,
    "chr" = NA_character_
)

#' Wraps an error in a condition object
#'
#' @keywords internal
wrap_error = function(call) {
    structure(class = c("worker_error", "condition"),
              list(message=geterrmessage(), call=call));
}

#' Message format for logging
#'
#' @keywords internal
msg_fmt = function(verbose=TRUE) {
    if (verbose)
        function(...) base::message(format(Sys.time(), "%Y-%m-%d %H:%M:%OS9 | "), ...)
    else
        function(...) invisible(NULL)
}
