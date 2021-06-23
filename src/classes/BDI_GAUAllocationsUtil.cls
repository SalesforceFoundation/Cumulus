/*
    Copyright (c) 2021 Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2021
* @group Batch Data Import
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Provides helper methods to validate and process GAUs entered on the Data Import record.
*/

public with sharing class BDI_GAUAllocationsUtil {
    public static Allocations_Settings__c alloSettings = UTIL_CustomSettingsFacade.getAllocationsSettings();


    /**
     * @description Determines if the Data Import records passed into the method have GAU Allocation Information either
     * in the GAU 1 or GAU 2 fields or in the Additional Object JSON field.
     * @param dataImports he data import records to examine for GAU Allocation Information
     * @return Map<Id, DataImport__c> the DI records with GAU information in a map.
     */
    public static Map<Id, DataImport__c> getDIsWithGAUtoProcess(DataImport__c[] dataImports) {
        Map<Id, DataImport__c> diWithGAUToProcess = new Map<Id, DataImport__c>();
        // Loop through and determine which records have Additional Object JSON containing GAUAllocation objects or
        // the DI GAU fields filled out
        for (DataImport__c di : dataImports) {
            if (di.Additional_Object_JSON__c != null) {
                if (di.Additional_Object_JSON__c.contains('GAU_Allocation')) {
                    diWithGAUToProcess.put(di.Id,di);
                }
            }

            if (di.GAU_Allocation_1_GAU__c != null || di.GAU_Allocation_2_GAU__c != null) {
                diWithGAUToProcess.put(di.Id,di);
            }
        }
        return diWithGAUToProcess;
    }

    /**
     * @description Validates that Data Import records with GAU 1 or GAU 2 populated have a total percentage under 100
     * percent.  If it is over 100 percent the Data Import record will be failed and an error logged.
     * @param bdi the BDI_DataImportService instance that is being used for this context.
     * @param dataImports {List<DataImport__c>} the data import records to validate GAU percentages for.
     * @return Map<Id, DataImport__c> the DI records valid GAU percentages in a map
     */
    public static Map<Id, DataImport__c> validateDIGAUPercentages(BDI_DataImportService bdi,
                                                                    DataImport__c[] dataImports) {
        Map<Id, DataImport__c> diWithValidGAUToProcess = new Map<Id, DataImport__c>();

        // Loop through the DIs to determine if they exceed the allocation percentage max.
        for (DataImport__c di : dataImports) {
            Decimal totalPercent = 0;

            // Add to the total percent if the value is not null.
            if (di.GAU_Allocation_1_Percent__c != null) {
                totalPercent += di.GAU_Allocation_1_Percent__c;
            }
            if (di.GAU_Allocation_2_Percent__c != null) {
                totalPercent += di.GAU_Allocation_2_Percent__c;
            }

            // if the total percent is over 100 then fail the record and log an error.
            if (totalPercent > 100) {
                bdi.LogBDIError(di,label.bdiErrorGAUAllocationOver100,'GAU_Allocation_1_Import_Status__c');
            } else {
                // If the percent is less than 100 or they were null then pass it through for
                // more processing
                diWithValidGAUToProcess.put(di.Id,di);
            }
        }

        return diWithValidGAUToProcess;
    }

    /**
     * @description Inserting the new GAU Allocations defined on the Data Import record will likely cause issues if
     * there are any existing Allocations on the Donation listed in DonationImported__c or if there are any allocations
     * linked to an existing payment for the Donation listed in DonationImported__c.  This method will add an error
     * and fail the Data Import record if there are any existing Allocations located in either place.
     * @param bdi the BDI_DataImportService instance that is being used for this context.
     * @param dataImports {List<DataImport__c>} the data import records to search for existing Allocations for.
     */
    public static void checkForExistingAllocations(BDI_DataImportService bdi, DataImport__c[] dataImports) {

        Map<Id,DataImport__c[]> disByOpptId = new Map<Id,DataImport__c[]>();

        // Loops through data import records and if the donation imported is not null then add to list for review of
        // existing allocations.
        for (DataImport__c di : dataImports) {
            if (di.DonationImported__c != null) {

                if (disByOpptId.get(di.DonationImported__c) != null) {
                    disByOpptId.get(di.DonationImported__c).add(di);
                } else {
                    disByOpptId.put(di.DonationImported__c,new DataImport__c[]{di});
                }
            }
        }

        // If there are disByOpptId then query existing Allocations
        if (!disByOpptId.isEmpty()) {
            Set<Id> opptIds = disByOpptId.keySet();

            UTIL_Permissions utilPerm = UTIL_Permissions.getInstance();

            Set<SObjectField> allocFields = new Set<SObjectField>();
            allocFields.add(SObjectType.Allocation__c.fields.Id.getSobjectField());
            allocFields.add(SObjectType.Allocation__c.fields.Payment__c.getSobjectField());
            allocFields.add(SObjectType.Allocation__c.fields.Opportunity__c.getSobjectField());
            allocFields.add(SObjectType.Allocation__c.fields.General_Accounting_Unit__c.getSobjectField());

            Set<SObjectField> paymentFields = new Set<SObjectField>();
            paymentFields.add(SObjectType.npe01__OppPayment__c.fields.Id.getSobjectField());
            paymentFields.add(SObjectType.npe01__OppPayment__c.fields.npe01__Opportunity__c.getSobjectField());

            if(utilPerm.canRead(Allocation__c.getSObjectType(),allocFields)
                && utilPerm.canRead(npe01__OppPayment__c.getSObjectType(),paymentFields)) {

                String queryString = ' SELECT Id, ' +
                        'General_Accounting_Unit__c, ' +
                        'Opportunity__c,' +
                        'Payment__c,' +
                        'Payment__r.npe01__Opportunity__c '+
                        'FROM Allocation__c WHERE Opportunity__c IN: opptIds';

                if (alloSettings.Payment_Allocations_Enabled__c) {
                    queryString += ' OR Payment__r.npe01__Opportunity__c IN: opptIds';
                }

                Allocation__c[] existingAllos = Database.query(queryString);

                if (existingAllos != null){
                    for (Allocation__c allo: existingAllos) {
                        DataImport__c[] opptAlloMatchingDIs;
                        DataImport__c[] paymentAlloMatchingDIs;

                        // Log error for newly created donations that already have
                        if (disByOpptId.get(allo.Opportunity__c) != null) {
                            opptAlloMatchingDIs = disByOpptId.get(allo.Opportunity__c);
                            for (DataImport__c di : opptAlloMatchingDIs) {
                                bdi.LogBDIError(di,label.bdiErrorExistingDonationAllocations,null);
                            }
                        }

                        if (disByOpptId.get(allo.Payment__r.npe01__Opportunity__c) != null) {
                            paymentAlloMatchingDIs = disByOpptId.get(allo.Payment__r.npe01__Opportunity__c);
                            for (DataImport__c di : paymentAlloMatchingDIs) {
                                bdi.LogBDIError(di,label.bdiErrorExistingPaymentAllocations,null);
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * @description This method calls the Allocation Service to cascade down GAU Allocations from the Recurring Donation
     * to the Donation, and Payment (if payment allocations are enabled).  It also will capture errors returned from
     * processing GAU Allocations and fail the Data Import record.
     * @param bdi the BDI_DataImportService instance that is being used for this context.
     * @param dataImports {List<DataImport__c>} the data import records to process allocations for
     */
    public static void processAllocations(BDI_DataImportService bdi, List<DataImport__c> dataImports) {
        Set<Id> opptIdsForAllocProcessing = new Set<Id>();
        DataImport__c[] diForAlloProcessing = new DataImport__c[]{};
        for (DataImport__c di : dataImports) {

            // If the DI doesn't have a failure and it isn't in dry run mode and there is
            // a donation imported id and a donation or a payment was created then run allocation processing for all
            // donation ids.
            if (di.Status__c != System.label.bdiFailed &&
                    !bdi.isDryRun  &&
                    di.DonationImported__c != null && (
                    di.PaymentImportStatus__c == System.label.bdiCreated
                            || di.PaymentImportStatus__c == System.label.bdiUpdated
                            || di.DonationImportStatus__c == System.label.bdiCreated)) {

                opptIdsForAllocProcessing.add(di.DonationImported__c);
                diForAlloProcessing.add(di);
            }
        }

        // If there were any opportunities that met the criteria for allocation processing then call the
        // Allocations service.
        if(opptIdsForAllocProcessing.size() > 0) {
            // Instantiating a custom error class so that we can review the error messages without inserting them as
            // error records.
            ERR_RecordError errors = new ERR_RecordError('GAU Allocations');
            // Calling the allocations service with a custom error class and setting a flag not to commit the errors
            // since we will be adding them to the
            ALLO_AllocationsService allocationsSvc = new ALLO_AllocationsService()
                    .withAlternateRecordErrorsLogger(errors)
                    .withCommitAndClearRecordsEnabled(false);
            allocationsSvc.processRecords(opptIdsForAllocProcessing);

            Allocation__c[] allocForDelete = new Allocation__c[]{};

            for (DataImport__c di : diForAlloProcessing) {
                Error__c errorObj;

                // Retrieve the error object out of either the insert or update errors
                if (errors.insRecordErrors.containsKey(di.DonationImported__c)) {
                    errorObj = errors.insRecordErrors.get(di.DonationImported__c);
                } else if (errors.updRecordErrors.containsKey(di.DonationImported__c)) {
                    errorObj = errors.updRecordErrors.get(di.DonationImported__c);
                }

                if (errorObj != null) {
                    String statusFieldName;

                    // If there was a GAU allocation imported then add it to the list for delete and overwrite status
                    // with error message.  Otherwise add it to the status message for the Donation or Payment.
                    if (di.GAU_Allocation_1_Imported__c != null || di.GAU_Allocation_2_Imported__c != null) {
                        if (di.GAU_Allocation_1_Imported__c != null) {
                            allocForDelete.add(new Allocation__c(Id = di.GAU_Allocation_1_Imported__c));
                            statusFieldName = SObjectType.DataImport__c.fields.GAU_Allocation_1_Import_Status__c.Name;
                            di.GAU_Allocation_1_Imported__c = null;
                        }
                        if (di.GAU_Allocation_2_Imported__c != null) {
                            allocForDelete.add(new Allocation__c(Id = di.GAU_Allocation_2_Imported__c));
                            statusFieldName = SObjectType.DataImport__c.fields.GAU_Allocation_2_Import_Status__c.Name;
                            di.GAU_Allocation_2_Imported__c = null;
                        }
                    } else if (di.PaymentImported__c != null) {
                        statusFieldName = SObjectType.DataImport__c.fields.PaymentImportStatus__c.Name;
                    } else if (di.DonationImported__c != null) {
                        statusFieldName = SObjectType.DataImport__c.fields.DonationImportStatus__c.Name;
                    }

                    bdi.LogBDIError(di, errorObj.Full_Message__c, statusFieldName);
                }
            }
            // Delete any allocations that were created for an oppt that had related allocation errors.
            if (allocForDelete.size() > 0) {
                if (UTIL_Permissions.canDelete(String.valueOf(Allocation__c.getSObjectType()), false)) {
                    delete allocForDelete;
                }
            }
        }
    }
}