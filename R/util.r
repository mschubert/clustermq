#' Binds a ZeroMQ socket to an available port in given range
#'
#' @param socket   An ZeroMQ socket object
#' @param range    Numbers to consider (e.g. 6000:8000)
#' @param iface    Interface to listen on
#' @param n_tries  Number of ports to try in range
#' @return         The port the socket is bound to
#' @keywords internal
bind_avail = function(socket, range, iface="tcp://*", n_tries=100) {
    ports = sample(range, n_tries)

    for (i in 1:n_tries) {
        addr = paste(iface, ports[i], sep=":")
        success = tryCatch({
            port_found = bind_socket(socket, addr)
        }, error = function(e) NULL)
        if (is.null(success))
            break
    }

    if (!is.null(success))
        stop("Could not bind after ", n_tries, " tries")

    ports[i]
}

#' Construct the ZeroMQ host address
#'
#' @param node   Node or device name
#' @param ports  Range of ports to consider
#' @param n      How many addresses to return
#' @param short  Whether to use unqualified host name (before first dot)
#' @return       The possible addresses as character vector
#' @keywords internal
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

#' Lookup table for return types to purrr functions
#'
#' @keywords internal
purrr_lookup = list(
    "list" = purrr::pmap,
    "logical" = purrr::pmap_lgl,
    "numeric" = purrr::pmap_dbl,
    "integer" = purrr::pmap_int,
    "character" = purrr::pmap_chr,
    "lgl" = purrr::pmap_lgl,
    "dbl" = purrr::pmap_dbl,
    "int" = purrr::pmap_int,
    "chr" = purrr::pmap_chr
)
