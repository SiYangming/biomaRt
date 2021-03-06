###########################################################
## Functions for caching
###########################################################

.createHash <- function(mart, attributes, filters, values, uniqueRows = TRUE, bmHeader = FALSE) {
    
    ## if we are using the current version Ensembl URL
    ## swap for the archive version so we can check when it is outdated
    host <- martHost(mart)
    if(grepl("(www|uswest|useast|asia)\\.ensembl\\.org", host)) {
        archives <- biomaRt::listEnsemblArchives()
        host <- archives[which(archives$current_release == "*"), "url"]
    }
    
    attributes <- paste( sort(attributes), collapse = "" )
    ## need to keep the filters and values in the same order
    ## so create a single index for reordering both
    idx <- order(filters)
    filters <- paste( filters[idx], collapse = "" )
    if(is.list(values)) {
        values <- values[idx]
        values <- unlist(lapply(values, sort))
    } else {
        values <- sort(values)
    }
    values <- paste( values, collapse = "" )    
    
    combined <- paste(c(host, mart@biomart, mart@dataset, attributes, filters, values, uniqueRows, bmHeader), 
                      collapse = "_")
    paste0("biomaRt_", 
           as(openssl::md5(combined), "character"))
}

#' @param bfc Object of class BiocFileCache, created by a call to 
#' BiocFileCache::BiocFileCache()
#' @param hash unique hash representing a query.
.addToCache <- function(bfc, result, hash) {
    tf <- tempfile()
    saveRDS(result, file = tf)
    bfcadd(bfc, rname = hash, fpath = tf, action = "copy")
    file.remove(tf)
}

#' @param bfc Object of class BiocFileCache, created by a call to 
#' BiocFileCache::BiocFileCache()
#' @param hash unique hash representing a query.
.readFromCache <- function(bfc, hash) {

    cache_hits <- bfcquery(bfc, hash, field = "rname")
    if(nrow(cache_hits) > 1) {
        stop("Multiple cache results found.",
             "\nPlease clear your cache by running biomartCacheClear()")
    } else {
        rid <- cache_hits$rid
        result <- readRDS( bfc[[ rid ]] )
        return(result)
    }
}

#' @param bfc Object of class BiocFileCache, created by a call to 
#' BiocFileCache::BiocFileCache()
#' @param hash unique hash representing a query.
#' 
#' This function returns TRUE if a record with the requested hash already 
#' exists in the file cache, otherwise returns FALSE.
#' @keywords Internal
.checkCache <- function(bfc, hash, verbose = FALSE) {
    res <- bfcquery(bfc, query = hash, field = "rname")
    as.logical(nrow(res))
}

.biomartCacheLocation <- function() {
    Sys.getenv(x = "BIOMART_CACHE", 
               unset = rappdirs::user_cache_dir(appname="biomaRt"))
}

biomartCacheClear <- function() {
    cache <- .biomartCacheLocation()
    bfc <- BiocFileCache::BiocFileCache(cache, ask = FALSE)
    removebfc(bfc, ask = FALSE)
}

biomartCacheInfo <- function() {
    cache <- .biomartCacheLocation()
    
    if(!file.exists(cache)) {
        message("biomaRt cache uninitialized\n", 
                "- Location: ", cache)
    } else {
        
        bfc <- BiocFileCache::BiocFileCache(cache, ask = FALSE)
        files <- bfcinfo(bfc)$rpath
        total_size <- sum(file.size(files))
        size_obj <- structure(total_size, class = "object_size")
    
        message("biomaRt cache\n", 
                "- Location: ", cache, "\n",
                "- No. of files: ", length(files), "\n",
                "- Total size: ", format(size_obj, units = "auto"))
    }
    return(invisible(cache))
}

