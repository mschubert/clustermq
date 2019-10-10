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

#' Construct the ZeroMQ host
#'
#' @param short  whether to use unqualified host name (before first dot)
#' @return  the host name as character string
#' @keywords internal
host = function(short=getOption("clustermq.short.host", TRUE), interface=getOption("clustermq.network.interface", NULL)) {
    if (is.null(interface))
        host = Sys.info()["nodename"]
        if (short)
            host = strsplit(host, "\\.")[[1]][1]
    else
        # If the user has specified an interface name, get the host's IP address
        # on that particular interface
        network_interface_details = system2("ifconfig", args=(interface), stdout=TRUE, stderr=FALSE)
        inet_string = grep(" inet ", network_interface, value=TRUE)
        inet_vector = strsplit(inet_string, "\\s+")[[1]]
        pos = match("inet", inet_vector)
        host = inet_vector[pos+1]
    host
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
