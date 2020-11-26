*** Settings ***
Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/GiftEntryPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             Setup Test Data
...             API Check And Enable Gift Entry
Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Variables ***
&{CONTACT}        Email=test@example.com
${TEMPLATE}       Labels Template
&{DATE}           Field Label=Closed Date
&{CAMPAIGN}       Field Label=Campaign
&{PAY}            Field Label=Check Number
&{RECORD_TYPE}    Field Label=Record Type

*** Keywords ***
Setup Test Data
    Setupdata   contact   ${CONTACT}
    &{campaign_rec} =    API Create Campaign
    Set suite variable   &{CAMPAIGN_REC}
    ${ns} =  Get NPSP Namespace Prefix
    Set suite variable    ${NS}
    ${ui_date} =    Get Current Date                   result_format=%b %-d, %Y
    Set suite variable    ${UI_DATE}

*** Test Cases ***

Verify Changing Labels on Template Gets Updated on Batches
    [Documentation]                         Create a template with Record Type and Campagin Lookup fields, custom labels for lookup, date and text fields
    ...                                     and finally add these fields to batch table. Using this new template create a batch and verify that labels are updated on batch form
    ...                                     Create a gift and verify batch table field names are updated as well and verify that batch is processed without errors.
    [tags]                                  feature:GE        W-042499
    #Create new template with new field labels
    Go To Page                              Landing                         GE_Gift_Entry
    Click Link                              Templates
    Click Gift Entry Button                 Create Template
    Current Page Should Be                  Template                        GE_Gift_Entry
    Enter Value In Field
    ...                                     Template Name=${TEMPLATE}
    ...                                     Description=This is created by automation script
    Click Gift Entry Button                 Next: Form Fields
    Perform Action On Object Field          select                          Opportunity           Record Type ID
    Fill Template Form
    ...                                     Opportunity: Close Date=&{DATE}
    ...                                     Opportunity: Campaign ID=&{CAMPAIGN}
    ...                                     Payment: Check/Reference Number=&{PAY}
    ...                                     Opportunity: Record Type ID=&{RECORD_TYPE}
    Click Gift Entry Button                 Next: Batch Settings
    Add Batch Table Columns                 Campaign                        Check Number          Record Type
    Click Gift Entry Button                 Save & Close
    Current Page Should Be                  Landing                         GE_Gift_Entry
    Click Link                              Templates
    Wait Until Page Contains                ${TEMPLATE}
    Store Template Record Id                ${TEMPLATE}
    #Verify new field labels are displayed on newly created batch with new template
    Click Gift Entry Button                 New Batch
    Wait Until Modal Is Open
    Select Template                         ${TEMPLATE}
    Load Page Object                        Form                            Gift Entry
    Fill Gift Entry Form
    ...                                     Batch Name=${CAMPAIGN_REC}[Name] Automation Batch
    ...                                     Batch Description=This is a test batch created via automation script
    Click Gift Entry Button                 Next
    Click Gift Entry Button                 Save
    Current Page Should Be                  Form                            Gift Entry            title=Gift Entry Form
    ${batch_id} =                           Save Current Record ID For Deletion     ${NS}DataImportBatch__c
    Wait Until Page Contains Element        npsp:label:${DATE}[Field Label]
    Page Should Contain Element             npsp:label:${CAMPAIGN}[Field Label]
    Page Should Contain Element             npsp:label:${PAY}[Field Label]
    Page Should Contain Element             npsp:label:${RECORD_TYPE}[Field Label]
    Fill Gift Entry Form
    ...                                     Data Import: Donation Donor=Contact1
    ...                                     Data Import: Contact1 Imported=${data}[contact][Name]
    ...                                     ${DATE}[Field Label]=Today
    ...                                     Opportunity: Amount=150
    ...                                     ${CAMPAIGN}[Field Label]=${CAMPAIGN_REC}[Name]
    ...                                     ${PAY}[Field Label]=74454354
    ...                                     ${RECORD_TYPE}[Field Label]=Donation
    Click Button                            Save & Enter New Gift
    #Verify gift is created with correct values and labels are updated on the table and process batch
    Verify Gift Count                       1
    Wait Until Page Contains Element        npsp:gift_entry.field_span:Batch Gifts,${DATE}[Field Label]
    Page Should Contain Element             npsp:gift_entry.field_span:Batch Gifts,${CAMPAIGN}[Field Label]
    Page Should Contain Element             npsp:gift_entry.field_span:Batch Gifts,${PAY}[Field Label]
    Page Should Contain Element             npsp:gift_entry.field_span:Batch Gifts,${RECORD_TYPE}[Field Label]
    Verify Table Field Values               Batch Gifts
    ...                                     Donor Name=${data}[contact][Name]
    ...                                     Opportunity: Amount=$150.00
    ...                                     ${CAMPAIGN}[Field Label]=${CAMPAIGN_REC}[Name]
    ...                                     ${PAY}[Field Label]=74454354
    ...                                     ${RECORD_TYPE}[Field Label]=Donation
    ...                                     ${DATE}[Field Label]=${UI_DATE}
    Click Gift Entry Button                 Process Batch
    Click Data Import Button                NPSP Data Import                button       Begin Data Import Process
    Wait For Batch To Process               BDI_DataImport_BATCH            Completed
    Click Button With Value                 Close

