*** Settings ***

Resource       cumulusci/robotframework/Salesforce.robot
Resource       robot/Cumulus/resources/Data.robot
Library        robot/Cumulus/resources/BDI_API.py


*** Keywords ***
Collect BDI Failures
    @{failures} =   Salesforce Query  DataImport__c
    ...           select=Id,Status__c,FailureInformation__c, PaymentImported__c, PaymentImportStatus__c
    ...           Status__c=Failed
    Return From Keyword   @{failures}


Ensure Custom Metadata Was Deployed
    ${Default_Object_Mapping_Set} =   Salesforce Query  Data_Import_Object_Mapping__mdt
    ...           select=Id
    ...           Data_Import_Object_Mapping_Set__r.DeveloperName=Default_Object_Mapping_Set
    ${Default_Object_Mapping_Set_Length} =  Get Length  ${Default_Object_Mapping_Set}

    ${Migrated_Custom_Object_Mapping_Set} =   Salesforce Query  Data_Import_Object_Mapping__mdt
    ...           select=Id
    ...           Data_Import_Object_Mapping_Set__r.DeveloperName=Migrated_Custom_Object_Mapping_Set
    ${Migrated_Custom_Object_Mapping_Set_Length} =  Get Length  ${Migrated_Custom_Object_Mapping_Set}

    Should Be Equal     ${Default_Object_Mapping_Set_Length}    ${Migrated_Custom_Object_Mapping_Set_Length}

    Output      Custom Metadata Deployed        ${Migrated_Custom_Object_Mapping_Set_Length}

Display BDI Failures
    @{failures} =   Collect BDI Failures
    ${length} =  Get Length  ${failures}
    Run Keyword If  ${length} == 0  Log to Console  No failure records
    Return From Keyword If       ${length}==0        False

    Output      Failures   ${length}

    Output      Example Failure   Id: ${failures[0]['Id']}
    ...                                   Status__c: ${failures[0]['Status__c']}
    ...                                   PaymentImported__c: ${failures[0]['PaymentImported__c']}
    ...                                   PaymentImportStatus__c: ${failures[0]['PaymentImportStatus__c']}
    ...                                   FailureInformation__c: ${failures[0]['FailureInformation__c']}
