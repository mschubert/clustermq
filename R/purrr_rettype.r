#' Lookup table for return types to vector NAs
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
