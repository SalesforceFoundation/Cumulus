*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/GiftEntryPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             API Check And Enable Gift Entry
...             Setup Test Data
Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Keywords ***
Setup Test Data
    [Documentation]      Creates the contact,opportunity along with getting dates and namespace required for test.
    &{CONTACT} =         API Create Contact    FirstName=${faker.first_name()}    LastName=${faker.last_name()}
    Set suite variable   &{CONTACT}
    ${FUT_DATE} =            Get Current Date         result_format=%Y-%m-%d    increment=2 days
    Set suite variable   ${FUT_DATE}
    ${CUR_DATE} =            Get Current Date         result_format=%Y-%m-%d
    Set suite variable   ${CUR_DATE}
    &{OPPORTUNITY} =     API Create Opportunity   ${CONTACT}[AccountId]              Donation
    ...                  StageName=Prospecting
    ...                  Amount=500
    ...                  CloseDate=${FUT_DATE}
    ...                  npe01__Do_Not_Automatically_Create_Payment__c=false
    ...                  Name=${CONTACT}[Name] Donation
    Set suite variable   &{OPPORTUNITY}
    ${UI_DATE} =         Get Current Date                   result_format=%b %-d, %Y
    Set suite variable   ${UI_DATE}
    &{PAYMENT1} =         API Query Record         npe01__OppPayment__c      npe01__Opportunity__c=${OPPORTUNITY}[Id]
    Set suite variable   &{PAYMENT1}
    ${NS} =              Get NPSP Namespace Prefix
    Set suite variable   ${NS}

*** Test Cases ***
Review Donation And Create Payment For Batch Gift
    [Documentation]       Create a contact with open opportunity (with payment record) via API. Go to GE create a batch with default template.
    ...                   With donor as contact created, open review donations modal and select add payment. Change date to today and payment amt < opp amt.
    ...                   Verify that opp shows in table and on processing creates a paymment but opp is still prospecting and amt is not updated.
    ...                   Create another payment with total > opp amt and verify opp is closed and opp date is payment date. Verify original payment is not updated.
    [tags]                               feature:GE                    W-042803
    #verify Review Donations link is available and create a payment
    Go To Page                           Landing                       GE_Gift_Entry
    Click Gift Entry Button              New Batch
    Wait Until Modal Is Open
    Select Template                      Default Gift Entry Template
    Load Page Object                     Form                          Gift Entry
    Fill Gift Entry Form
    ...                                  Batch Name=${CONTACT}[Name]Automation Batch
    ...                                  Batch Description=This is a test batch created via automation script
    Click Gift Entry Button              Next
    Click Gift Entry Button              Save
    Current Page Should Be               Form                          Gift Entry
    ${batch_id} =                        Save Current Record ID For Deletion     ${NS}DataImportBatch__c
    Fill Gift Entry Form
    ...                                  Donor Type=Contact1
    ...                                  Existing Donor Contact=${CONTACT}[Name]
    Click Button                         Review Donations
    Wait Until Modal Is Open
    Click Button                         Add new Payment
    Wait Until Modal Is Closed
    Fill Gift Entry Form
    ...                                  Donation Amount=300
    ...                                  Donation Date=Today
    Click Button                         Save & Enter New Gift
    #verify donation date and amount values changed on table
    Verify Gift Count                    1
    Verify Table Field Values            Batch Gifts
    ...                                  Donor Name=${CONTACT}[Name]
    ...                                  Donation Amount=$300.00
    ...                                  Donation Name=${OPPORTUNITY}[Name]
    ...                                  Donation Date=${UI_DATE}
    Scroll Page To Location              0      0
    Click Gift Entry Button              Process Batch
    Click Data Import Button             NPSP Data Import                button       Begin Data Import Process
    Wait For Batch To Process            BDI_DataImport_BATCH            Completed
    Click Button With Value              Close
    #verify a payment record is created and paid but opportunity values did not change
    Verify Expected Values               nonns                          Opportunity    ${OPPORTUNITY}[Id]
    ...                                  Amount=500.0
    ...                                  CloseDate=${FUT_DATE}
    ...                                  StageName=Prospecting
    ...                                  npe01__Amount_Outstanding__c=200.0
    Current Page Should Be               Form                          Gift Entry
    ${pay_id}                            Get Record Id From Field link        bge.value                     Donation Name
    Verify Expected Values               nonns                          npe01__OppPayment__c    ${pay_id}
    ...                                  npe01__Opportunity__c=${OPPORTUNITY}[Id]
    ...                                  npe01__Payment_Amount__c=300.0
    ...                                  npe01__Payment_Date__c=${CUR_DATE}
    ...                                  npe01__Paid__c=True
    #create another payment for opportunity higher than opportunity amount
    Fill Gift Entry Form
    ...                                  Donor Type=Contact1
    ...                                  Existing Donor Contact=${CONTACT}[Name]
    Click Button                         Review Donations
    Wait Until Modal Is Open
    Click Button                         Add new Payment
    Wait Until Modal Is Closed
    Fill Gift Entry Form
    ...                                  Donation Amount=250
    ...                                  Donation Date=Today
    Click Button                         Save & Enter New Gift
    Verify Gift Count                    2
    Scroll Page To Location              0      0
    Click Gift Entry Button              Process Batch
    Click Data Import Button             NPSP Data Import                button       Begin Data Import Process
    Wait For Batch To Process            BDI_DataImport_BATCH            Completed
    Click Button With Value              Close
    #verify opportunity is closed with correct date and amount and intial payment record is still open
    Verify Expected Values               nonns                          Opportunity    ${OPPORTUNITY}[Id]
    ...                                  Amount=500.0
    ...                                  CloseDate=${CUR_DATE}
    ...                                  StageName=Closed Won
    ...                                  npe01__Amount_Outstanding__c=-50.0
    Verify Expected Values               nonns                          npe01__OppPayment__c    ${PAYMENT1}[Id]
    ...                                  npe01__Payment_Amount__c=500.0
    ...                                  npe01__Scheduled_Date__c=${FUT_DATE}
    ...                                  npe01__Paid__c=False
