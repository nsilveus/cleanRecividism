
# Loading data ------------------------------------------------------------

# Corrected file path with proper separator
encripted_drive_path <- "/Volumes/Untitled/PA DOC/"

# Verify the correct file path
file_path <- paste0(encripted_drive_path, "2021-22_Silveus_deidentified_prison_spells.csv")
print(file_path)  # This should print the full file path

# Read the CSV file using the corrected file path
movements <- read.csv(file_path)


movements <- read.csv("/Volumes/Untitled/PA DOC/2021-22_Silveus_deidentified_prison_spells.csv")

# Change column name; BRIAN (June 6th 2024):this has been changed so this instruction is no longer necessary 6/3/2024
#movements <- movements %>% rename("control_number" = "ï..control_number" )

names(movements)

demographics <- read_xlsx(paste0(encripted_drive_path,"2021-22_Silveus_deidentified.xlsx"),sheet = "demographics")

ccc_cohort <- read_xlsx(paste0(encripted_drive_path,"2021-22_Silveus_deidentified.xlsx"),sheet = "ccc_cohort")

ccc_moves <- read_xlsx(paste0(encripted_drive_path,"2021-22_Silveus_deidentified.xlsx"),sheet = "ccc_moves")

sentencing <- read_xlsx(paste0(encripted_drive_path,"2021-22_Silveus_deidentified.xlsx"),sheet = "sentencing")

lsir <- read_xlsx(paste0(encripted_drive_path,"2021-22_Silveus_deidentified.xlsx"),sheet = "lsir")



# Preparing data frame -----------------------------------------------------


# Select columns and create month and year of arrival variables.
cc_counts_df <- ccc_moves %>% 
  # BRIAN (June 6th 2024): added 'movement_id'
  select(c('control_number', 'bed_date', 'status_code', 'status_description','status_date', 'location_to_code', 'location_from_code', 'movement_id'))  %>% 
# Drop duplicates by control number status code, and date. 
# Sometimes there are multiple entry records if the resident is enrolled in multiple programs.
  distinct(control_number, status_code, status_date, location_from_code, .keep_all = TRUE) %>% 
  # BRIAN (June 6th 2024): check for duplicate movement IDs
  distinct(movement_id, .keep_all = TRUE)




# If control number (resident) has that status code then keep it, then, for each resident, it gives a listing of their "total history"
view_status_case <- function(df_name, status_code_str){
  temp_df <- df_name
  temp_df$temp <- ifelse(temp_df$status_code==status_code_str,1,0)
  temp_df <-temp_df %>% group_by(control_number) %>% mutate(case = max(temp))
  temp_df %>% filter(case==1) %>% arrange(control_number,ymd(status_date)) %>% select(c('control_number','status_code', 'status_description', 'bed_date', 'status_date', 'location_from_code', 'location_to_code')) %>%  View()
}

view_status_case(center_change, 'UDSC')

# Observing Transfer to County

view_status_case(cc_counts_df, 'TRTC')

center_change <-  cc_counts_df %>% 
  filter(location_to_code != 'NULL')

center_change_codes <- unique(center_change$status_code)

center_change_codes 


# Of the 34 unique codes, we are interested in 4 arrival codes: 
# INRS - In Residence
# TRRC - Transfer Received
# RTRS - Return to Residence
# DPWF - Return from DPW

cc_arrivals <- cc_counts_df %>% 
  filter(status_code == 'INRS' | status_code == 'TRRC' | status_code == 'RTRS' | status_code == 'DPWF') %>% 
  mutate(month_year = floor_date(status_date,"month")) %>%  
  # Replaced the following: group_by(month_year, location_from_code) %>% summarise(arrivals=n(), .groups = 'drop') %>% ungroup() 
  summarize(
    arrivals = n(),
    .by = c(month_year, location_from_code)
  ) %>% 
  # BRIAN (June 6th 2024): arrange does not seem to do anything. Perhaps this is because it is not a tibble anymore?
  # arrange(desc(location_from_code)) %>% 
  complete(month_year, location_from_code, fill = list(arrivals = 0)) %>%  
  as.data.frame()


# Adding transfer out, parole, etc by CCC/CCF month

departure_codes <- c('TRGH','PTST','DECN','ABSC','TRSC','UDSC','TTRN','DPWT','DC2P','SENC','ESCP','HOSP','AWOL','ATA','DECX','DECA','DECS','TRTC')

cc_departures <- cc_counts_df %>% 
  filter(status_code  %in% departure_codes) %>% 
  mutate(month_year=floor_date(status_date, unit='month')) %>% 
  # Replaced the following: group_by(month_year, location_from_code)%>% summarise(departures=n(), .groups = 'drop') %>% ungroup() %>%
  summarize (
    departures = n(),
    .by = c(month_year, location_from_code)
  ) %>% 
  complete(month_year, location_from_code, fill = list(departures=0))  %>%  
  as.data.frame()


# Merge departures and arrivals. Subtract to have net flow
cc_flows <- left_join(cc_arrivals,cc_departures, by = c('month_year'='month_year', 'location_from_code'='location_from_code')) %>% 
  replace_na(list(departures=0, arrivals=0))
cc_flows <- cc_flows %>% 
  mutate(net_arrivals = arrivals - departures)

cc_flows_by_month <- cc_flows %>% 
  group_by(month_year) %>%
  summarise(arrivals = sum(arrivals),departures = sum(departures), net_arrivals = sum(net_arrivals)) %>%
  arrange(month_year) %>% mutate(month_year = ymd(month_year))

# Plot of net flow
ggplot(data=cc_flows_by_month %>% 
         filter(year(month_year) >= 2008 & year(month_year) < 2020), aes(x = month_year, y = arrivals)) + 
  geom_point() + geom_line() + 
  labs(title = "Arrivals to Pennsylvania Halfway Houses by Month", y='Arrivals', x='') +
  scale_x_date(date_breaks = '1 year', date_labels = "%b-%Y") + 
  theme(axis.text.x = element_text(angle = 90))