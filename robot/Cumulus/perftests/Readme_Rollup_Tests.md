# Robot Automation Tests - Customizable Rollups

## File
- Rollups.robot

## Org Type
- Persistent Enterprise Sandbox Org
- http://npsp-ldv-gamma--rollupperf.my.salesforce.com

### Storage:
- 100GB Available
- Accounts: 523K 
- Contacts: 510K
- Opportunities: ~2.2 Million
- Recurring Donations: 475K

## Test Automation Flow (CCI):
1. `max_feature_parameter_limit_work_around`: Remove the Feature Parameters over the max of 25
2. `unmanaged_ee`: Push the latest unmanaged code into the Sandbox
3. `deploy_rd2_config`: Because `unmanaged_ee` overwrites config when Enhanced Recurring Donations is enabled, this puts it back. Specifically re-enables the "Last_Day" picklist value on the Day_of_Month__c field.
4. `test_rollup_performance`: Execute the Robot Test

## Robot Test: test_rollup_performance

### A. Create 10K Opportunities
1. Query the 10K Account records that have two Household Members
2. Create one Closed Won Opportunity for each Household.
3. The result is an Opportunity with two OpportunityContactRole records, ensuring that there will be SoftCredit values to rollup.

### B. Execute the Customizable Rollup Account Hard Credit Job
1. Execute through Anonymous Apex
2. Wait for the job to complete

### C. Execute the Customizable Rollup Account Hard Credit Job
1. Execute through Anonymous Apex
2. Wait for the job to complete

### D. Execute the Customizable Rollup Account Hard Credit Job
1. Execute through Anonymous Apex
2. Wait for the job to complete

### E. Delete Test Data
1. Disable Rollup Triggers (`CRLP_Rollup_TDTM` class)
2. Hard Delete Opportunities created in step A above.

