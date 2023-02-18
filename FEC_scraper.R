library(tidyverse)
library(rvest)
library(jsonlite)
library(RPostgres)

fec_scraper = function(){ 
  
report = system("curl 'https://api.propublica.org/campaign-finance/v1/2022/filings/types/F3.json' -H 'X-API-Key: 7xhhJQ6SApuk703iqnVHUzSmwepe6A1Qhbj9t4Gc'", intern = TRUE) %>% fromJSON
report = report[["results"]] %>% 
  as.data.frame %>% 
  dplyr::select(filing_id, fec_committee_id, committee_name, report_title, date_filed, report_period, contributions_total,cash_on_hand,disbursements_total,receipts_total,loans_total, debts_total)

  return(report)

}

#grabbing connection variables 
conn <- dbConnect(
  RPostgres::Postgres(), 
  host = Sys.getenv('PGHOST'), 
  dbname = Sys.getenv('PGDATABASE'), 
  user = Sys.getenv('PGUSER'), 
  password = Sys.getenv('PGPASSWORD'), 
  port = Sys.getenv('PGPORT')
)

#creating table, if not already created
dbExecute(conn,
          "CREATE TABLE IF NOT EXISTS fec_filings (
               id SERIAL, 
               filing_id TEXT PRIMARY KEY,
               fec_committee_id TEXT, 
               committee_name TEXT, 
               report_title TEXT, 
               date_filed DATE, 
               report_period TEXT, 
               contributions_total NUMERIC(12,2),
               cash_on_hand NUMERIC(12,2), 
               disbursement_total NUMERIC(12,2), 
               receipts_total NUMERIC(12,2), 
               loans_total NUMERIC(12,2), 
               debts_total NUMERIC(12,2)
          )
          ")


while(TRUE){
  filings <- fec_scraper()
  filings <- unname(filings)
  
  for (i in 1:20){
    dbExecute(conn, 
              "INSERT INTO fec_filings(filing_id, fec_committee_id, committee_name, report_title, date_filed, report_period, contributions_total, cash_on_hand, disbursement_total, receipts_total, loans_total, debts_total)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                ON CONFLICT (filing_id) 
                    DO NOTHING", params = filings[i,])
    
  }
  print("Form 3 filings updated")
  #sleep 
  Sys.sleep(3600)
}