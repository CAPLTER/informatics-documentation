# libraries
library(tidyverse)
library(RSQLite)

# options
options(dplyr.summarise.inform = FALSE)

# GIOS

source("~/Documents/localSettings/mysql_prod.R")

dbGetQuery(mysql, "SELECT * FROM gios2_production.dataset_access_log ORDER BY id DESC LIMIT 3 ;")

gios_log <- dbGetQuery(mysql, "
SELECT
  CAST(datasets.package_id AS char) AS pid,
  CAST(dal.file AS char) AS file,
  dal.created
FROM gios2_production.dataset_access_log dal
LEFT JOIN gios2_production.dataset_files df ON (df.url = dal.file)
LEFT JOIN gios2_production.datasets ON (datasets.id = df.dataset_id)
WHERE
  datasets.data_access IN ('PUBLIC', 'CAPLTER') AND
  datasets.package_id NOT LIKE 'msb-%'
;")

# for viewing and error checking tally
# gios_log %>%
#   mutate(
#     created = as.POSIXct(created, format = "%Y-%m-%d %H:%M:%S"),
#     created = as.Date(created),
#     year = lubridate::year(created)
#     ) %>%
# mutate(
#   dataset = str_extract(
#     string = str_extract(
#       string = pid,
#       pattern = "(?:knb-lter-cap\\.)([0-9]+)"
#       ),
#     pattern = "[0-9]+"
#   )
# )

gios_log <- gios_log %>%
  mutate(
    created = as.POSIXct(created, format = "%Y-%m-%d %H:%M:%S"),
    created = as.Date(created),
    year = lubridate::year(created)
    ) %>%
  group_by(pid, file, year) %>%
  summarise(
    count = n()
    ) %>%
  ungroup() %>%
  group_by(year, pid) %>%
  summarise(
    accessed_at_least = max(count, na.rm = TRUE)
    ) %>%
  ungroup() %>%
  mutate(
    dataset = str_extract(
      string = str_extract(
        string = pid,
        pattern = "(?:knb-lter-cap\\.)([0-9]+)"
        ),
      pattern = "[0-9]+"
    )
    ) %>%
  group_by(year, dataset) %>%
  summarise(
    touches = sum(accessed_at_least)
    ) %>%
  ungroup() %>%
  mutate(dataset = as.integer(dataset)) %>%
  arrange(year, dataset)

# exclude datasets that are not in EDI
gios_log <- gios_log %>%
  filter(dataset %in% unique(entities_summary$dataset))

# match temporal range of EDI
# gios_log <- gios_log %>%
#   filter(year >= 2015)


# EDI

con15 <- dbConnect(
  RSQLite::SQLite(),
  "~/Dropbox/development/dataset_statistics/year_2015/knb-lter-cap.sqlite"
)
con16 <- dbConnect(
  RSQLite::SQLite(),
  "~/Dropbox/development/dataset_statistics/year_2016/knb-lter-cap.sqlite"
)
con17 <- dbConnect(
  RSQLite::SQLite(),
  "~/Dropbox/development/dataset_statistics/year_2017/knb-lter-cap.sqlite"
)
con18 <- dbConnect(
  RSQLite::SQLite(),
  "~/Dropbox/development/dataset_statistics/year_2018/knb-lter-cap.sqlite"
)
con19 <- dbConnect(
  RSQLite::SQLite(),
  "~/Dropbox/development/dataset_statistics/year_2019/knb-lter-cap.sqlite"
)
con20 <- dbConnect(
  RSQLite::SQLite(),
  "~/Dropbox/development/dataset_statistics/year_2020/knb-lter-cap.sqlite"
)

dbListTables(con19)

entities <- rbind(
  dbGetQuery(con15, "SELECT * FROM entities ;") %>%
    mutate(year = 2015),
  dbGetQuery(con16, "SELECT * FROM entities ;") %>%
    mutate(year = 2016),
  dbGetQuery(con17, "SELECT * FROM entities ;") %>%
    mutate(year = 2017),
  dbGetQuery(con18, "SELECT * FROM entities ;") %>%
    mutate(year = 2018),
  dbGetQuery(con19, "SELECT * FROM entities ;") %>%
    mutate(year = 2019),
  dbGetQuery(con20, "SELECT * FROM entities ;") %>%
    mutate(year = 2020)
)

# edi logs: 2018 - oct_2020
edi_logs <- rbind(
  dbGetQuery(con18, "SELECT * FROM packages ;") %>%
    mutate(year = 2018),
  dbGetQuery(con19, "SELECT * FROM packages ;") %>%
    mutate(year = 2019),
  dbGetQuery(con18, "SELECT * FROM packages ;") %>%
    mutate(year = 2020)
)

# from logs: total file downloads for from EDI (2018-oct_2020)
edi_logs %>% summarise(downloads = sum(count))

# from ent: total file downloads for from EDI (2018-oct_2020)
entities %>% summarise(total = sum(count))

# From the two above, why are the counts different? Regardless, they are within
# ~6% of each other so we can say > 21K file downloads plus ~2K from CAP for
# the period 2018 through Oct_2020 for >23K file downloads for that period.

# total number of downloads ranked by dataset id
edi_log %>%
  mutate(
    dataset = str_extract(
      string = str_extract(
        string = edi_log$pid,
        pattern = "(?:knb-lter-cap\\.)([0-9]+)"
        ),
      pattern = "[0-9]+"
    )
    ) %>%
group_by(dataset) %>%
summarise(downloads = sum(count)) %>%
arrange(desc(downloads))

# The number of files downloaded that we see with edi_log can be deceptive as
# it exaggerates the values based on the number of files in a dataset. For
# example, knb-lter-cap.514.x (Salt River rephotography) contains 42 files. As
# such, if the files in this dataset are accessed twice, that reflects a
# download total of 84. That is, of course, technically accurate - that 84
# files were downloaded. However, it over accentuates the contribution of that
# particular dataset. For example, consider a dataset with only one file for
# which the single file was downloaded 12 times. In this comparison, it is of
# greater interest for this analysis that the dataset with the single file was
# accessed 12 times and the dataset with 42 files was accessed twice. As such,
# the approach below focuses on 'touches' rather than total file downloads by
# isolating the maximum number of files downloaded for each version of dataset
# (by year as well). For example, keeping with the aforementioned rephotography
# dataset, consider that in 2018, the maximum number of files downloaded from
# version 5 (knb-lter-cap.514.5) of that dataset was 2, of version 6 was 2, and
# of version 10 was 3. As such, the total number of times that at least one
# file was accessed in dataset knb-lter-cap.514.x (any version) in 2018 is the
# sum of the maximum number of downloads per version (n = 7 in this example).

# calculate dataset touches delinated by year and dataset number
entities_summary <- entities %>%
  group_by(year, pid) %>%
  summarise(
    accessed_at_least = max(count, na.rm = TRUE)
    ) %>%
  ungroup() %>%
  mutate(
    dataset = str_extract(
      string = str_extract(
        string = pid,
        pattern = "(?:knb-lter-cap\\.)([0-9]+)"
        ),
      pattern = "[0-9]+"
    )
    ) %>%
  group_by(year, dataset) %>%
  summarise(
    touches = sum(accessed_at_least)
    ) %>%
  ungroup() %>%
  mutate(dataset = as.integer(dataset)) %>%
  arrange(dataset)

# explore most touched datasets
entities_summary %>%
  group_by(dataset) %>%
  summarise(accessed_at_least = sum(touches)) %>%
  arrange(desc(accessed_at_least))

# example most touched dataset (McDowell arthropods - wow!)
entities %>%
 filter(grepl("knb-lter-cap.643.", pid))

# calcuate unique datasets per year
entities_summary %>%
  count(year)

# touches

touches <- rbind(
  gios_log %>%
    group_by(year) %>%
    summarise(accessed = sum(touches)) %>%
    ungroup() %>%
    mutate(source = "CAP"),
  entities_summary %>%
    group_by(year) %>%
    summarise(accessed = sum(touches)) %>%
    ungroup() %>%
    mutate(source = "EDI")
  ) %>%
rbind(
  rbind(
  gios_log %>%
    group_by(year) %>%
    summarise(accessed = sum(touches)) %>%
    ungroup() %>%
    mutate(source = "CAP"),
  entities_summary %>%
    group_by(year) %>%
    summarise(accessed = sum(touches)) %>%
    ungroup() %>%
    mutate(source = "EDI")
    ) %>%
  group_by(year) %>%
  summarise(accessed = sum(accessed)) %>%
  ungroup() %>%
  mutate(source = "total")
) %>%
rename(touches = accessed) %>%
add_row(
  year = 2017,
  touches = NA,
  source = "CAP"
  ) %>%
mutate(
  touches = case_when(
    year %in% c(2015, 2016, 2017) & source == "total" ~ NA_integer_,
    year %in% c(2015, 2016, 2017) & source == "EDI" ~ NA_integer_,
    TRUE ~ touches)
)

dataset_count <- rbind(
  gios_log,
  entities_summary
  ) %>%
group_by(year) %>%
summarise(datasets = n_distinct(dataset))

# touches

library(patchwork)


plot_touches <- ggplot() +
  geom_bar(
    mapping = aes(x = year, y = touches, fill = source),
    data = touches %>% filter(year >= 2018),
    stat = "identity",
    position = position_dodge2(preserve = "single", padding = 0),
    na.rm = FALSE
    ) +
  #   geom_line(
  #     mapping = aes(x = year, y = datasets*10, colour = "a"),
  #     data = dataset_count,
  #     size = 2
  #     ) +
  scale_x_continuous(
    name = "year",
    breaks = touches$year) +
  scale_fill_grey(
    name = "data source",
    start = 0.8,
    end = 0.4,
    na.value = "blue"
    ) +
  #   scale_y_continuous(
  #     sec.axis = sec_axis(
  #       trans = ~ . / 10,
  #       name = "number of datasets"
  #     )
  #     ) +
  #   scale_colour_manual(
  #     name = "number of datasets",
  #     values = c("a" = "black"),
  #     labels = c("#")
  #     ) +
  theme(
    text = element_text(face = "bold"),
    axis.text.y = element_text(face = "bold"),
    legend.position = c(0.2, 0.8)
      ) +
    ggtitle(
      label = "approximate number of accesses\nto data resources",
      subtitle = "2018 - ~current"
    )

  plot_datasets <- ggplot() +
    geom_line(
      mapping = aes(x = year, y = datasets),
      data = dataset_count %>% filter(year >= 2015),
      size = 2
      ) +
    #     scale_colour_manual(
    #       name = "number of datasets",
    #       values = c("a" = "black"),
    #       labels = c("#")
    #       ) +
    scale_x_continuous(
      name = "year",
      breaks = dataset_count$year) +
    theme(
      text = element_text(face = "bold"),
      axis.text.x = element_text(face = "bold", size = 10),
      axis.text.y = element_text(face = "bold")
      ) +
    ggtitle(
      label = "number of CAP LTER datasets\nin EDI",
      subtitle = "2015 - ~current"
    )

plot_datasets + plot_touches

ggsave(
  filename = "~/Desktop/download_stats.png",
  width = 9,
  height = 5
)
