## @description: NPSP Performance Tests - Enhanced Recurring Donations Batch
## @date 2021-01-09

*** Variables ***
${database_url} =
${persistent_org} =     ${True}

*** Settings ***
Documentation   Performance Testing of RD2 Nightly Batch Job in a persistent org that has millions of records already.
Library         DateTime
Resource        cumulusci/robotframework/Salesforce.robot
Resource        cumulusci/robotframework/CumulusCI.robot
Resource        robot/Cumulus/resources/NPSP.robot
Resource        robot/Cumulus/resources/Data.robot

*** Keywords ***
## =============================================================================================
## Main Testing Keywords:
## =============================================================================================
Execute RD2 Batch Job
    [Documentation]     Kickoff the RD2_OpportunityEvaluation_BATCH rollup job

    Run Task    execute_anon
        ...     apex=RD2_OpportunityEvaluation_BATCH rdBatchJob = new RD2_OpportunityEvaluation_BATCH(); Database.executeBatch(rdBatchJob, rdBatchJob.batchSize);
    Run Task    batch_apex_wait
        ...     class_name=RD2_OpportunityEvaluation_BATCH


*** Test Cases ***
RD2 Batch Job
    [Tags]    rd2 batch
    Execute RD2 Batch Job
