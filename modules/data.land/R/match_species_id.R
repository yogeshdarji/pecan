#' Match BETY species ID.
#'
#' Parses species codes in input data and matches them with the BETY species ID.
#' 
#' \code{format_name} can be one of the following:
#' \describe{
#'  \item{\code{usda}}{USDA Plants database symbol (e.g. QURU, TSCA)}
#'  \item{\code{fia}}{FIA species code}
#'  \item{\code{latin_name}}{Scientific name, as "Genus species"; must match exactly and unambiguously to \code{scientificname} field in BETY}
#'  \item{\code{custom}}{A data frame matching BETY IDs (column name \code{bety_species_id}) to input codes (column name \code{input_code}). This data frame must be passed via the \code{translation_table} argument.}
#' }
#' 
#' @param input_codes Character vector of species codes
#' @param format_name Species code format name (see details)
#' @param bety \code{dplyr} \code{src} object containing BETY connection 
#' @param translation_table Data frame with custom translation table (see details).
#' @return \code{data.frame} containing the following columns:
#' \describe{
#'  \item{\code{input_code}}{Character provided as input}
#'  \item{\code{bety_species_id}}{Big integer species ID, unique and specific to BETY}
#'  \item{\code{genus}}{Genus part of Latin name, from BETY}
#'  \item{\code{species}}{Species part of Latin name, from BETY}
#' }
#' @author Alexey Shiklomanov <ashiklom@bu.edu>
#' @examples
#' bety <- dplyr::src_postgres(dbname = 'bety',
#'                        user = 'bety',
#'                        password = 'bety',
#'                        host = 'localhost')
#' input_codes <- c('ACRU', 'PIMA', 'TSCA')
#' format_name <- 'usda'
#' match_species_id(input_codes = input_codes,
#'                  format_name = format_name,
#'                  bety = bety)
#'                  
#' @export
match_species_id <- function(input_codes, format_name = 'custom', bety = NULL, translation_table = NULL, ...) {
    # Relate format names to BETY columns
    formats_dict <- c('usda' = 'Symbol',
                      'fia' = 'spcd',
                      'latin_name' = 'scientificname', 
                      'custom' = 'custom')
    if (!format_name %in% names(formats_dict)) {
        PEcAn.utils::logger.severe('format_name "', format_name, '" not found. ',
                                   'Please use one of the following: ',
                                   paste(names(formats_dict), collapse = ', '))
    }
    if (!is.null(translation_table)) {
        msg2 <- c('Found the following columns: ', 
                  paste(colnames(translation_table), collapse = ', '))
        if (!'input_code' %in% colnames(translation_table)) {
            PEcAn.utils::logger.severe('Custom translation table must have column "input_code". ', msg2)
        } else if (!'bety_species_id' %in% colnames(translation_table)) {
            PEcAn.utils::logger.severe('Custom translation table must have column "bety_species_id". ', msg2)
        } else {
            if (any(grepl('^(genus|species)$', colnames(translation_table)))) {
                PEcAn.utils::logger.warn('"genus" or "species" columns found in translation table. ',
                                         'Because these also match the BETY table, ',
                                         'they will be ignored by the merge, but their names will ',
                                         'be appended with ".translation_table" for disambiguation')
            }
            bety_species <- dplyr::tbl(bety, 'species') %>%
                dplyr::filter_(~id %in% translation_table[['bety_species_id']]) %>%
                dplyr::select_('bety_species_id' = 'id', 'genus', 'species') %>%
                dplyr::collect()
            translation <- dplyr::left_join(translation_table, bety_species, 
                                            by = 'bety_species_id',
                                            suffix = c('.translation_table', ''))
        }
    } else {
        column <- formats_dict[format_name]
        filter_cri <- lazyeval::interp(~ col %in% codes, 
                                       col = as.name(column),
                                       codes = input_codes)
        translation <- dplyr::tbl(bety, 'species') %>%
            dplyr::filter_(filter_cri) %>%
            dplyr::select_('bety_species_id' = 'id', 'genus', 'species',
                           'input_code' = column) %>%
            dplyr::collect()
    }
    input_table <- data.frame(input_code = input_codes, stringsAsFactors = FALSE)
    merge_table <- dplyr::left_join(input_table, translation)
    return(merge_table)
} # match_species_id

