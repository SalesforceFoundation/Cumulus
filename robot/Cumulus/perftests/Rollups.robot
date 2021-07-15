## @description: NPSP Performance Tests - Customizable Rollups
## @date 2021-01-05

*** Variables ***
${database_url} =
${persistent_org} =     ${True}

*** Settings ***
Documentation   Performance Testing of Customizable Rollups in a persistent org that has millions of records already.
...             An additional 10K Opportunities will be created against 10K Accounts for the test (and then deleted)
...             - Contact Hard Credit
...             - Contact Soft Credit
...             - Account Hard Credit
Library         DateTime
Resource        cumulusci/robotframework/Salesforce.robot
Resource        cumulusci/robotframework/CumulusCI.robot
Resource        robot/Cumulus/resources/NPSP.robot
Resource        robot/Cumulus/resources/Data.robot
Suite Setup     Initial Setup
Suite Teardown  Delete Test Opportunities

*** Keywords ***
## =============================================================================================
## Main Testing Keywords:
## =============================================================================================
Insert Opportunities for Rollups
    [Documentation]  Generate and Insert 10K Opportunities using 10K existing Accounts

    ${query_results} =  SOQL Query
    ...  SELECT Id FROM Account WHERE Number_of_Household_Members__c=2 LIMIT 10000

    ${accounts}=    Set Variable    ${query_results}[records]
    ${numaccounts}=  Get Length     ${accounts}

    Log to Console  Number of Accounts Queried: ${numaccounts}

    Disable Rollup Triggers

    FOR     ${index}  IN RANGE  0    ${numaccounts}     200
        Log to Console   Create 200 Opps with starting Account Index of ${index}
        Create 200 Opportunities     ${index}    ${accounts}
    END

    Log to Console  Number of Opportunities Created: ${numaccounts}

    Enable Rollup Triggers

Execute Account Hard Credit Rollups
    [Documentation]     Kickoff the CRLP_Account_HardCredit rollup job

    Run Task    execute_anon
        ...     apex=CRLP_RollupBatch_SVC.executeBatchRollupJob(CRLP_RollupProcessingOptions.RollupType.AccountHardCredit, CRLP_RollupProcessingOptions.BatchJobMode.NonSkewMode, null, null);
    Run Task    batch_apex_wait
        ...     class_name=CRLP_Account_BATCH

Execute Contact Hard Credit Rollups
    [Documentation]     Kickoff the CRLP_Contact_HardCredit rollup job

    Run Task    execute_anon
        ...     apex=CRLP_RollupBatch_SVC.executeBatchRollupJob(CRLP_RollupProcessingOptions.RollupType.ContactHardCredit, CRLP_RollupProcessingOptions.BatchJobMode.NonSkewMode, null, null);
    Run Task    batch_apex_wait
        ...     class_name=CRLP_Contact_BATCH

Execute Contact Soft Credit Rollups
    [Documentation]     Kickoff the CRLP_Contact_SoftCredit rollup job

    Run Task    execute_anon
        ...     apex=CRLP_RollupBatch_SVC.executeBatchRollupJob(CRLP_RollupProcessingOptions.RollupType.ContactSoftCredit, CRLP_RollupProcessingOptions.BatchJobMode.NonSkewMode, null, null);
    Run Task    batch_apex_wait
        ...     class_name=CRLP_Contact_SoftCredit_BATCH

Execute RD2 Batch Job
    [Documentation]     Kickoff the RD2_OpportunityEvaluation_BATCH rollup job

    Run Task    execute_anon
        ...     apex=RD2_OpportunityEvaluation_BATCH rdBatchJob = new RD2_OpportunityEvaluation_BATCH(); Database.executeBatch(rdBatchJob, rdBatchJob.batchSize);
    Run Task    batch_apex_wait
        ...     class_name=RD2_OpportunityEvaluation_BATCH

## =============================================================================================
## Data Creation Keywords:
## =============================================================================================
Create 200 Opportunities
    [Arguments]         ${acctstartindex}     ${accounts}
    [Documentation]     Generate 200 Opportunity objects for the related Account/Contact

    ${random_amt}=      Generate Random String    6     [NUMBERS]
    ${date}=     Get Current Date        result_format=%Y-%m-%d
    @{opps}=     Generate Test Data      Opportunity  200
        ...  Name=Performance Test Opportunity ${acctstartindex}-{{number}}
        ...  StageName=Closed Won
        ...  Amount=${random_amt}
        ...  CloseDate=${date}
        ...  npe01__Do_Not_Automatically_Create_Payment__c=true

    ${numopps}=  Get Length     ${opps}
    FOR     ${index}   IN RANGE   ${numopps}
        ${acctindex} =      Evaluate    ${acctstartindex} + ${index}
        ${opp}=         Set Variable    ${opps}[${index}]
        ${account}=     Set Variable    ${accounts}[${acctindex}]
        ${account_id}=  Set Variable    ${account}[Id]
        set to dictionary   ${opp}   AccountId   ${account_id}
    END
    Salesforce Collection Insert  ${opps}


## =============================================================================================
## Helper Keywords
## =============================================================================================

Initial Setup
    Delete Test Opportunities
    Insert Opportunities for Rollups

Disable Duplicate Matching
    [Documentation]  Disable Salesforce duplicate matching
    Run Task        set_duplicate_rule_status
        ...     active=${False}

Disable Rollup Triggers
    [Documentation]  Disable all NPSP Rollup Triggers
    Log to Console   Disable NPSP Rollup Triggers
    Run Task         disable_triggers
        ...     active=${False}
        ...     restore=${False}
        ...     handlers=CRLP_Rollup_TDTM

Enable Rollup Triggers
    [Documentation]  Enable all NPSP Rollup Triggers
    Log to Console   Enable NPSP Rollup Triggers
    Run Task         restore_triggers
        ...     active=${True}
        ...     restore=${False}
        ...     handlers=CRLP_Rollup_TDTM

Enable Default GAU Allocation
    [Documentation]     Insert a single GAU record and set that as the default allocation in NPSP
    ${ns}=              Get NPSP Namespace Prefix
    &{default_gau}=     API Create GAU
    API Modify Allocations Setting
    ...        ${ns}Default_Allocations_Enabled__c=true
    ...        ${ns}Default__c=${default_gau}[Id]

Disable Default GAU Allocation
    [Documentation]     Disable the default GAU
    ${ns}=   Get NPSP Namespace Prefix
    API Modify Allocations Setting
    ...        ${ns}Default_Allocations_Enabled__c=false

Delete Test Opportunities
    [Documentation]     Delete All Created Records
    Log to Console      Deleting All Created Opporutnities
    Disable Rollup Triggers
    Bulk Delete     Opportunity     where=Name Like '%Performance Test Opportunity%'
    Enable Rollup Triggers


*** Test Cases ***
CRLP Account Hard Credit Batch Job
    [Tags]    crlp account hardcredit
    Execute Account Hard Credit Rollups

CRLP Contact Hard Credit Batch Job
    [Tags]    crlp contact hardcredit
    Execute Contact Hard Credit Rollups

CRLP Contact Soft Credit Batch Job
    [Tags]    crlp contact softcredit
    Execute Contact Soft Credit Rollups