*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Suite Setup     Open Test Browser
Suite Teardown  Delete Records and Close Browser

*** Test Cases ***

Analyze account object home page
    Go To Object Home    Account
    Click Object Button  New
    Select Record Type                     Organization
    Wait until modal is open
    Wait Until Page Contains    Organization
    # run axe analysis for the modal on page
    Run Accessibility Check  cssSelector=div[class*="isModal active"]
    
    Go To Object Home    Account
    Click Object Button  New
    Select Record Type                     Organization
    Wait until modal is open
    Wait Until Page Contains    Organization
    # run axe analysis for whole page
    Run Accessibility Check


    
    
