*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/NPSPSettingsPageObject.py
...             robot/Cumulus/resources/ContactPageObject.py
...             robot/Cumulus/resources/RecurringDonationsPageObject.py
...             robot/Cumulus/resources/OpportunityPageObject.py
Suite Setup     Run keywords
...             Open Test Browser
...             Setup Test Data
...             Enable RD2
Suite Teardown  Delete Records and Close Browser

*** Keywords ***
Setup Test Data
     ${EFFECTIVE_DATE_INITIAL} =           Get Current Date      result_format=%-m/%-d/%Y
     ${DATE}=                              Get current date      result_format=%Y-%m-%d %H:%M:%S.%f      increment=30 days
     ${DATE_TO_UPDATE} =                   Convert Date          ${DATE}                                 result_format=%Y-%m-%d
     ${EFFECTIVE_MODIFIED_DATE}=           Get current date      result_format=%-d/%-m/%Y                increment=30 days
     ${CURRDATE}=                          Get Current Date      result_format=datetime
     ${CURRENTVALUE} =                     Evaluate              (${CURRDATE.month-1}) * 100
     ${CURRENTVALUE_EDITED}=               Evaluate              (${CURRDATE.month}*100) + 150
     Set Suite Variable  ${CURRENTVALUE}
     Set Suite Variable  ${DATE}
     Set Suite Variable  ${EFFECTIVE_MODIFIED_DATE}
     Set Suite Variable  ${CURRENTVALUE_EDITED}
     Set Suite Variable  ${EFFECTIVE_DATE_INITIAL}
     Set Suite Variable  ${DATE_TO_UPDATE}

     &{contact1_fields}=              Create Dictionary          Email=rd2tester@example.com
     &{recurringdonation_fields} =	  Create Dictionary          Name=ERDTest1
     ...                                                         npe03__Installment_Period__c=Monthly
     ...                                                         npe03__Amount__c=100
     ...                                                         npe03__Open_Ended_Status__c=${TYPE}
     ...                                                         Status__c=Active
     ...                                                         Day_of_Month__c=${DAY_OF_MONTH}
     ...                                                         InstallmentFrequency__c=${FREQUENCY}
     ...                                                         PaymentMethod__c=${METHOD}

     Setupdata   contact             ${contact1_fields}          recurringdonation_data=${recurringdonation_fields}


*** Variables ***
${FREQUENCY}  1
${DAY_OF_MONTH}  15
${AMOUNT_TO_UPDATE}  150
${METHOD}  Credit Card
${TYPE}    Open

*** Test Cases ***

Edit An Enhanced Recurring donation record of type open
    [Documentation]               After creating an open recurring donation using API, The test ensures that when the record
     ...                          is edited and effective date is updated to next month , Verifies that future schedule is shown
     ...                          with the right values reflected. Verifies the current year and future year schedules are updated
     ...                          Verifies the opportunity status
    [tags]                                   unstable               W-041167            feature:RD2

    Go To Page                               Details
    ...                                      npe03__Recurring_Donation__c
    ...                                      object_id=${data}[contact_rd][Id]

    Validate Field Values Under Section
    ...                                      Amount=$100.00
    ...                                      Status=Active
    # Validate the fields under Current Schedule card
    Validate Field Values Under Section      Current Schedule
    ...                                      Amount=$100.00
    ...                                      Payment Method=Credit Card
    ...                                      Effective Date=${EFFECTIVE_DATE_INITIAL}
    ...                                      Installment Period=Monthly
    ...                                      Day of Month=15
    # validate recurring donation statistics current and next year value
    Validate Field Values Under Section      Statistics
    ...                                      Current Year Value=$${CURRENTVALUE}.00
    ...                                      Next Year Value=$1,200.00
    #Query the opportunity ID associated with the recurring donation. Navigate to the opportunity and validate the status
    @{opportunity1} =                        API Query Opportunity For Recurring Donation                   ${data}[contact_rd][Id]
    Store Session Record                     Opportunity                                                    ${opportunity1}[0][Id]
    Go To Page                               Details                        Opportunity                     object_id=${opportunity1}[0][Id]
    Navigate To And Validate Field Value     Stage                          contains                        Pledged
    #Using backend API update the recurring donation record and modify the startDate field to next month's date
    API Modify Recurring Donation            ${data}[contact_rd][Id]
    ...                                      npe03__Amount__c=${AMOUNT_TO_UPDATE}
    ...                                      StartDate__c=${DATE_TO_UPDATE}
    Go To Page                               Details
    ...                                      npe03__Recurring_Donation__c
    ...                                      object_id=${data}[contact_rd][Id]
    # Verify that Future schedule section shows up and the values reflect the changes
    Validate Field Values Under Section      Future Schedule
    ...                                      Amount=$150.00
    ...                                      Payment Method=Credit Card
    ...                                      Effective Date=${EFFECTIVE_MODIFIED_DATE}
    ...                                      Installment Period=Monthly
    ...                                      Day of Month=15
    Go To Page                               Details
    ...                                      npe03__Recurring_Donation__c
    ...                                      object_id=${data}[contact_rd][Id]
    Validate Field Values Under Section      Statistics
    ...                                      Current Year Value=$${CURRENTVALUE_EDITED}.00
    ...                                      Next Year Value=$1,800.00
    @{opportunity1} =                        API Query Opportunity For Recurring Donation                   ${data}[contact_rd][Id]
    Store Session Record                     Opportunity                                                    ${opportunity1}[0][Id]
    Go To Page                               Details                        Opportunity                     object_id=${opportunity1}[0][Id]
    Navigate To And Validate Field Value     Stage                          contains                        Pledged