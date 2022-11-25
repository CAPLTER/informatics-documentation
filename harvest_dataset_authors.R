#' @title Query and format a table of knb-lter-cap dataset authors in the EDI
#' repository
#'
#' @description This is a short workflow to harvest knb-lter-cap dataset
#' authors in the EDI repository. Two example queries are prented, one for all
#' datasets under that scope and another only for datsets published 2012-2022.
#' Of course, the spectrum of other query parameters is endless. Additional
#' tooling is provided to format the data into a more resonable structure and
#' format.
#'
#' @note While querying the EDI data repository is exhaustive, processing with
#' \code{harvest_creators} and the tidying here is most definitely not. The
#' purpose here is for a approximate survey of dataset authors only, and the
#' workflow should be adjusted accordingly if a full accounting is required.
#'
#' @return A tibble of knb-lter-cap dataset creators
#'
cap_packages <- EDIutils::search_data_packages(query = "q=scope:knb-lter-cap&fl=packageid") # query all knb-lter-cap
cap_packages <- EDIutils::search_data_packages(query = "defType=edismax&q=*:*&fq=-scope:ecotrends&fq=-scope:lter-landsat*&fq=pubdate:%5B2012-01-01T00:00:00Z/DAY+TO+2022-11-25T00:00:00Z/DAY%5D&fq=scope:(knb-lter-cap)&fl=packageid&debug=false") # query all knb-lter-cap with pub date 2012-2022

harvest_creators <- function(edi_data_package) {

  metadata  <- EDIutils::read_metadata(
    packageId = edi_data_package,
    env = "production"
  )

  creators <- xml2::xml_find_all(
    x     = metadata,
    xpath = ".//creator"
  )

  creators <- xml2::as_list(creators)

  suppressMessages(

    creators_tibble <- tibble::tibble(nodeset = creators) |>
    tidyr::unnest_wider(nodeset)

  )

  essential_cols <- c("individualName", "organizationName", "electronicMailAddress")

  if (all(essential_cols %in% colnames(creators_tibble))) {

    suppressMessages(

      creators_tibble <- creators_tibble |>
      dplyr::select(any_of(c(essential_cols, "userId"))) |>
      tidyr::unnest_wider(individualName) |>
      tidyr::unnest_longer(organizationName) |>
      tidyr::unnest_longer(electronicMailAddress)

    )

    name_cols <- c("givenName", "surName")

    if (all(name_cols %in% colnames(creators_tibble))) {

      creators_tibble <- creators_tibble |>
      tidyr::unnest_longer(givenName) |>
      tidyr::unnest_longer(surName)

      if ("givenName...1" %in% colnames(creators_tibble)) {

        creators_tibble <- creators_tibble |>
        tidyr::unnest_longer(`givenName...1`) |>
        dplyr::mutate(
          givenName = dplyr::case_when(is.na(givenName) & !is.na(`givenName...1`) ~ `givenName...1`,
            TRUE ~ givenName
          )
        )

      }

      if ("givenName...2" %in% colnames(creators_tibble)) {

        creators_tibble <- creators_tibble |>
        tidyr::unnest_longer(`givenName...2`) |>
        dplyr::mutate(
          middleInitial = NA_character_,
          middleInitial = dplyr::case_when(is.na(middleInitial) & !is.na(`givenName...2`) ~ `givenName...2`,
            TRUE ~ middleInitial
          )
        )

      }

      if ("userId" %in% colnames(creators_tibble)) {

        creators_tibble <- creators_tibble |>
        tidyr::unnest_longer(userId)

      }

      creators_tibble <- creators_tibble |>
      dplyr::select(-contains("..."))

    } else {

      creators_tibble <- NULL

    }

  } else {

    creators_tibble <- NULL

  }

  return(creators_tibble) 

}

people_recent <- purrr::map_dfr(as.list(cap_packages$packageid), ~ harvest_creators(.x)) # 2012-2022

people_recent <- people_recent |>
dplyr::select(-salutation) |>
dplyr::filter(
  !is.na(surName),
  !is.na(givenName),
  !is.na(organizationName),
  !is.na(electronicMailAddress)
  ) |>
dplyr::mutate(
  across(where(is.character), ~ stringr::str_trim(.x, side=c("both"))),
  middleInitial    = gsub("\\.", "", middleInitial),
  organizationName = gsub("[\r\n]", " ", organizationName),
  organizationName = gsub("[\t]", " ", organizationName),
  organizationName = gsub("\\s{2,}", " ", organizationName),
  organizationName = dplyr::case_when(grepl("arizona state university", organizationName, ignore.case = TRUE) ~ "Arizona State University",
    TRUE ~ organizationName
    ),
  userId = stringr::str_extract(userId, "[\\w\\d]{4}-[\\w\\d]{4}-[\\w\\d]{4}-[\\w\\d]{4}")
)

people_recent <- people_recent |>
dplyr::distinct(
  givenName,
  surName,
  organizationName,
  middleInitial,
  userId
)
