# README

#  evaluate datasets published in a given period

# libraries
library(tidyverse)

# database connection
source("~/Documents/localSettings/mysql_prod.R")

# query datasets in a reporting year
datasets <- dbGetQuery(mysql, "
  SELECT
    package_id,
    dataset_number,
    revision,
    dataset_title,
    dataset_published
  FROM
    tbl
  WHERE
    dataset_published between '2018-12-31' and '2020-01-01' ;"
) %>%
arrange(dataset_number, revision)

# resolve new and updated datasets

new_datasets <- datasets %>%
  filter(revision == 1)

updated_datasets <- datasets %>%
  filter(revision > 1) %>%
  anti_join(new, by = c("dataset_number"))
