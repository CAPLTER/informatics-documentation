## calculate download statistics for CAP LTER data packages

The workflow here was developed to estimate downloads of CAP LTER datasets in advance of the CAP IV mid-term site review in October 2020. We use the EDI::counter package (https://github.com/PASTAplus/counter) to quantify file downloads from PASTA for the period 2015 through the site review (October 2020). Code also is included to estimate downloads from the now deprecated CAP LTER data portal. For convenience, the output from download_stats.R (figure .png) was saved to file and incorporated into the presentation Rmd as an asset rather than incorporating the code to construct the figures directly into the presentation Rmd. Note that only data returned from counter for the years 2018, 2019, and 2020 were used as the data from 2015-2017 seemed to be an empty set.

Steps to install and run counter:

```sh
  sudo apt install python3-pip
  pip3 install requests
  pip3 install lxml
  pip3 install daiquiri
  pip3 install click
  pip3 install sqlalchemy
  pip3 install psycopg2
  export PATH="$HOME/.local/bin:$PATH"
  pip3 install .
  counter -s "2020-01-01T00:00:00" -e "2020-05-01T00:00:00" knb-lter-cap "uid=CAP,o=LTER,dc=ecoinformatics,dc=org:password"
  counter -s "2019-01-01T00:00:00" -e "2019-12-31T00:00:00" -c knb-lter-cap "uid=CAP,o=LTER,dc=ecoinformatics,dc=org:password"
  counter -s "2018-01-01T00:00:00" -e "2018-12-31T23:59:00" -c knb-lter-cap "uid=CAP,o=LTER,dc=ecoinformatics,dc=org:password"
```
