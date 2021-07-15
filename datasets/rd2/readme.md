# Using the RD SnowFakery Data Factories

- Snowfakery Documentation: https://snowfakery.readthedocs.io/en/docs/
- NPSP LDV Org Data Loading Documentation: https://salesforce.quip.com/aoqmAzdgQYJL
 
## YML Files:

##### Special Notes:
- Be sure that RD2 is enabled in the org first by using the `enable_rd2` flow
- Do *not* disable all NPSP Triggers before executing. 
- Follow the directions in the Quip Doc above to pre-configure the LDV org for data loading
- Run the standard RD2 batch job after the import completes to allow the first installment opportunity to be created.
  
### data_recipe_with_rd2.yml:
- This yml will create Contacts records with the following:
   - 95% of all created Contacts will have 1 Enhanced Recurring Donation
       - 95% of the RD's are for this Household Contact
       - 5% of the RD's are for an Organization Account (and the Household Contact)
       - DateEstablished/EffectiveDate is within the last 2 years
       - 5% of the RD's have an Allocation and/or a linked Campaign
       - 95% of RD's are Open, the other 5% are Fixed length
       - There is a random distribution of Installment Periods, DayOfMonth, etc.
       - All RD's will get exactly 1 historical ClosedWon Opportunity
   - Create 0 to 5 Opportunities for the Contact & Related Household Account
       - CloseDate between 3 years ago and 6 months in the future (ClosedWon if in the past)
   - Note: Allocation records are always inserted using the Bulk Serial api as defined in the related load.yml file.

##### To generate 500000 Contacts with sample RD2 and Opp data:
`cci flow run test_data_rd2_managed -o generate_and_load_from_yaml__num_records 500000 --org {orgname}`
