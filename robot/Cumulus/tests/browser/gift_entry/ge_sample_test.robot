*** Settings ***

Resource        robot/Cumulus/resources/NPSP.robot
Library         cumulusci.robotframework.PageObjects
...             robot/Cumulus/resources/NPSPSettingsPageObject.py
...             robot/Cumulus/resources/GiftEntryPageObject.py
Suite Setup     Open Test Browser

Suite Teardown  Capture Screenshot and Delete Records and Close Browser

*** Test Cases ***

Enable Advanced Mapping
    [Documentation]                           This test case assumes that Advanced Mapping and GE is disabled by default. If AM is already enabled 
    ...                                       then throws an error and if not, enables Advanced Mapping and GE for Data Imports 
    [tags]                                    feature:GE    Accessibility
    Go To Page                                Custom          NPSP_Settings
    Open Main Menu                            System Tools
    Click Link With Text                      Advanced Mapping for Data Import & Gift Entry
    Verify Advanced Mapping Is Not Enabled
    Click Toggle Button                       Advanced Mapping
    Wait For Message                          Advanced Mapping is enabled
    Choose Frame                              Nonprofit Success Pack Settings
    Click Toggle Button                       Gift Entry
    Wait For Message                          Gift Entry Enabled
    Go To page                                Custom                GE_Gift_Entry
    Wait until Page contains                  Templates
    Click Element                             //*[@data-qa-locator="button Create Template"]/button
    Wait until Page contains                  New Template
    Input Text                                //*[contains(@data-qa-locator,"Template Name")]//input    test
    Click Element                             //*[@data-qa-locator="button Next: Form Fields"]/button
    Run Accessibility Check
    Click Element                             //*[contains(@data-qa-locator,"Default Value Data Import: Donation Donor")]//input
    Click Element                             //span[@title="Account1"]
    Click Element                             //*[contains(@data-qa-locator,"checkbox Required Data Import: Donation Donor")]//label/span[contains(@class,"checkbox")]
    sleep                                     5
    Go To page                                Custom                GE_Gift_Entry
    Click Button                              New Single Gift
    Wait Until Page contains                  Donor Information
    Run Accessibility Check
    Go To page                                Custom                GE_Gift_Entry
    Click Button                              New Batch
    Wait Until Modal Is Open
    Click Element                             //input[@name="Template"]
    Click Element                             //span[text()="Default Gift Entry Template"]
    Click Button                              Next
    ${batch} =                                Generate Random String
    Fill BGE Form
    ...    Batch Name=${batch}
    ...    Batch Description=This batch is created by using GE feature
    Click Button                              Next
    Scroll Element Into View                  //button[text()="Save"]  
    Click Button                              Save
    Wait For Locator                          bge.title              Batch Gift Entry
    Verify Title                              Batch Gift Entry       ${batch}
    Run Accessibility Check