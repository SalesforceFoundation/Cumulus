*** Settings ***

Resource        tests/NPSP.robot
Suite Setup     Open Test Browser
Suite Teardown  Delete Records and Close Browser

*** Test Cases ***

Create Donation from Contact and Verify Contact Roles on Opportunity Page
    &{contact1} =  API Create Contact    Email=skristem@robot.com
    &{contact2} =  API Create Contact    AccountId=&{contact1}[AccountId]
    &{opportunity} =  API Create Opportunity    &{Contact1}[AccountId]    Name=Role test $100 donation
    Go To Record Home  &{opportunity}[Id]
    Wait For Locator    record.related.check_occurance    Contact Roles    2
    Select Relatedlist    Contact Roles
    Verify Contact Roles
    ...                     &{contact1}[FirstName] &{contact1}[LastName]=Donor
    ...                     &{contact2}[FirstName] &{contact2}[LastName]=Household Member  