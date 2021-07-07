*** Settings ***

Resource       cumulusci/robotframework/Salesforce.robot
Library        DateTime
Library        Process
Library        robot/Cumulus/resources/NPSPSettingsPageObject.py
Library        NPSP.py

*** Variables ***
${task1}  Send Email1
${sub_task}    Welcome Email1-1
${task2}     Make a Phone Call2


*** Keywords ***

Capture Screenshot and Delete Records and Close Browser
    [Documentation]         This keyword will capture a screenshot before closing the browser and deleting records when test fails
    Run Keyword If Any Tests Failed      Capture Page Screenshot
    Close Browser
    Delete Session Records

API Create Contact
    [Documentation]  If no arguments are passed, this keyword will create a contact with Firstname and Lastname
    ...              as random strings with no additional info. This keyword returns the contact dictonary when called
    ...              Syntax for passing parameters:
    ...
    ...              | field api name=value   | Ex: MobilePhone=1234567098    |
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
    [Documentation]  This keyword is used to update an existing contact by passing contact id and apifieldname and value.
    ...              This keyword returns the contact dictonary after the update, when called
    ...              Syntax for passing parameters:
    ...
    ...              | contact_id   | id of the contact Ex: 000axb57689    |
    ...              | field_api_name=value   | Ex: if old value is my@test.com and u wnat to update then pass Email=abc@test.com    |
    [Arguments]      ${contact_id}      &{fields}
    Salesforce Update       Contact     ${contact_id}
    ...                     &{fields}
    @{records} =  Salesforce Query      Contact
    ...              select=Id,FirstName,LastName,Email
    ...              Id=${contact_id}
    &{contact} =  Get From List  ${records}  0
    [return]         &{contact}

API Modify Recurring Donation
    [Documentation]  This keyword is used to update an existing recurring donation record by passing id and
    ...              This keyword returns the recurring donation dictonary after the update, when called
    ...              Syntax for passing parameters:
    ...
    ...              | Recurring Donation ID   |

    [Arguments]             ${rd_id}      &{fields}
    ${ns} =                 Get NPSP Namespace Prefix
    Salesforce Update       npe03__Recurring_Donation__c     ${rd_id}
    ...                     &{fields}
    @{records} =  Salesforce Query      npe03__Recurring_Donation__c
    ...              select=${ns}StartDate__c,npe03__Amount__c
    ...              Id=${rd_id}
    &{rd} =          Get From List  ${records}  0
    [return]         &{rd}

API Create Campaign
    [Documentation]  If no arguments are passed, this keyword will create a new campaign with just Name
    ...              as random strings and no additional info. This keyword returns the campaign dictonary when called
    ...              Syntax for passing parameters:
    ...
    ...              | field_api_name=value   | Ex: MobilePhone=1234567098    |
    [Arguments]      &{fields}
    ${name} =   Generate Random String
    ${campaign_id} =  Salesforce Insert  Campaign
    ...                  Name=${name}
    ...                  &{fields}
    &{campaign} =     Salesforce Get  Campaign  ${campaign_id}
    [return]         &{campaign}

API Create Opportunity
    [Documentation]  Creates opportunity of specified type for specified account. Opportunity details can be passed as key, value pairs
    ...              Sets defaults of StageName=Closed Won,CloseDate=current date,Amount=100, do not create payments as true if no values are passed.
    ...              This keyword returns the opportunity dictonary when called
    ...              Required parameters are:
    ...
    ...              |   account_id    |   id of account opportunity should be associated with    |
    ...              |   opp_type      |   avaialble options: Donation, Grant, Matching Gift, In-Kind Gift, Major Gift, Membership    |
    ...              |   field_api_name=value |   Ex:StageName=Closed Won    |
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
    [Documentation]  If no arguments are passed, this keyword will create an account of type organization with just Name
    ...              as random string and no additional info. This keyword returns the account dictonary when called
    ...              Syntax for passing parameters:
    ...
    ...              | field_api_name=value   | Ex: MobilePhone=1234567098    |
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
    [Documentation]  Creates a primary affiliation for a contact with specified account
    ...              Required parameters are:
    ...
    ...              |   account_id    |   id of account   |
    ...              |   contact_id    |   id of contact   |
    ...              |   field_api_name=value |   any field u want to populate with value on  npe5__Affiliation__c object   |
    [Arguments]      ${account_id}      ${contact_id}    &{fields}
    ${opp_id} =  Salesforce Insert    npe5__Affiliation__c
    ...               npe5__Organization__c=${account_id}
    ...               npe5__Contact__c=${contact_id}
    ...               npe5__Primary__c=true
    ...               &{fields}

API Create Secondary Affiliation
    [Documentation]  Creates a secondary affiliation for a contact with specified account
    ...              Required parameters are:
    ...
    ...              |   account_id    |   id of account   |
    ...              |   contact_id    |   id of contact   |
    ...              |   field_api_name=value |   any field u want to populate with value on  npe5__Affiliation__c object
    [Arguments]      ${account_id}      ${contact_id}    &{fields}
    ${opp_id} =  Salesforce Insert    npe5__Affiliation__c
    ...               npe5__Organization__c=${account_id}
    ...               npe5__Contact__c=${contact_id}
    ...               npe5__Primary__c=false
    ...               &{fields}

API Create Relationship
    [Documentation]  Creates a specified relationship between two contacts and sets default status as current if no value passed.
    ...              This keyword returns the relationship record as dictonary when called
    ...              Required parameters are:
    ...
    ...              |   contact_id    |   id of primary contact   |
    ...              |   relcontact_id    |   id of related contact   |
    ...              |   relation   | possible relation between contacts    |
    ...              |   field_api_name=value |   Ex: npe4__Status__c=Current   |
    [Arguments]      ${contact_id}      ${relcontact_id}    ${relation}    &{fields}
    ${rel_id} =  Salesforce Insert  npe4__Relationship__c
    ...                  npe4__Contact__c=${contact_id}
    ...                  npe4__RelatedContact__c=${relcontact_id}
    ...                  npe4__Type__c=${relation}
    ...                  npe4__Status__c=Current
    ...                  &{fields}
    &{relation} =     Salesforce Get  npe4__Relationship__c  ${rel_id}
    [return]         &{relation}

API Create Recurring Donation
    [Documentation]         Creates a recurring donation with specified fields.This keyword returns the recurring donation dictonary when called
    ...                     Syntax for passing parameters:
    ...
    ...                     |   field_api_name=value |   Ex: npe03__Installment_Period__c=Monthly   |
    [Arguments]        &{fields}
    ${ns} =            Get Npsp Namespace Prefix
    ${recurring_id} =  Salesforce Insert  npe03__Recurring_Donation__c
    ...                &{fields}
    &{recurringdonation} =           Salesforce Get     npe03__Recurring_Donation__c  ${recurring_id}
    [return]           &{recurringdonation}

API Create Payment
    [Documentation]   Creates a payment record for the specified opportunity record with given parameters passed
    [Arguments]       ${opportunity}     &{fields}
    ${pay_id} =       Salesforce Insert  npe01__OppPayment__c
    ...               npe01__Opportunity__c=${opportunity}
    ...               &{fields}
    &{payment} =      Salesforce Get  npe01__OppPayment__c  ${pay_id}
    [return]          &{payment}

API Query Installment
    [Documentation]         Queries for record on opportunity object using recurring donation id, installment and other specified fields
    ...                     This keyword returns the record found when called
    ...                     Syntax for passing parameters:
    ...
    ...                     |   id  |   recurring donation id   |
    ...                     |   installment |   installment name    |
    ...                     |   field_api_name=value |   Ex: npe03__Installment_Period__c=Monthly   |
    [Arguments]        ${id}                      ${installment}    &{fields}
    @{object} =        Salesforce Query           Opportunity
    ...                select=Id
    ...                npe03__Recurring_Donation__c=${id}
    ...                ${ns}Recurring_Donation_Installment_Name__c=${installment}
    ...                &{fields}
    [return]           @{object}

API Create GAU
    [Documentation]  If no arguments are passed, this keyword will create a GAU with Name
    ...              as random strings with no additional info. This keyword returns the GAU dictonary when called
    ...              Syntax for passing parameters:
    ...
    ...              | field api name=value   | Ex: Description=New GAU   |
    [Arguments]      &{fields}
    ${name} =   Generate Random String
    ${ns} =    Get Npsp Namespace Prefix
    ${gau_id} =  Salesforce Insert  ${ns}General_Accounting_Unit__c
    ...               Name=${name}
    ...               &{fields}
    &{gau} =     Salesforce Get  ${ns}General_Accounting_Unit__c  ${gau_id}
    [return]         &{gau}

API Create GAU Allocation
    [Documentation]  Creates GAU allocations for a specified opportunity. Pass either Amount or Percentage for Allocation
    ...              Required parameters are:
    ...
    ...              |   gau_id                   |   id of the gau that should be allocated    |
    ...              |   opp_id                   |   opportunity id    |
    ...              |   Amount__c or Percent__c  |   this should be either allocation amount or percent Ex:Amount__c=50.0 or Percent__c=10.0    |
    [Arguments]      ${gau_id}    ${opp_id}     &{fields}
    ${ns} =          Get Npsp Namespace Prefix
    ${all_id} =      Salesforce Insert  ${ns}Allocation__c
    ...              ${ns}General_Accounting_Unit__c=${gau_id}
    ...              ${ns}Opportunity__c=${opp_id}
    ...              &{fields}
    &{gau_alloc} =   Salesforce Get  ${ns}Allocation__c  ${all_id}
    [return]         &{gau_alloc}

API Modify Allocations Setting
    [Documentation]     Can be used to modify either Default Allocations or Payment Allocations.
    ...                 Required parameters are:
    ...
    ...                 |   field name and value   |   this would be key value pairs, Ex: Default_Allocations_Enabled__c=true   |
    [Arguments]         &{fields}
    ${ns} =             Get Npsp Namespace Prefix
    @{records} =        Salesforce Query      ${ns}Allocations_Settings__c
    ...                 select=Id
    &{setting} =        Get From List  ${records}  0
    Salesforce Update  ${ns}Allocations_Settings__c     ${setting}[Id]
    ...                 &{fields}
    &{alloc_setting} =  Salesforce Get  ${ns}Allocations_Settings__c  ${setting}[Id]
    [return]            &{alloc_setting}

API Create DataImportBatch
    [Documentation]     Creates a batch gift entry batch with specified key,value pairs and return the batch record when keyword is called.
    ...                 Required parameters are:
    ...
    ...                 |   field name and value   | Ex:Batch_Description__c=Created via API |
    [Arguments]      &{fields}
    ${name} =   Generate Random String
    ${ns} =  Get NPSP Namespace Prefix
    ${batch_id} =  Salesforce Insert  ${ns}DataImportBatch__c
    ...                  Name=${name}
    ...                  &{fields}
    &{batch} =     Salesforce Get  ${ns}DataImportBatch__c  ${batch_id}
    [return]         &{batch}

API Create DataImport
    [Documentation]     Creates a data import with specified key,value pairs and return the data import record when keyword is called.
    ...                 Required parameters are:
    ...
    ...                 |   field name and value   | Ex:Contact1_Firstname__c=John |
    [Arguments]         &{fields}
    ${ns} =             Get NPSP Namespace Prefix
    ${dataimport_id} =  Salesforce Insert  ${ns}DataImport__c
    ...                 &{fields}
    &{data_import} =    Salesforce Get  ${ns}DataImport__c  ${dataimport_id}
    [return]            &{data_import}

API Query Opportunity For Recurring Donation
    [Arguments]        ${id}                      &{fields}
    Sleep               2    #sleep here is necessary for the backend to get updated
    @{object} =        Salesforce Query           Opportunity
    ...                select=Id
    ...                npe03__Recurring_Donation__c=${id}
    ...                &{fields}
    [return]           @{object}

# Validate Batch Process When CRLP Unchecked
#     [Documentation]              Validates that all the Rollup Donations Batch processes complete successfully when CRLPs is disabled
#     Open NPSP Settings           Bulk Data Processes                Rollup Donations Batch
#     Click Settings Button        idPanelOppBatch                    Run Batch
#     Wait For Batch To Process    RLLP_OppAccRollup_BATCH            Completed
#     Wait For Batch To Process    RLLP_OppContactRollup_BATCH        Completed
#     Wait For Batch To Process    RLLP_OppHouseholdRollup_BATCH      Completed
#     Wait For Batch To Process    RLLP_OppSoftCreditRollup_BATCH     Completed

# Validate Batch Process When CRLP Checked
#     [Documentation]              Validates that all the Rollup Donations Batch processes complete successfully when CRLPs is enabled
#     Open NPSP Settings           Bulk Data Processes                      Rollup Donations Batch
#     Click Settings Button        idPanelOppBatch                          Run Batch
#     Wait For Batch To Process    CRLP_Account_SoftCredit_BATCH            Completed
#     Wait For Batch To Process    CRLP_RD_BATCH                            Completed
#     Wait For Batch To Process    CRLP_Account_AccSoftCredit_BATCH         Completed
#     Wait For Batch To Process    CRLP_Contact_SoftCredit_BATCH            Completed
#     Wait For Batch To Process    CRLP_Account_BATCH                       Completed
#     Wait For Batch To Process    CRLP_Contact_BATCH                       Completed

# Run Donations Batch Process
#     [Documentation]              Checks if customizable rollups is enabled and if enabled runs Validate Batch Process When CRLP Checked
#     ...                          else runs Validate Batch Process When CRLP UnChecked
#     Open NPSP Settings           Donations                     Customizable Rollups
#     ${crlp_enabled} =            Check Crlp Not Enabled By Default

#     #Open NPSP Settings and run Rollups Donations Batch job Validate the batch jobs completeness based accordingly
#     Run Keyword if      ${crlp_enabled} != True
#         ...             Validate Batch Process When CRLP Unchecked
#         ...     ELSE    Validate Batch Process When CRLP Checked

Run Donations Batch Process
    [Documentation]    Checks if customizable rollups is enabled via API and if enabled runs CRLP batch processes
    ...                else runs RLLP Batch Processes
    ${ns} =            Get NPSP Namespace Prefix
    @{records} =       Salesforce Query           ${ns}Customizable_Rollup_Settings__c
    ...                select=${ns}Customizable_Rollups_Enabled__c
    &{crlp} =          Get From List              ${records}  0
    #Open NPSP Settings and run Rollups Donations Batch job Validate the batch jobs completeness based accordingly
    Open NPSP Settings           Bulk Data Processes                      Rollup Donations Batch
    Click Settings Button        idPanelOppBatch                          Run Batch
    Run Keyword if     '${crlp}[${ns}Customizable_Rollups_Enabled__c]'!='True'
    ...                Run Keywords
    ...                Wait For Batch To Process    RLLP_OppAccRollup_BATCH            Completed
    ...         AND    Wait For Batch To Process    RLLP_OppContactRollup_BATCH        Completed
    ...         AND    Wait For Batch To Process    RLLP_OppHouseholdRollup_BATCH      Completed
    ...         AND    Wait For Batch To Process    RLLP_OppSoftCreditRollup_BATCH     Completed
    ...         ELSE   Run Keywords
    ...                Wait For Batch To Process    CRLP_Account_SoftCredit_BATCH            Completed
    ...         AND    Wait For Batch To Process    CRLP_RD_BATCH                            Completed
    ...         AND    Wait For Batch To Process    CRLP_Account_AccSoftCredit_BATCH         Completed
    ...         AND    Wait For Batch To Process    CRLP_Contact_SoftCredit_BATCH            Completed
    ...         AND    Wait For Batch To Process    CRLP_Account_BATCH                       Completed
    ...         AND    Wait For Batch To Process    CRLP_Contact_BATCH                       Completed

Scroll Page To Location
    [Documentation]     Scrolls window by pixels using javascript
    ...                 Required parameters are:
    ...
    ...                 |   x_location   | pixels to scroll by, along the x-axis(horizontal) |
    ...                 |   y_location   | pixels to scroll by, along the y-axis(vertical) |
    [Arguments]         ${x_location}    ${y_location}
    Execute JavaScript  window.scrollTo(${x_location},${y_location})

Open NPSP Settings
    [Documentation]           Goes to NPSP settings page and opens the sublist under the toplist
    ...                       Required parameters are:
    ...
    ...                       |   topmenu   | parent list Ex:Bulk Data Processes |
    ...                       |   submenu   | child list Ex:Rollup Donations Batch |
    [Arguments]               ${topmenu}     ${submenu}
    Go To Page                Custom         NPSP_Settings
    Open Main Menu            ${topmenu}
    Open Sub Link             ${submenu}
    Sleep  2

Click Data Import Button
    [Documentation]   Switches to the frame and clicks the button identified by path
    ...               Ex: Click Data Import Button  NPSP Data Import  button  Begin Data Import Process
    ...               Required parameters are:
    ...
    ...               |   frame_name   | name of the frame on the page |
    ...               |   ele_path   | button path specified in locator file |
    ...               |   others    |   parameters to identify button   |
    [Arguments]       ${frame_name}    ${ele_path}     @{others}
    Select Frame And Click Element    ${frame_name}    ${ele_path}     @{others}


Process Data Import Batch
    [Documentation]        Go to NPSP Data Import Page and change view to 'To be Imported' and Process Batch
    ...                    | status | expected status of batch processing Ex:'Completed' 'Errors' |
    [Arguments]    ${status}
    Go To Page                                         Listing                 DataImport__c
    Change View To                                     To Be Imported
    Click                                              Start Data Import
    Begin Data Import Process And Verify Status        BDI_DataImport_BATCH    ${status}
    Click Close Button

Enable Customizable Rollups
    [Documentation]        Go to NPSP Settings and check if Customizable Rollups are enabled
    ...                    if enabled does nothing but if disabled then enables.
    Go To Page                                Custom          NPSP_Settings
    Open Main Menu                            Donations
    Click Link With Text                      Customizable Rollups
    Enable Customizable Rollups If Not Enabled

Enable Advanced Mapping
    [Documentation]    This keyword enables advanced mapping if not already enabled.
    Go To Page                              Custom          NPSP_Settings
    Open Main Menu                          System Tools
    Click Link With Text                    Advanced Mapping for Data Import & Gift Entry
    Enable Advanced Mapping If Not Enabled

Create Customfield In Object Manager
    [Documentation]        Reads key value pair arguments.
    ...                    Navigates to Object Manager page and load fields and relationships for the specific object
    ...                    Runs keyword to create custom field
    ...                    Example key,value pairs
    ...                            Object=Payment
    ...                            Field_Type=Formula
    ...                            Field_Name=Is Opportunity From Prior Year
    ...                            Formula=YEAR( npe01__Opportunity__r.CloseDate ) < YEAR( npe01__Payment_Date__c )
    [Arguments]            &{fields}
    Load Page Object                                     Custom                           ObjectManager
    Open Fields And Relationships                        ${fields}[Object]
    Create Custom Field                                  &{fields}

Add Custom Picklist Values To Field
    [Documentation]        Reads key value pair arguments.
    ...                    Navigates to Object Manager page and load fields and relationships for the specific object
    ...                    Runs keyword to add picklist values
    ...                    Example key,value pairs
    ...                                                    Object=Recurring Donation
    ...                                                    Field_Name=Status
    ...                                                    Values=@{picklistvalues}
    [Arguments]            &{fields}
    Load Page Object                                     Custom                           ObjectManager
    Open Fields And Relationships                        ${fields}[Object]
    Add picklist values                                  &{fields}

Enable RD2QA
    [Documentation]        Enables Enhanced Recurring donations (RD2) settings and deploys the metadata

    ${apex}=  Catenate  SEPARATOR=\n
    ...   Map<String, Object> params = new Map<String, Object>{ 'ScheduleJobs' => true };
    ...   String shouldScheduleJobs = '%%%PARAM_1%%%';
    ...   if (!String.isEmpty(shouldScheduleJobs)) {
    ...         params.put('ScheduleJobs', Boolean.valueOf(shouldScheduleJobs));
    ...   }
    ...   String ns = ('%%%NAMESPACE%%%').replace('__','');
    ...   Type t = Type.forName(ns, 'Callable_Api');
    ...   Callable apiClass = (Callable)t.newInstance();
    ...   apiClass.call('Settings.EnableEnhancedRecurringDonations', params);

    ${apex2}=  Catenate  SEPARATOR=\n
    ...   Map<String, Object> params = new Map<String, Object>();
    ...   String ns = ('%%%NAMESPACE%%%').replace('__','');
    ...   Type t = Type.forName(ns, 'Callable_Api');
    ...   Callable apiClass = (Callable)t.newInstance();
    ...   apiClass.call('RD2.ExecuteDataMigration', params);

    ${apex3}=  Catenate  SEPARATOR=\n
    ...   npe03__Recurring_Donations_Settings__c rdSettings = npe03__Recurring_Donations_Settings__c.getOrgDefaults();
    ...   rdSettings.%%%NAMESPACE%%%RecurringDonations2EnablementState__c = '{"isReady":true,"isMigrationEnabled":true,"isMetaLaunched":true,"isMetaConfirmed":true,"isEnabled":true,"isDryRun2":false,"isConfirmed":true,"dryRunLimit":7}';
    ...   upsert rdSettings;

    # Enable customizable rollups after enabling RD2
    Run Task       enable_crlp
    # Wait for CRLP to be fully enabled before continuing with data migration
    Run Task       custom_settings_value_wait
    ...            object=%%%NAMESPACE%%%Customizable_Rollup_Settings__c
    ...            field=%%%NAMESPACE%%%Customizable_Rollups_Enabled__c
    ...            value=true
    # Enables RD2 in Custom Settings.
    Run Task       execute_anon
    ...            apex= ${apex}
    # Deploys the unpackaged configuration required for RD2
    Run Task       deploy_rd2_config
    # Execute the data migration job in case there is any RD test data in the org
    Run Task       execute_anon
    ...            apex= ${apex2}
    Run Task       batch_apex_wait
    ...            class_name=RD2_DataMigration_BATCH
    # Update enhanced Recurring Donation enablement page state
    Run Task       execute_anon
    ...            apex= ${apex3}

API Query Recurrring Donation Settings For RD2 Enablement
    [Documentation]    Queries the Recurring Donation settings object for the RD2 Enabled status and returns the boolean status value
    ${ns} =            Get Npsp Namespace Prefix
    @{record} =        Salesforce Query      npe03__Recurring_Donations_Settings__c
    ...                select=${ns}IsRecurringDonations2Enabled__c
    &{rd2_enabled} =                 Get From List  ${record}  0
    [return]           ${rd2_enabled}[${ns}IsRecurringDonations2Enabled__c]

Enable RD2
    [Documentation]           Checks if Rd2 settings are already enabled and then run the scripts to enable RD2
    ${is_rd2_enabled} =       API Query Recurrring Donation Settings For RD2 Enablement
    ${ns} =                   Get Npsp Namespace Prefix
    Log                       ${ns}
    ${return} =                Run Keyword if            "${is_rd2_enabled}"!="True" and "${ns}"!="npsp__"
    ...                        Run Flow                  enable_rd2
    Run Keyword if            "${is_rd2_enabled}"!="True" and "${ns}"=="npsp__"
    ...                        Run flow                  enable_rd2_managed
    Run Keyword if            "${return}"!="None"
    ...                       Log           ${return.stdout}
    Run Keyword if            "${return}"!="None"
    ...                       Log           ${return.stderr}
    Run Keyword if            "${return}"!="None"
    ...                       Should Be Equal As Integers	    ${return.rc}	    0
    Sleep                     1                                 Wait Added For Metadata Get Loaded

Run Recurring Donations Batch
    [Documentation]              Triggers Recurring Donations Batch Job And Waits For the Batch Job To Complete Depending On the Type
    [Arguments]                  ${type}
    Open NPSP Settings           Bulk Data Processes               Recurring Donations Batch
    Click Settings Button        idPanelRDBatch                    Run Batch
    Run Keyword if               "${type}"!="RD2"
    ...                          Wait For Batch To Process         RD_RecurringDonations_BATCH       Completed
    ...     ELSE                 Wait For Batch To Process         RD2_OpportunityEvaluation_BATCH   Completed

API Get Id
    [Documentation]         Returns the ID of a record identified by the given field_name and field_value input for a specific object
    [Arguments]             ${obj_name}    &{fields}
    @{records} =            Salesforce Query      ${obj_name}
    ...                         select=Id
    ...                         &{fields}
    &{Id} =                 Get From List  ${records}  0
    [return]                ${Id}[Id]

Enable Gift Entry
    [Documentation]    This keyword enables advanced mapping(prerequisite) and gift entry if not already enabled.
    Go To Page                              Custom          NPSP_Settings
    Open Main Menu                          System Tools
    Click Link With Text                    Advanced Mapping for Data Import & Gift Entry
    Enable Gift Entry If Not Enabled

API Query Record
    [Documentation]    Queries the given object table by using key,value pair passed and returns the entire record
    [Arguments]        ${object_name}             &{fields}
    @{records} =       Salesforce Query           ${object_name}
    ...                select=Id
    ...                &{fields}
    &{Id} =            Get From List  ${records}  0
    &{myrecord} =      Salesforce Get  ${object_name}  ${Id}[Id]
    [return]           &{myrecord}

API Check And Enable Gift Entry
    [Documentation]    Checks through API if Advanced Mapping and Gift Entry are already enabled. If yes then does nothing.
    ...                If either of them are not enabled then calls the Enable Gift Entry keyword to enable them
    ${ns} =             Get NPSP Namespace Prefix
    @{records} =       Salesforce Query           ${ns}Data_Import_Settings__c
    ...                select=${ns}Field_Mapping_Method__c
    &{am} =            Get From List  ${records}  0
    @{records} =       Salesforce Query           ${ns}Gift_Entry_Settings__c
    ...                select=${ns}Enable_Gift_Entry__c
    &{ge} =            Get From List  ${records}  0
    Run Keyword if     '${am}[${ns}Field_Mapping_Method__c]'!='Data Import Field Mapping' or '${ge}[${ns}Enable_Gift_Entry__c]'!='True'
    ...                Enable Gift Entry

Add instance to suite metadata
    [Documentation]     Logs the org instance number in the metadata on the log
    &{org_info} =       Get Org Info
    Set suite metadata  Org Instance:  ${org_info['instance_name']}  top=True

API Create Lead
    [Documentation]     creates a lead record using given field api name and value pairs and
    ...                 returns the lead dictionary when called.
    ...                 Syntax for passing parameters:
    ...
    ...                 | field_api_name=value   | Ex: MobilePhone=1234567098    |
    [Arguments]         &{fields}
    ${lead_id} =        Salesforce Insert  Lead
    ...                 &{fields}
    &{lead} =           Salesforce Get  Lead  ${lead_id}
    [return]            &{lead}

Create Gift Entry Batch
    [Documentation]     Creates a new gift entry batch using the template specified and with given name
    [Arguments]         ${template}    ${batch_name}
    Click Gift Entry Button                 New Batch
    Wait Until Modal Is Open
    Select Template                         ${template}
    Load Page Object                        Form                            Gift Entry
    Fill Gift Entry Form
    ...                                     Batch Name=${batch_name}
    ...                                     Batch Description=This is a test batch created via automation script
    Click Gift Entry Button                 Next
    Click Gift Entry Button                 Save

Verify Error Message on AM Page And Object Group
    [Documentation]         Verifies error is thrown on Advanced mapping and object group page for missing field mapping
    [Arguments]             ${object_group}     ${field}
    Go To Page                          Custom          NPSP_Settings
    Open Main Menu                      System Tools
    Click Link With Text                Advanced Mapping for Data Import & Gift Entry
    Click Configure Advanced Mapping
    Wait Until Page Contains Element    npsp:npsp_settings.page_error:warning,${object_group} : ${field} (${field}__c)
    View Field Mappings Of The Object   Account 1
    Wait Until Page Contains Element    npsp:npsp_settings.page_error:warning,${object_group} : ${field} (${field}__c)
    Page Should Contain Element         npsp:npsp_settings.field_error:custom_acc_text__c

Verify No Errors Displayed on AM Page And Object Group
    [Documentation]         Verifies error is not thrown on Advanced mapping and object group page for given field mapping
    [Arguments]             ${object_group}     ${field}
    Go To Page                          Custom          NPSP_Settings
    Open Main Menu                      System Tools
    Click Link With Text                Advanced Mapping for Data Import & Gift Entry
    Click Configure Advanced Mapping
    Page Should Not Contain Locator     npsp_settings.page_error    warning     ${object_group} : ${field} (${field}__c)
    Page Should Not Contain Locator     gift_entry.page_error
    View Field Mappings Of The Object   Account 1
    Page Should Not Contain Locator     npsp_settings.page_error    warning     ${object_group} : ${field} (${field}__c)
    Wait For Locator Is Not Visible     npsp_settings.field_error   ${field}__c

Change Object Permissions
    [Documentation]  Adds or removes the Create, Read, Edit and Delete permissions for the specified object on the specified permission set..
    [Arguments]  ${action}  ${objectapiname}  ${permset}


    ${removeobjperms} =  Catenate  SEPARATOR=\n
    ...  ObjectPermissions objperm;
    ...  objperm = [SELECT Id, PermissionsRead, PermissionsEdit, PermissionsCreate, PermissionsDelete FROM ObjectPermissions 
    ...  WHERE parentId IN ( SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}') 
    ...  AND SobjectType='${objectapiname}']; 
    ...  objperm.PermissionsRead = false; 
    ...  objperm.PermissionsEdit = false; 
    ...  objperm.PermissionsCreate = false; 
    ...  objperm.PermissionsDelete = false; 
    ...  update objperm; 

    ${addobjperms} =  Catenate  SEPARATOR=\n
    ...  String permid = [SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}'].id;
    ...  ObjectPermissions objperm = New ObjectPermissions(PermissionsRead = true, PermissionsEdit = true, PermissionsCreate = true, 
    ...  PermissionsDelete = true, ParentId = permid, SobjectType='${objectapiname}');
    ...  insert objperm;

    Run Keyword if  "${action}" == "remove"
    ...             Run Task  execute_anon
    ...             apex= ${removeobjperms}

    Run Keyword if  "${action}" == "add"
    ...             Run Task  execute_anon
    ...             apex= ${addobjperms}

Change Field Permissions
    [Documentation]  Adds or removes the Create, Read, Edit and Delete permissions for the specified object field on the specified permission set.
    [Arguments]  ${action}  ${objectapiname}  ${fieldapiname}  ${permset}

    ${removefieldperms} =  Catenate  SEPARATOR=\n
    ...  FieldPermissions fldperm;
    ...  fldperm = [SELECT Id, Field, PermissionsRead, PermissionsEdit FROM FieldPermissions 
    ...  WHERE parentId IN ( SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}')
    ...  AND SobjectType='${objectapiname}'
    ...  AND Field='${objectapiname}.${fieldapiname}'];        
    ...  fldperm.PermissionsRead = false;
    ...  fldperm.PermissionsEdit = false;
    ...  update fldperm;

    ${addfieldperms} =  Catenate  SEPARATOR=\n
    ...  String permid = [SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}'].id;
    ...  FieldPermissions fldperm = New FieldPermissions(PermissionsRead = true, PermissionsEdit = true,
    ...  ParentId = permid, Field = '${objectapiname}.${fieldapiname}', SobjectType='${objectapiname}');
    ...  insert fldperm;

    Run Keyword if  "${action}" == "remove"
    ...             Run Task  execute_anon
    ...             apex= ${removefieldperms}

    Run Keyword if  "${action}" == "add"
    ...             Run Task  execute_anon
    ...             apex= ${addfieldperms}

Object Permissions Cleanup
   [Documentation]  Resets all object permissions in case a test fails before they are restored. Skips the reset if the permissions have already been added back.
   [Arguments]  ${objectapiname}  ${permset}
 
   ${addobjback} =  Catenate  SEPARATOR=\n
   ...  List<ObjectPermissions> checkperms = [SELECT PermissionsRead FROM ObjectPermissions 
   ...  WHERE parentId IN ( SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}') AND
   ...  SobjectType = '${objectapiname}'];
   ...  if (checkperms.isEmpty()) {
   ...  String permid = [SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}'].id;
   ...  ObjectPermissions objperm = New ObjectPermissions(PermissionsRead = true, PermissionsEdit = true, PermissionsCreate = true, 
   ...  PermissionsDelete = true, ParentId = permid, SobjectType = '${objectapiname}');
   ...  insert objperm; }
   ...  else { System.debug('Permissions Exist, skipping.'); }
 
   Run Task  execute_anon  apex=${addobjback}


Field Permissions Cleanup
   [Documentation]  Resets all field permissions in case a test fails before they are restored. Skips the reset if the permissions have already been added back.
   [Arguments]  ${objectapiname}  ${fieldapiname}  ${permset}
 
   ${ns} =  Get NPSP Namespace Prefix
 
   ${addfieldback} =  Catenate  SEPARATOR=\n
   ...  List<FieldPermissions> checkperms = [SELECT PermissionsRead FROM FieldPermissions 
   ...  WHERE parentId IN ( SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}') AND
   ...  SobjectType = '${objectapiname}' AND Field = '${objectapiname}.${fieldapiname}'];
   ...  if (checkperms.isEmpty()) {
   ...  String permid = [SELECT id FROM permissionset WHERE PermissionSet.Name = '${permset}'].id;
   ...  FieldPermissions fldperm = New FieldPermissions(PermissionsRead = true, PermissionsEdit = true, 
   ...  ParentId = permid, Field = '${objectapiname}.${fieldapiname}', SobjectType = '${objectapiname}');
   ...  insert fldperm; }
   ...  else { System.debug('Permissions Exist, skipping.'); }
 
   Run Task  execute_anon  apex=${addfieldback}


Return Field Value
    [Documentation]
    [Arguments]  ${objectapiname}  ${rec_id}  ${field}

    @{records} =  SOQL Query    SELECT ${field} FROM ${objectapiname} where Id = '${rec_id}'
    &{field_value} =            Get From List  ${records}  0

    [Return]  &{field_value}