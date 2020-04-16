*** Settings ***

Resource       cumulusci/robotframework/Salesforce.robot
Library        DateTime
Library        NPSP.py

*** Variables ***
${task1}  Send Email1
${sub_task}    Welcome Email1-1
${task2}     Make a Phone Call2


*** Keywords ***

Capture Screenshot and Delete Records and Close Browser
    Run Keyword If Any Tests Failed      Capture Page Screenshot
    Close Browser
    Delete Session Records
    
API Create Contact
    [Arguments]      &{fields}
    ${first_name} =  Generate Random String
    ${last_name} =   Generate Random String
    ${contact_id} =  Salesforce Insert  Contact
    ...                  FirstName=${first_name}
    ...                  LastName=${last_name}
    ...                  &{fields}  
    &{contact} =     Salesforce Get  Contact  ${contact_id}
    [return]         &{contact}

API Modify Contact
    [Arguments]      ${contact_id}      &{fields}
    Salesforce Update       Contact     ${contact_id}
    ...                     &{fields}
    @{records} =  Salesforce Query      Contact
    ...              select=Id,FirstName,LastName,Email
    ...              Id=${contact_id}
    &{contact} =  Get From List  ${records}  0
    [return]         &{contact}

API Create Campaign
    [Arguments]      &{fields}
    ${name} =   Generate Random String
    ${campaign_id} =  Salesforce Insert  Campaign
    ...                  Name=${name}
    ...                  &{fields}  
    &{campaign} =     Salesforce Get  Campaign  ${campaign_id}
    [return]         &{campaign}
    
API Create Opportunity
    [Arguments]      ${account_id}    ${opp_type}      &{fields} 
    ${rt_id} =       Get Record Type Id  Opportunity  ${opp_type}
    ${close_date} =  Get Current Date  result_format=%Y-%m-%d
    ${opp_id} =  Salesforce Insert    Opportunity
    ...               AccountId=${account_id}
    ...               RecordTypeId=${rt_id}
    ...               StageName=Closed Won
    ...               CloseDate=${close_date}
    ...               Amount=100
    ...               Name=Test Donation
    ...               npe01__Do_Not_Automatically_Create_Payment__c=true 
    ...               &{fields}
    &{opportunity} =     Salesforce Get  Opportunity  ${opp_id} 
    [return]         &{opportunity}  
 
API Create Organization Account
    [Arguments]      &{fields}
    ${name} =        Generate Random String
    ${rt_id} =       Get Record Type Id  Account  Organization
    ${account_id} =  Salesforce Insert  Account
    ...                  Name=${name}
    ...                  RecordTypeId=${rt_id}
    ...                  &{fields}
    &{account} =     Salesforce Get  Account  ${account_id}
    [return]         &{account}

API Create Primary Affiliation
    [Arguments]      ${account_id}      ${contact_id}    &{fields}    
    ${opp_id} =  Salesforce Insert    npe5__Affiliation__c
    ...               npe5__Organization__c=${account_id}
    ...               npe5__Contact__c=${contact_id}
    ...               npe5__Primary__c=true 
    ...               &{fields}

API Create Secondary Affiliation
    [Arguments]      ${account_id}      ${contact_id}    &{fields}    
    ${opp_id} =  Salesforce Insert    npe5__Affiliation__c
    ...               npe5__Organization__c=${account_id}
    ...               npe5__Contact__c=${contact_id}
    ...               npe5__Primary__c=false 
    ...               &{fields}

API Create Relationship
    [Arguments]      ${contact_id}      ${relcontact_id}    ${relation}    &{fields}
    ${rel_id} =  Salesforce Insert  npe4__Relationship__c
    ...                  npe4__Contact__c=${contact_id}
    ...                  npe4__RelatedContact__c=${relcontact_id}
    ...                  npe4__Type__c=${relation}
    ...                  npe4__Status__c=Current    
    ...                  &{fields}  
    &{relation} =     Salesforce Get  npe4__Relationship__c  ${rel_id}
    [return]         &{relation}
    
     
# API Create Engagement Plan
    # [Arguments]      ${plan_name}     &{fields}    
    # ${opp_id} =  Salesforce Insert    npsp__Engagement_Plan_Template__c
    # ...               Name=${plan_name}
    # ...               npsp__Description__c=This plan is created via Automation 
    # ...               &{fields}

API Create Recurring Donation
    [Arguments]        &{fields}
    ${ns} =            Get Npsp Namespace Prefix
    ${recurring_id} =  Salesforce Insert  npe03__Recurring_Donation__c
    ...                &{fields} 
    &{recurringdonation} =           Salesforce Get     npe03__Recurring_Donation__c  ${recurring_id}
    [return]           &{recurringdonation}

API Query Installment
    [Arguments]        ${id}                      ${installment}    &{fields}
    @{object} =        Salesforce Query           Opportunity
    ...                select=Id
    ...                npe03__Recurring_Donation__c=${id}
    ...                ${ns}Recurring_Donation_Installment_Name__c=${installment}
    ...                &{fields}
    [return]           @{object}

API Create GAU
    [Arguments]      &{fields}
    ${name} =   Generate Random String
    ${ns} =    Get Npsp Namespace Prefix
    ${gau_id} =  Salesforce Insert  ${ns}General_Accounting_Unit__c
    ...               Name=${name}
    ...               &{fields} 
    &{gau} =     Salesforce Get  ${ns}General_Accounting_Unit__c  ${gau_id}
    [return]         &{gau}  

API Create DataImportBatch
    [Arguments]      &{fields}
    ${name} =   Generate Random String
    ${ns} =  Get NPSP Namespace Prefix
    ${batch_id} =  Salesforce Insert  ${ns}DataImportBatch__c
    ...                  Name=${name}
    ...                  &{fields}
    &{batch} =     Salesforce Get  ${ns}DataImportBatch__c  ${batch_id}
    [return]         &{batch}
    
API Create DataImport   
    [Arguments]      &{fields}
    ${ns} =  Get NPSP Namespace Prefix
    ${dataimport_id} =  Salesforce Insert  ${ns}DataImport__c
    ...                  &{fields}
    &{data_import} =     Salesforce Get  ${ns}DataImport__c  ${dataimport_id}
    [return]         &{data_import} 

New Contact for HouseHold
    Click Related List Button  Contacts    New 
    Wait Until Modal Is Open
    ${first_name} =           Generate Random String
    ${last_name} =            Generate Random String
    Populate Form
    ...                       First Name=${first_name}
    ...                       Last Name=${last_name}
    Click Modal Button        Save    
    Wait Until Modal Is Closed
    Go To Object Home         Contact
    Click Link                link= ${first_name} ${last_name}
    Current Page Should be    Details    Contact
    ${contact_id} =           Save Current Record ID For Deletion      Contact
    [return]                  ${contact_id}

Run Donations Batch Process
    Open NPSP Settings          Bulk Data Processes                Rollup Donations Batch
    Click Settings Button       idPanelOppBatch                    Run Batch
    # Wait For Locator    npsp_settings.status    CRLP_Account_SoftCredit_BATCH    Completed
    # Wait For Locator    npsp_settings.status    CRLP_RD_BATCH    Completed
    # Wait For Locator    npsp_settings.status    CRLP_Account_AccSoftCredit_BATCH    Completed
    # Wait For Locator    npsp_settings.status    CRLP_Contact_SoftCredit_BATCH    Completed
    # Wait For Locator    npsp_settings.status    CRLP_Account_BATCH    Completed
    # Wait For Locator    npsp_settings.status    CRLP_Contact_BATCH    Completed
    Wait For Batch To Process    RLLP_OppAccRollup_BATCH            Completed
    Wait For Batch To Process    RLLP_OppContactRollup_BATCH        Completed
    Wait For Batch To Process    RLLP_OppHouseholdRollup_BATCH      Completed
    Wait For Batch To Process    RLLP_OppSoftCreditRollup_BATCH     Completed
    
     
Scroll Page To Location
    [Arguments]    ${x_location}    ${y_location}
    Execute JavaScript    window.scrollTo(${x_location},${y_location}) 

Open NPSP Settings
    [Arguments]    ${topmenu}    ${submenu}
    Go To Page                Custom         NPSP_Settings
    Open Main Menu            ${topmenu}
    Open Sub Link             ${submenu}
    Sleep  1
    
Click Data Import Button
    [Arguments]       ${frame_name}    ${ele_path}     @{others}
    Select Frame And Click Element    ${frame_name}    ${ele_path}     @{others}

Run Accessibility Check
    [Arguments]       &{css_selector}
    Inject Axe Core Library
    &{results}    Get Axe Analysis Results      &{css_selector}
    Log Summary Of Results    ${results}
    Warn On Incomplete Rules    ${results}
    Warn On Violations Rules    ${results}    
      
     
Process Data Import Batch
    [Documentation]        Go to NPSP Data Import Page and change view to 'To be Imported' and Process Batch
    ...                    | status | expected status of batch processing Ex:'Completed' 'Errors' |
    [Arguments]    ${status}
    Go To Page                                         Listing                 DataImport__c
    Change View To                                     To Be Imported
    Click                                              Start Data Import
    Begin Data Import Process And Verify Status        BDI_DataImport_BATCH    ${status}
    Click Close Button    
