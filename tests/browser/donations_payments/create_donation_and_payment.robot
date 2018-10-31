*** Settings ***

Resource        tests/NPSP.robot
Suite Setup     Open Test Browser
Suite Teardown  Delete Records and Close Browser

*** Variables ***
${No_of_payments}     5
${intervel}    2
${frequency}    Month
${opp_name}

*** Test Cases ***

Create Donation from a Contact
    [tags]  unstable
    ${contact_id} =  Create Contact with Email
    &{contact} =  Salesforce Get  Contact  ${contact_id}
    Header Field Value    Account Name    &{contact}[LastName] Household
    Scroll Page To Location    0    500
    Wait For Locator    record.related.button    Opportunities    New Contact Donation
    Click Special Related List Button   Opportunities    New Contact Donation
    Choose Frame    New Opportunity
    Click Element    p3
    Select Option    Donation    
    Click Element    //input[@title='Continue'] 
    Create Opportunities    Test $100 donation    &{Contact}[LastName] Household
    ${opp_name}    Get Main Header 
    Set Global Variable      ${opp_name}
    Select Related Dropdown    Payments
    Click Link    link=Schedule Payments
    Wait For Locator    frame    Create one or more Payments for this Opportunity
    Select Frame with Title    Create one or more Payments for this Opportunity
    Enter Payment Schedule    ${No_of_payments}    ${intervel}    ${frequency}
    ${loc}    Get NPSP Locator    payments.text
    Input Text    ${loc}    8/15/2018
    Click Element    //*[@id="j_id0:vfForm:j_id134"]
    ${value}     Verify Payment Split   100    ${No_of_payments}
    Should be equal as strings    ${value}    ${No_of_payments}
    Verify Date Split    8/15/2018    ${No_of_payments}    ${intervel}
    Click Button with Value    Create Payments
    ${value}    Verify Occurance Payments    Payments
    Should not be equal as strings    ${value}    0
    
Verify Payments 
    [tags]  unstable
    Go To Object Home         Opportunity
    Click Link    ${opp_name}  
    Click ViewAll Related List    Payments
    Reload Page
    ${flag}     Verify payment    
    should be equal as strings     ${flag}    pass
