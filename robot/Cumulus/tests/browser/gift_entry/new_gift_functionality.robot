*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/GiftEntryPageObject.py
...             robot/Cumulus/resources/OpportunityPageObject.py
...             robot/Cumulus/resources/ContactPageObject.py
...             robot/Cumulus/resources/AccountPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             API Check And Enable Gift Entry
...             Setup Test Data
Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Keywords ***
Setup Test Data
    [Documentation]      Creates the organiation account and household contact record
    ...                  along with getting dates required for test.
    &{ACCOUNT} =         API Create Organization Account    Name=${faker.company()}
    ...                  BillingStreet=${faker.street_address()}
    ...                  BillingCity=${faker.city()}
    ...                  BillingState=California
    ...                  BillingPostalCode=${faker.postcode()}
    Set suite variable   &{ACCOUNT}
    ${DATE} =            Get Current Date         result_format=%Y-%m-%d
    Set suite variable   ${DATE}
    &{CONTACT} =         API Create Contact
    ...                  FirstName=${faker.first_name()}
    ...                  LastName=${faker.last_name()}
    ...                  npe01__HomeEmail__c=test@example.com
    Set suite variable   &{CONTACT}

*** Test Cases ***
Create Gift For Contact Using New Gift Button
    [Documentation]                      Open a contact record and click on New Gift button from the actions menu of the page.
    ...                                  Verify that Single Gift form is loaded with prepopulated contact info and create a gift.
    ...                                  Verify that opp page is loaded on save. Verify that new opportunity and payment are created with right info
    [tags]                               feature:GE                    W-039584
    Go To Page                           Details              Contact       object_id=${CONTACT}[Id]
    Current Page Should Be               Details              Contact
    Click Button                         New Gift
    Current Page Should Be               Form                          Gift Entry
    Verify Field Default Value
    ...                                  Existing Donor Contact=${CONTACT}[Name]
    ...                                  Contact First Name=${CONTACT}[FirstName]
    ...                                  Contact Last Name=${CONTACT}[LastName]
    ...                                  Contact Personal Email=${CONTACT}[npe01__HomeEmail__c]
    Fill Gift Entry Form
    ...                                  Donation Date=Today
    ...                                  Donation Amount=150
    Click Button                         Save
    #verify new opportunity and its payment are created with correct info
    Current Page Should Be               Details              Opportunity
    ${newopp_id}                         Save Current Record ID For Deletion    Opportunity
    Verify Expected Values               nonns                Opportunity       ${newopp_id}
    ...                                  Amount=150.0
    ...                                  CloseDate=${DATE}
    ...                                  StageName=Closed Won
    &{payment} =  API Query Record       npe01__OppPayment__c      npe01__Opportunity__c=${newopp_id}
    Verify Expected Values               nonns                          npe01__OppPayment__c    ${payment}[Id]
    ...                                  npe01__Payment_Amount__c=150.0
    ...                                  npe01__Payment_Date__c=${DATE}
    ...                                  npe01__Paid__c=True

Create Gift For Account Using New Gift Button
    [Documentation]                      Open a Organization Account record and click on New Gift button from the actions menu of the page.
    ...                                  Verify that Single Gift form is loaded with prepopulated Account info and create a gift.
    ...                                  Verify that opp page is loaded on save. Verify that new opportunity and payment are created with right info
    [tags]                               feature:GE                    W-039584
    Go To Page                           Details              Account       object_id=${ACCOUNT}[Id]
    Current Page Should Be               Details              Account
    Click Button                         New Gift
    Current Page Should Be               Form                          Gift Entry
    Verify Field Default Value
    ...                                  Existing Donor Organization=${ACCOUNT}[Name]
    ...                                  Organization Account Street=${ACCOUNT}[BillingStreet]
    ...                                  Organization Account City=${ACCOUNT}[BillingCity]
    ...                                  Organization Account State/Province=${ACCOUNT}[BillingState]
    ...                                  Organization Account Zip/Postal Code=${ACCOUNT}[BillingPostalCode]
    Fill Gift Entry Form
    ...                                  Donation Date=Today
    ...                                  Donation Amount=1500
    Click Button                         Save
    #verify new opportunity and its payment are created with correct info
    Current Page Should Be               Details              Opportunity
    ${newopp_id}                         Save Current Record ID For Deletion    Opportunity
    Verify Expected Values               nonns                Opportunity       ${newopp_id}
    ...                                  Amount=1500.0
    ...                                  CloseDate=${DATE}
    ...                                  StageName=Closed Won
    &{payment} =  API Query Record       npe01__OppPayment__c      npe01__Opportunity__c=${newopp_id}
    Verify Expected Values               nonns                          npe01__OppPayment__c    ${payment}[Id]
    ...                                  npe01__Payment_Amount__c=1500.0
    ...                                  npe01__Payment_Date__c=${DATE}
    ...                                  npe01__Paid__c=True
