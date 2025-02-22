#' Summarise lmFit FDR results
#'
#' Summarise number of significant genes at various FDR cutoffs. Can split by up/down fold change as well.
#'
#' @param fdr data.frame output by kimma::extract_lmFit( )
#' @param fdr.cutoff numeric vector of FDR cutoffs to summarise at
#' @param p.cutoff numeric vector of P-value cutodds to summarise at. No FDR summary given if p.cutoff is provided
#' @param FCgroup logical if should separate summary by up/down fold change groups
#' @param intercept logical if should include intercept variable in summary
#'
#' @return Data frame with total significant genes for each variable at various FDR cutoffs
#' @export
#'
#' @examples
#'# Run limma model
#' design <- model.matrix(~ virus, data = example.voom$targets)
#' fit <- limma::eBayes(limma::lmFit(example.voom$E, design))
#'
#' ## Get results
#' model_results <- extract_lmFit(design = design, fit = fit)
#'
#' # Summarise results
#' summarise_lmFit(fdr = model_results, fdr.cutoff = c(0.05, 0.5), FCgroup = TRUE)
#'

summarise_lmFit <- function(fdr, fdr.cutoff = c(0.05,0.1,0.2,0.3,0.4,0.5),
                            p.cutoff = NULL,
                            FCgroup = FALSE, intercept = FALSE){
  adj.P.Val <- geneName <- group <- n <- variable <- fdr.var <- NULL
  if(intercept){
    fdr.filter <- fdr
  } else{
    fdr.filter <- dplyr::filter(fdr, variable != '(Intercept)') %>%
      droplevels()
  }

  # Use p-values if specified
  if(!is.null(p.cutoff)){
    fdr.cutoff <- p.cutoff
    fdr.var <- "P.Value"
  } else {
    fdr.var <- "adj.P.Val"
  }

    if(FCgroup){
    #Blank df for results
    result <- data.frame()

    for(FDR.i in fdr.cutoff){
      name.fdr <- paste("fdr",FDR.i, sep="_")
      #Calculate total, nonredundant signif genes at different levels
      total.temp <- fdr.filter %>%
        dplyr::filter(get(fdr.var) <= FDR.i) %>%
        dplyr::distinct(geneName, FCgroup) %>%
        dplyr::count(FCgroup, .drop = FALSE) %>%
        dplyr::mutate(variable = "total (nonredundant)")

      #Summarize signif genes per variable at various levels
      group.temp <- fdr.filter %>%
        dplyr::filter(get(fdr.var) <= FDR.i) %>%
        dplyr::count(variable, FCgroup, .drop = FALSE)

      result.temp <- dplyr::bind_rows(total.temp, group.temp) %>%
        dplyr::mutate(group = name.fdr)

      result <- dplyr::bind_rows(result, result.temp)
    }
    } else {
      #Blank df for results
      result <- data.frame()

      for(FDR.i in fdr.cutoff){
        name.fdr <- paste("fdr",FDR.i, sep="_")
        #Calculate total, nonredundant signif genes at different levels
        total.temp <- fdr.filter %>%
          dplyr::filter(get(fdr.var) <= FDR.i) %>%
          dplyr::distinct(geneName) %>%
          dplyr::mutate(variable = "total (nonredundant)") %>%
          dplyr::count(variable, .drop = FALSE)

        #Summarize signif genes per variable at various levels
        group.temp <- fdr.filter %>%
          dplyr::filter(get(fdr.var) <= FDR.i) %>%
          dplyr::count(variable, .drop = FALSE)

        #If 0 genes, make zero df
        if(nrow(total.temp)==0){
          result.temp <- data.frame(variable=c(unique(fdr.filter$variable),
                                               "total (nonredundant)"),
                                    n=0,
                                    model=unique(fdr.filter$model),
                                    group=name.fdr)
        } else {
          result.temp <- dplyr::bind_rows(total.temp, group.temp) %>%
            dplyr::mutate(group = name.fdr)
        }

        result <- dplyr::bind_rows(result, result.temp)
      }
    }
  #Format to wide output
  result.format <- tidyr::pivot_wider(result, names_from = group, values_from = n) %>%
    dplyr::mutate(variable = forcats::fct_relevel(factor(variable), "total (nonredundant)",
                                                  after=Inf)) %>%
    dplyr::arrange(variable)

  #rename for P-value if specified
  if(!is.null(p.cutoff)) {
    result.format <- result.format %>%
      dplyr::rename_all(~gsub("fdr_","p_",.))
  }

  return(result.format)
}
