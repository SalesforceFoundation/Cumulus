*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/GiftEntryPageObject.py
...             robot/Cumulus/resources/OpportunityPageObject.py
...             robot/Cumulus/resources/PaymentPageObject.py
...             robot/Cumulus/resources/AccountPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             API Check And Enable Gift Entry
...             Setup Test Data
Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Keywords ***
Setup Test Data
    &{account} =         API Create Organization Account    Name=${faker.company()}
    Set suite variable   &{ACCOUNT}
    ${date} =            Get Current Date         result_format=%Y-%m-%d
    Set suite variable   ${DATE}
    &{opportunity} =     API Create Opportunity   ${account}[Id]              Donation
    ...                  StageName=Prospecting
    ...                  Amount=150
    ...                  CloseDate=${date}
    ...                  npe01__Do_Not_Automatically_Create_Payment__c=false
    ...                  Name=${account}[Name] Donation

*** Test Cases ***
Review Donation And Create Opportunity For SGE
    [Documentation]                      Create an organization account with open opportunity (with payment record) via API. Go to SGE form
    ...                                  select the donor as account and the account created. Verify review donations modal but select to create alternative opportunity.
    ...                                  Enter details and save. Verify that new opportunity and payment are created with right info
    [tags]                               feature:GE                    W-039564
    #verify Review Donations link is available and create a new opportunity using SGE form
    Go To Page                           Landing                       GE_Gift_Entry
    Click Gift Entry Button              New Single Gift
    Current Page Should Be               Form                          Gift Entry
    Fill Gift Entry Form
    ...                                  Donor Type=Account1
    ...                                  Existing Donor Organization=${ACCOUNT}[Name]
    Click Button                         Review Donations
    Wait Until Modal Is Open
    Click Button                         Alternatively, create a new Opportunity.
    Wait Until Modal Is Closed
    Fill Gift Entry Form
    ...                                  Donation Date=Today
    ...                                  Donation Amount=150
    Click Button                         Save
    #verify new opportunity and its payment are created with correct info
    Current Page Should Be               Details                        Opportunity
    ${newopp_id}                         Save Current Record ID For Deletion     Opportunity
    Verify Expected Values               nonns                          Opportunity    ${newopp_id}
    ...                                  Amount=150.0
    ...                                  CloseDate=${DATE}
    ...                                  StageName=Closed Won
    Select Tab                           Related
    Click Related Table Item Link        Payments                       Paid
    Current Page Should Be               Details                        npe01__OppPayment__c
    ${pay_id}                            Save Current Record ID For Deletion     npe01__OppPayment__c
    Verify Expected Values               nonns                          npe01__OppPayment__c    ${pay_id}
    ...                                  npe01__Payment_Amount__c=150.0
    ...                                  npe01__Payment_Date__c=${DATE}
    ...                                  npe01__Paid__c=True
    #verify account has two opportunities listed
    Go To Page                           Details                        Account         object_id=${ACCOUNT}[Id]
    Validate Related Record Count        Opportunities                  2

