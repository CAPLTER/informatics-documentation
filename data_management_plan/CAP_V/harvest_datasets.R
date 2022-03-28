# remotes::install_github("EDIorg/EDIutils", ref = "development")

# build data catalog

## workflow: query cap holdings by scope

### includes all cap datasets but none outside the cap scope (e.g., not urex)
### includes only the most recent version

scope_pkgs <- EDIutils::search_data_packages(
  query = 'q=*:*&fl=packageid&fq=scope:(knb-lter-cap)&fq=-scope:(ecotrends+lter-landsat)&rows=1000',
  env = "production"
)

scope_pkgs_list <- xml2::xml_find_all(scope_pkgs, ".//packageid") |>
    xml2::as_list()

cap_pkgs <- unlist(scope_pkgs_list)

cap_packages <- tibble::tibble(
  package = cap_pkgs
)


## workflow: query cap holdings by user

### yields incomplete listing of cap datasets but does include non-cap datasets published with the cap login (e.g., urex)
### includes all versions of datasets

cap_user <- EDIutils::create_dn(userId = "CAP")
cap_pkgs <- EDIutils::list_user_data_packages(cap_user)

## extra step here to get the most recent version

cap_packages <- tibble::tibble(
  packages = cap_pkgs
  ) |>
tidyr::separate(
  col    = packages,
  into   = c("scope", "identifier", "version"),
  sep    = "\\.",
  remove = FALSE
  ) |>
dplyr::group_by(
  scope,
  identifier
  ) |>
dplyr::summarise(
  highest = max(version)
  ) |>
dplyr::ungroup() |>
dplyr::mutate(
  package = paste0(scope, ".", identifier, ".", highest)
)


## for both workflows: construct list of package ids and citations

cap_citations_list <- split(
  cap_packages,
  cap_packages$package
) |>
{\(pkg) purrr::map(.x = pkg, ~ EDIutils::read_data_package_citation(packageId = .x$package, access = TRUE, style = "ESIP", ignore = NULL, frmt = "char", env = "production"))}()

## for both workflows: citation list to frame

cap_citations_frame <- tibble::enframe(cap_citations_list) |>
  tidyr::unnest_wider(value) |>
  dplyr::select(
    package  = name,
    citation = `...1`
  )

# keywords

## extract key words function

extract_key_words <- function(package_id) {

  edi_metadata <- EDIutils::read_metadata(package_id)

  keyword_list <- xml2::xml_find_all(edi_metadata, ".//keyword") |>
    xml2::as_list()

  keyword_tibble <- tibble::tibble(nodeset = keyword_list) |>
    tidyr::unnest_wider(nodeset) |>
    dplyr::mutate(package = package_id) |>
    dplyr::select(
      package,
      keyword = `...1`
    )

  return(keyword_tibble)

}

# extract_key_words_safely   <- purrr::safely(.f = extract_key_words)
extract_key_words_possibly <- purrr::possibly(.f = extract_key_words, otherwise = NULL)

# cap_packages_keywords <- purrr::map_dfr(.x = cap_pkgs, ~ extract_key_words_safely(.x))
cap_packages_keywords <- purrr::map_dfr(.x = cap_pkgs, ~ extract_key_words_possibly(.x))

## add core areas

core_research_areas <- cap_packages_keywords |>
dplyr::mutate(
  CRA = NA_character_,
  CRA = dplyr::case_when(
    grepl("primary production", keyword, ignore.case = T) ~ "PP",
    grepl("population", keyword, ignore.case = T) ~ "PC",
    grepl("movement of \\borganic\\b", keyword, ignore.case = T) ~ "OM",
    grepl("movement of \\binorganic\\b", keyword, ignore.case = T) ~ "ND",
    grepl("disturbance", keyword, ignore.case = T) ~ "D",
    grepl("landuse|land-use|land use", keyword, ignore.case = T) ~ "LU",
    grepl("\\bhuman-environment\\b|\\bhuman environment\\b", keyword, ignore.case = T) ~ "SES" # also matched 'human environment feedback'
    )
  ) |>
dplyr::filter(!is.na(CRA)) |>
dplyr::distinct(package, CRA) |>
dplyr::group_by(package) |>
dplyr::summarise(core_area = paste(CRA, collapse = " ")) |>
dplyr::ungroup()

# keyword_string <- cap_packages_keywords |>
#   dplyr::group_by(package) |>
#   dplyr::summarise(keywords = paste(keyword, collapse = " "))

# customize table as needed:

# - add custom core areas as needed 
# - remove url per RFP guidelines
# - remove access data
# - subsequently confirm that all datasets have a a CRA

custom_table <- cap_citations_frame |>
dplyr::left_join(core_research_areas, by = c("package")) |>
dplyr::mutate(
  core_area = dplyr::case_when(
    grepl("636|100|101|112|147|323|575", package, ignore.case = T) ~ "D",
    grepl("113|223|269|280|282|291", package, ignore.case = T) ~ "D LU",
    grepl("114|295", package, ignore.case = T) ~ "ND",
    grepl("270|271", package, ignore.case = T) ~ "D ND OM",
    grepl("273|616", package, ignore.case = T) ~ "PC",
    grepl("285", package, ignore.case = T) ~ "D PC",
    TRUE ~ core_area
    ),
  citation = sub("https://doi.org/", "DOI: ", citation),
  citation = sub(". Accessed .*", "", citation)
)


# custom_table |>
# dplyr::mutate(
#   citation = sub(". Accessed .*", "", citation)
# ) |> readr::write_csv("~/Desktop/sans_access.csv")

# custom_table |>
#   dplyr::filter(is.na(core_area))

# construct table for ingest by Rmd

readr::write_csv(
  x    = custom_table,
  file = "cap_datasets.csv"
)
