/*
    Copyright (c) 2019, Salesforce.org
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
* @date 2019
* @group BGE
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Lightning Component Server Controller for the Data Import Batch Entry component.
*/

public with sharing class BGE_DataImportBatchEntry_CTRL {

    /*******************************************************************************************************
    * @description The number of additional Data Import Records to load on each infinite scroll query
    */
    private static Integer loadSize = 100;

    /*******************************************************************************************************
    * @description Checks for field permissions to create a new Batch
    * @return void; throws an AuraHandledException if any fields fail FLS check
    */
    @AuraEnabled
    public static void checkFieldPermissions() {
        BGE_BatchGiftEntry_UTIL.checkFieldPermissionsNeededForBatch();
    }

    /*******************************************************************************************************
    * @description deletes DataImport__c record and returns updated totals in the model
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @param dataImportId: ID of the DataImport__c
    * @return String serialized DataImportModel to update totals
    */
    @AuraEnabled
    public static String deleteDataImportRow(Id batchId, Id dataImportId) {
        Boolean canDelete = UTIL_Permissions.getInstance().canDelete(DataImport__c.SObjectType);
        if(!canDelete) {
            throw new AuraHandledException(Label.commonPermissionErrorMessage);
        }
        
        try {
            delete new DataImport__c(Id = dataImportId);
            DataImportModel dataImportModel = getUpdatedTotals(batchId);
            return JSON.serialize(dataImportModel);
        } catch (DmlException ex) {
            throw new AuraHandledException(Label.commonPermissionErrorMessage);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description initializes the data model for the BGE_DataImportBatchEntry component
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @return serialized string of dataImportModel
    */
    @AuraEnabled
    public static String getDataImportModel(Id batchId) {

        if (batchId == null) {
            throw new AuraHandledException('Data Import Model must receive a Batch ID.');
        }

        DataImportModel dataImportModel = new DataImportModel();
        dataImportModel.id = batchId;
        dataImportModel.dataImportRows = getDataImportRows(batchId, 0);
        dataImportModel.setColumns();
        dataImportModel.labels = getBatchDataImportLabels();
        dataImportModel.isNamespaced = String.isNotBlank(UTIL_Namespace.getNamespace());
        dataImportModel.totalCountOfRows = getDataImportBatchTotalCount(batchId);
        AggregateResult[] aggResult = getDataImportBatchTotalAmount(batchId);
        dataImportModel.totalRowAmount = (Decimal)aggResult[0].get('amount');
        dataImportModel.batchTotalRowAmount = getBatchTotalRowAmount(dataImportModel.dataImportRows);
        checkBatchGiftEntryFieldPermissions (batchId);
        return JSON.serialize(dataImportModel);
    }

    private static Decimal getBatchTotalRowAmount(List<DataImportRow> dataImportRows) {
        Decimal totalAmount = 0;

        for (DataImportRow dataImportRow: dataImportRows) {
                totalAmount+= dataImportRow.record.Donation_Amount__c == null
                    ? 0
                    : dataImportRow.record.Donation_Amount__c;
        }
        return totalAmount;
    }

    private static Decimal getBatchTotalRowAmount(Id batchId) {
        Decimal totalAmount = 0;

        for (DataImport__c dataImport: [
            SELECT Donation_Amount__c
            FROM DataImport__c
            WHERE NPSP_Data_Import_Batch__c =: batchId
        ]) {
            totalAmount+= dataImport.Donation_Amount__c == null
                ? 0
                : dataImport.Donation_Amount__c;
        }
        return totalAmount;
    }

    private static void checkBatchGiftEntryFieldPermissions(Id batchId) {
        Decimal batchGiftEntryVersion;
        Boolean isQueryException = false;
        try {
            batchGiftEntryVersion = getBatchGiftEntryVersion(batchId);
        } catch (QueryException qe) {
            // If User doesn't have access to Version field, treat as 1.0.
            isQueryException = true;
        }

        List<String> fields = BGE_BatchGiftEntry_UTIL.getDataImportFields(batchId);

        if (isQueryException || batchGiftEntryVersion < 2) {
            BGE_BatchGiftEntry_UTIL.checkFieldPermissions(
                String.valueOf(DataImport__c.SObjectType),
                fields
            );
        } else {
            List<String> nonNameFields = getNonNameFields(fields);
            BGE_BatchGiftEntry_UTIL.checkFieldPermissions(
                String.valueOf(DataImport__c.SObjectType),
                nonNameFields
            );
        }
    }

    private static Decimal getBatchGiftEntryVersion(Id batchId) {
        return [
            SELECT Batch_Gift_Entry_Version__c
            FROM DataImportBatch__c
            WHERE Id = :batchId
            WITH SECURITY_ENFORCED
        ][0].Batch_Gift_Entry_Version__c;
    }

    private static List<String> getNonNameFields(List<String> fields) {
        List<String> nonNameFields = new List<String>();
        for (String str : fields) {
            Boolean isNameField = str.contains('.');
            if (isNameField) {
                continue;
            } else if (!nonNameFields.contains(str)) {
                nonNameFields.add(str);
            }
        }
        return nonNameFields;
    }

    /*******************************************************************************************************
    * @description queries the DataImport__c records associated with the given batchId
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @param offset: next offset to query
    * @return list of custom DataImportRow objects for use in the lightning:datatable
    */
    @AuraEnabled
    public static List<DataImportRow> getDataImportRows(Id batchId, Integer offset){

        try {
            List<DataImportRow> rows = new List<DataImportRow>();
            List<DataImport__c> dataImports = getDataImportRecordsByBatchId(batchId, offset);
            for (DataImport__c dataImportRecord : dataImports) {
                rows.add(new DataImportRow(dataImportRecord));
            }

            return rows;
        }
        catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description Retrieves all open Opportunities and related Payments for the selected Donor (Account or Contact)
    * @return JSON string of all open Opportunities and related Payments for the given donor
    */
    @AuraEnabled
    public static String getOpportunitiesWithOppPayments(Id donorId) {
        Schema.SObjectType token = donorId.getSobjectType();

        String relationshipField;
        if (token == Account.SObjectType) {
            relationshipField = 'AccountId';
        } else if (token == Contact.SObjectType) {
            relationshipField = 'Primary_Contact__c';
        } else {
            throw new AuraHandledException('SObjectType ' + token + ' is not supported.');
        }

        String query = 'SELECT Id, ' +
                'Name, ' +
                'StageName, ' +
                'Amount, ' +
                    '(SELECT Id, ' +
                    'Name, ' +
                    'npe01__Scheduled_Date__c, ' +
                    'npe01__Opportunity__r.Name, ' +
                    'npe01__Opportunity__c, ' +
                    'npe01__Payment_Amount__c,' +
                    'npe01__Paid__c, ' +
                    'npe01__Written_Off__c ' +
                    'FROM npe01__OppPayment__r ' +
                    'WHERE npe01__Written_Off__c = false) ' +
                'FROM Opportunity ' +
                'WHERE ' + relationshipField + ' = :donorId ' +
                'AND IsClosed = false ' +
                'WITH SECURITY_ENFORCED';

        try {
            List<OpportunityWrapper> opportunityWrappers = new List<OpportunityWrapper>();
            for (Opportunity opportunity : Database.query(query)) {
                opportunityWrappers.add(new OpportunityWrapper(opportunity));
            }
            return JSON.serialize(opportunityWrappers);
        } catch (QueryException ex) {
            throw new AuraHandledException(Label.commonPermissionErrorMessage);
        } catch (Exception ex) {
            throw new AuraHandledException('ERROR: ' + ex.getMessage());
        }
    }

    /**
    * @description Wrapper class used to hold only the information needed in the
    * component for each Opportunity.  The component does not need to store any of
    * the paid or written-off Payments for a donor, but it does need to know if the Donation
    * has related Payments that have not been written-off. In that case the User should not
    * be able to update the Opportunity in the BGE Donation Selector.
    */
    @TestVisible
    private class OpportunityWrapper {
        @TestVisible Opportunity opportunity {get; private set;}
        @TestVisible List<npe01__OppPayment__c> unpaidPayments {get; private set;}
        @TestVisible Boolean hasNonWrittenOffPayments {get; private set;}

        private OpportunityWrapper(Opportunity opportunity) {
            this.opportunity = opportunity;
            initialize();
        }

        private void initialize() {
            if (unpaidPayments == null) {
                unpaidPayments = new List<npe01__OppPayment__c>();
            }

            if (opportunity.npe01__OppPayment__r.isEmpty()) {
                hasNonWrittenOffPayments = false;
                return;
            }

            for (npe01__OppPayment__c oppPayment : opportunity.npe01__OppPayment__r) {
                if (hasNonWrittenOffPayments == null
                        && oppPayment.npe01__Written_Off__c == false) {
                    hasNonWrittenOffPayments = true;
                }

                if (isAvailableForUpdate(oppPayment)) {
                    unpaidPayments.add(oppPayment);
                } else {
                    continue;
                }
            }

            //If hasNonWrittenOffPayments is null after looping all of the Payments,
            //then all of the Opp's Payments are written-off, and hasNonWrittenOffPayments can
            //be set to false, as this Opp should be treated in the BGE Donation Selector UI
            //as if it has 0 Payments.
            if (hasNonWrittenOffPayments == null) {
                hasNonWrittenOffPayments = false;
            }
        }

        private Boolean isAvailableForUpdate(npe01__OppPayment__c oppPayment) {
            if (oppPayment.npe01__Paid__c || oppPayment.npe01__Written_Off__c) {
                return false;
            } else {
                return true;
            }
        }
    }

    /*******************************************************************************************************
    * @description runs BDI Dry Run against a given Id based on the processing settings of a given batch
    * @param dataImportId: the NPSP_Data_Import__c record to update
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @return DataImportModel with updated data import record row and updated totals for the batch
    */
    @AuraEnabled
    public static String runSingleDryRun(Id dataImportId, Id batchId) {
        try {
            Data_Import_Settings__c dataImportSettings = BDI_DataImportService.loadSettings(batchId);
            List<DataImport__c> dataImportListToRun = prepareDataImportsForDryRun(
                getDataImportRecordsForDryRunByIds(new List<Id> { dataImportId }));
                
            BDI_DataImport_API.processDataImportRecords(dataImportSettings, dataImportListToRun, true);

            DataImportModel dataImportModel = getUpdatedTotals(batchId);

            DataImport__c dataImport = getDataImportRecordsByIds(batchId, new List<Id>{dataImportId})[0];
            DataImportRow processedDataImportRow = new DataImportRow(dataImport);

            dataImportModel.dataImportRows = new List<DataImportRow>{processedDataImportRow};

            return JSON.serialize(dataImportModel);
        } catch (Exception ex){
            throw new AuraHandledException('ERROR: ' + ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description runs BDI Dry Run against all Data Import records based on the processing settings of a 
    *  given batch
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @return DataImportModel with updated data import record row and updated totals for the batch
    */
    @AuraEnabled
    public static String runBatchDryRun(Id batchId, Integer numberOfRowsToReturn) {
        try {
            Data_Import_Settings__c dataImportSettings = BDI_DataImportService.loadSettings(batchId);

            List<DataImport__c> allRawDataImports = getAllDataImportRecordsForDryRunByBatchId(batchId);
            List<DataImport__c> rawDataImportsToPrepareForDryRun = new List<DataImport__c>();
            for (DataImport__c di : allRawDataImports) {
                if (di.Status__c != BDI_DataImport_API.bdiImported) {
                    rawDataImportsToPrepareForDryRun.add(di);
                }
            }

            if (rawDataImportsToPrepareForDryRun.size() > 0) {
                List<DataImport__c> dataImportListToRun = 
                    prepareDataImportsForDryRun(rawDataImportsToPrepareForDryRun);
                BDI_DataImport_API.processDataImportRecords(dataImportSettings, dataImportListToRun, true);
            }

            DataImportModel dataImportModel = getUpdatedTotals(batchId);

            List<DataImportRow> rows = new List<DataImportRow>();
            List<DataImport__c> dataImportsToReturn = 
                getNumOfDataImportRecordsByBatchId(batchId, numberOfRowsToReturn);
            for (DataImport__c di : dataImportsToReturn) {
                DataImportRow processedDataImportRow = new DataImportRow(di);
                rows.add(processedDataImportRow);
            }
            dataImportModel.dataImportRows = rows;

            return JSON.serialize(dataImportModel);
        } catch (Exception ex){
            throw new AuraHandledException('ERROR: ' + ex.getMessage());
        }
    }


    /*******************************************************************************************************
    * @description updates data import record, dry runs the record, and returns updated totals with the new row.
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @param dataImport: the NPSP_Data_Import__c record to update
    * @return String serialized DataImportModel to update totals
    */
    @AuraEnabled
    public static String updateAndDryRunRow(Id batchId, DataImport__c dataImport) {
        try {
            Database.update(dataImport);
            return runSingleDryRun(dataImport.Id, batchId);
        } catch (Exception ex) {
            String saveErrorMessage = String.format(Label.CRLP_SaveError, 
                new List<String>{Schema.SObjectType.DataImport__c.getName()});
            throw new AuraHandledException(saveErrorMessage + '. ' + ex.getMessage());
        }
    }

    /*******************************************************************************************************
    * @description gets updated amount total and row count for the batch
    * @param batchId: ID of the NPSP_Data_Import_Batch__c
    * @return DataImportModel updated model with total amount and number of rows
    */
    public static DataImportModel getUpdatedTotals(Id batchId) {
        DataImportModel dataImportModel = new DataImportModel();

        dataImportModel.id = batchId;
        dataImportModel.totalCountOfRows = getDataImportBatchTotalCount(batchId);
        AggregateResult[] aggResult = getDataImportBatchTotalAmount(batchId);
        dataImportModel.totalRowAmount = (Decimal) aggResult[0].get('amount');
        dataImportModel.batchTotalRowAmount = getBatchTotalRowAmount(batchId);

        return dataImportModel;
    }

    /*******************************************************************************************************
    * @description Retrieves required schema information for the component.
    * @return Map of DataImport__c object and field name keys to their labels.
    */
    private static Map<String, String> getBatchDataImportLabels() {

        Map<String, String> labels = new Map<String, String> {
            'accountObject' => Schema.SObjectType.Account.getLabel(),
            'accountLookup' => Schema.SObjectType.DataImport__c.fields.Account1Imported__c.getName(),
            'batchIdField' => Schema.SObjectType.DataImport__c.fields.NPSP_Data_Import_Batch__c.getName(),
            'bdiBatchClass' => UTIL_Namespace.StrTokenNSPrefix('BDI_DataImport'),
            'contactLookup' => Schema.SObjectType.DataImport__c.fields.Contact1Imported__c.getName(),
            'contactObject' => Schema.SObjectType.Contact.getLabel(),
            'dataImportObject' => Schema.SObjectType.DataImport__c.getName(),
            'donationDonor' => Schema.SObjectType.DataImport__c.fields.Donation_Donor__c.getName(),
            'donationAmountField' => Schema.SObjectType.DataImport__c.fields.Donation_Amount__c.getName(),
            'expectedCountField' => Schema.SObjectType.DataImportBatch__c.fields.Expected_Count_of_Gifts__c.getName(),
            'expectedTotalField' => Schema.SObjectType.DataImportBatch__c.fields.Expected_Total_Batch_Amount__c.getName(),
            'noDataImportsFound' => String.format(Label.stgNoObjectsFound, new List<String>{Schema.SObjectType.DataImport__c.getName()}),
            'opportunityImportedLookupField' => Schema.SObjectType.DataImport__c.fields.DonationImported__c.getName(),
            'opportunityImportedStatusField' => Schema.SObjectType.DataImport__c.fields.DonationImportStatus__c.getName(),
            'opportunityAmount' => Schema.SObjectType.Opportunity.fields.Amount.getLabel(),
            'opportunityObject' => Schema.SObjectType.Opportunity.getLabel(),
            'opportunityName' => Schema.SObjectType.Opportunity.getLabel(),
            'opportunityStage' => Schema.SObjectType.Opportunity.fields.StageName.getLabel(),
            'paymentAmount' => Schema.SObjectType.npe01__OppPayment__c.fields.npe01__Payment_Amount__c.getLabel(),
            'paymentObject' => Schema.SObjectType.npe01__OppPayment__c.getLabel(),
            'paymentScheduledDate' => Schema.SObjectType.npe01__OppPayment__c.fields.npe01__Scheduled_Date__c.getLabel(),
            'paymentImportedLookupField' => Schema.SObjectType.DataImport__c.fields.PaymentImported__c.getName(),
            'paymentImportedStatusField' => Schema.SObjectType.DataImport__c.fields.PaymentImportStatus__c.getName(),
            'requireTotalMatch' => Schema.SObjectType.DataImportBatch__c.fields.RequireTotalMatch__c.getName()
        };

        return labels;
    }

    /*******************************************************************************************************
    * @description Gets the sum of the amount totals of all rows for that batch
    * @param recordId the ID of the NPSP_Data_Import_Batch__c
    * @return Decimal amount
    */
    private static AggregateResult[] getDataImportBatchTotalAmount(Id recordId) {
        return [
            SELECT Sum(Donation_Amount__c)amount
            FROM DataImport__c
            WHERE NPSP_Data_Import_Batch__c =: recordId
        ];
    }

    /**
     * @description Instance method to get total amount from Agg Result.  Further
     * refactoring will move this to the GiftBatch Selector class.
     * @param batchId
     *
     * @return total amount of Gifts in Batch
     */
    public Decimal getTotal(Id batchId) {
        AggregateResult[] aggResult = getDataImportBatchTotalAmount(batchId);
        Decimal total = (Decimal) aggResult[0].get('amount');
        return total;
    }

    /*******************************************************************************************************
    * @description Gets the count of Data Import Batch records in a particular batch
    * @param recordId the ID of the NPSP_Data_Import_Batch__c
    * @return Integer count of batch records
    */
    private static Integer getDataImportBatchTotalCount(Id recordId) {
        return [SELECT Count() FROM DataImport__c WHERE NPSP_Data_Import_Batch__c =: recordId];
    }

    /*******************************************************************************************************
    * @description prepare the data import record for dry run by clearing certain fields or retaining them
    * based on if user has already selected a match, or if they want to let matching run. Either way, we want to use Dry Run
    * to check for potential errors.
    * @return List<DataImport__c> because BDI expects a list
    */
    private static List<DataImport__c> prepareDataImportsForDryRun(List<DataImport__c> dataImportRecords) {
        // Skip records where user has explicitly selected a matching record in BGE UI
        for(DataImport__c dataImportRecord : dataImportRecords) {
            if (dataImportRecord.DonationImportStatus__c == Label.bdiMatchedByUser
                    || dataImportRecord.DonationImportStatus__c == Label.bdiMatchedByUserNewOpp
                    || dataImportRecord.DonationImportStatus__c == Label.bdiMatchedApplyNewPayment) {
                // User defined match, so we do nothing and retain the values
            } else {
                // Clear Dry Run fields before running Dry Run so new field values are accounted for
                if (dataImportRecord.Status__c != null) {
                    dataImportRecord.Status__c = null;
                }
                if (dataImportRecord.FailureInformation__c != null) {
                    dataImportRecord.FailureInformation__c = null;
                }
                if (dataImportRecord.DonationImported__c != null) {
                    dataImportRecord.DonationImported__c = null;
                }
                if (dataImportRecord.DonationImportStatus__c != null) {
                    dataImportRecord.DonationImportStatus__c = null;
                }
                if (dataImportRecord.PaymentImported__c != null) {
                    dataImportRecord.PaymentImported__c = null;
                }
                if (dataImportRecord.PaymentImportStatus__c != null) {
                    dataImportRecord.PaymentImportStatus__c = null;
                }

            }
        }

        update dataImportRecords;

        return dataImportRecords;
    }

    /*******************************************************************************************************
    * @description returns a list of all DataImport__c records from a batch Id
    * @param batchId a Data Import Batch Id
    * @return List<DataImport__c>
    */
    public static List<DataImport__c> getAllDataImportRecordsByBatchId(Id batchId) {
        String query = getDataImportQuery(batchId, null, null, null);
        return Database.query(query);
    }

    /*******************************************************************************************************
    * @description returns a list of all DataImport__c records from a batch Id
    * @param batchId a Data Import Batch Id
    @ param numberOfRowsToReturn Limit on the query
    * @return List<DataImport__c>
    */
    private static List<DataImport__c> getNumOfDataImportRecordsByBatchId(Id batchId, Integer numberOfRowsToReturn) {
        String query = getDataImportQuery(batchId, null, numberOfRowsToReturn, null);
        return Database.query(query);
    }

    /*******************************************************************************************************
    * @description returns an offset list of DataImport__c records from a batch Id
    * @param batchId a Data Import Batch Id
    * @param offset Offset on the query
    * @return List<DataImport__c>
    */
    private static List<DataImport__c> getDataImportRecordsByBatchId(Id batchId, Integer offset) {
        String query = getDataImportQuery(batchId, null, loadSize, offset);
        return Database.query(query);
    }

    /*******************************************************************************************************
    * @description Returns a list of DataImport__c records by their ids
    * @param batchId a Data Import Batch Id
    * @param dataImportIds List of Data Import Ids
    * @return DataImport__c
    */
    private static List<DataImport__c> getDataImportRecordsByIds(Id batchId, List<Id> dataImportIds) {
        String query = getDataImportQuery(batchId, dataImportIds, null, null);
        return Database.query(query);
    }

    /*******************************************************************************************************
    * @description Returns a list of DataImport__c records by their ids, with fields needed for dry run
    * @param dataImportIds List of Data Import Ids
    * @return DataImport__c
    */
    private static List<DataImport__c> getDataImportRecordsForDryRunByIds(List<Id> dataImportIds) {
        String query =  BDI_DataImportService.strSoqlForDataImportProcess(dataImportIds);
        return Database.query(query);
    }

    /*******************************************************************************************************
    * @description returns a list of all DataImport__c records for a batch Id, with fields needed for dry run
    * @param batchId a Data Import Batch Id
    * @return List<DataImport__c>
    */
    public static List<DataImport__c> getAllDataImportRecordsForDryRunByBatchId(Id batchId) {
        String query = BDI_DataImportService.strSoqlForBatchProcess(batchId);
        return Database.query(query);
    }    

    /*******************************************************************************************************
    * @description Builds DataImport__c query based on provided parameters
    * @param batchId a Data Import Batch Id
    * @param dataImportIds List of Data Import Ids
    * @param numRows Limit on the query
    * @param offset Offset on the query
    * @return Query string
    */
    public static String getDataImportQuery(Id batchId, List<Id> dataImportIds, Integer numRows, Integer offset) {
        List<String> dataImportFields = BGE_BatchGiftEntry_UTIL.getDataImportFields(batchId);

        String query =  'SELECT ' + String.join(dataImportFields,', ') +
                        ' FROM DataImport__c' +
                        ' WHERE NPSP_Data_Import_Batch__c = :batchId';

        if (dataImportIds != null && dataImportIds.size() > 0) {
            query += ' AND Id IN :dataImportIds';
        }

        query += ' ORDER BY CreatedDate DESC';

        if (numRows != null) {
            query += ' LIMIT ' + numRows;
        }

        if (offset != null) {
            query += ' OFFSET ' + offset;
        }

        return query;
    }

    /*******************************************************************************************************
    * @description a class to retrieve information related to Active and Available fields.
    */
    public class Column {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public Boolean readOnly;
        @AuraEnabled public String type;
        @AuraEnabled public String defaultValue;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean hide;
        @AuraEnabled public String typeAttributes;
        @AuraEnabled public List<Map<String, String>> options;
    }

    /*******************************************************************************************************
    * @description a class to retrieve and save the required information for the Batch Data Import component.
    */
    public class DataImportModel {
        @AuraEnabled public Id id;
        @AuraEnabled public List<DataImportRow> dataImportRows;
        @AuraEnabled public List<Column> columns;
        @AuraEnabled public Boolean isNamespaced;
        @AuraEnabled public Map<String, String> labels;
        @AuraEnabled public Integer totalCountOfRows;
        @AuraEnabled public Decimal totalRowAmount;
        @AuraEnabled public Decimal batchTotalRowAmount;
        @AuraEnabled public List<UTIL_LightningComponentSupport.Notice> notices =
                new List<UTIL_LightningComponentSupport.Notice>();

        /*******************************************************************************************************
        * @description Retrieves the related list of columns for the BGE interface
        * @return list of Columns to use in BGE_DataImportBatchEntry table
        */
        public void setColumns() {
            List<Column> columns = new List<Column>();

            columns.addAll(getUserDefinedColumns());

            //add derived matched record column
            Column linkCol = new Column();
            linkCol.label = Label.bdiDonation;
            linkCol.fieldName = 'matchedRecordUrl';
            linkCol.readOnly = true;
            linkCol.type = 'url';
            linkCol.typeAttributes = '{"label":{"fieldName":"matchedRecordLabel"},"target":"_blank"}';
            columns.add(linkCol);

            //status of the DI record
            Column statusCol = new Column();
            statusCol.label = Schema.SObjectType.DataImport__c.fields.Status__c.getLabel();
            statusCol.fieldName = Schema.SObjectType.DataImport__c.fields.Status__c.getName();
            statusCol.readOnly = true;
            statusCol.type = 'text';
            columns.add(statusCol);

            this.columns = columns;
        }

        /*******************************************************************************************************
        * @description Retrieves the related list of columns defined by users in the Batch record Active_Fields__c
        * @return list of Columns to use in BGE_DataImportBatchEntry table
        */
        private List<Column> getUserDefinedColumns() {
            List<Column> columns = new List<Column>();

            DataImportBatch__c batch = [SELECT Active_Fields__c FROM DataImportBatch__c
            WHERE Id = :id];
            String activeFieldsJSON = batch.Active_Fields__c;
            if (activeFieldsJSON != null) {
                List<BGE_ConfigurationWizard_CTRL.BGEField> activeFields =
                        (List<BGE_ConfigurationWizard_CTRL.BGEField>)JSON.deserialize(
                                activeFieldsJSON,
                                List<BGE_ConfigurationWizard_CTRL.BGEField>.class
                        );

                Map<String, Schema.DescribeFieldResult> fieldMap = UTIL_Describe.getAllFieldsDescribe(
                        UTIL_Namespace.StrTokenNSPrefix('DataImport__c')
                );

                List<DescribeFieldResult> unpermittedFields = new List<DescribeFieldResult>();
                Set<String> unmappedFields = new Set<String>();

                for (BGE_ConfigurationWizard_CTRL.BGEField field : activeFields) {
                    Schema.DescribeFieldResult dataImportDFR = fieldMap.get(field.name.toLowerCase());
                    if (dataImportDFR != null) {

                        if (UTIL_Permissions.canUpdate(dataImportDFR, false)) {

                            String targetObject = '';
                            String targetField = '';
                            BDI_TargetFields targetFields =
                                    BGE_BatchGiftEntry_UTIL.targetFieldsBySourceField.get(
                                            dataImportDFR.getSObjectField());

                            if (targetFields == null) {
                                if (unmappedFields == null) {
                                    unmappedFields = new Set<String>();
                                }
                                unmappedFields.add(field.name);
                                continue;
                            }

                            Map<SObjectType, Set<SObjectField>> targetFieldsByTargetObject =
                                    targetFields.getTargetFieldsByTargetObject();

                            // One DI field can be mapped to multiple target fields although it will be rare
                            // and presents some issues with picklists; here we will return info for the first
                            // match
                            for (Schema.SObjectType targetSObjType: targetFieldsByTargetObject.keySet()) {
                                String aTargetObjectName = targetSObjType.getDescribe().getName();
                                if (BGE_BatchGiftEntry_UTIL.objectGroupNameByAllowedObjects.containsKey(
                                        aTargetObjectName)) {

                                    targetObject = aTargetObjectName;
                                    List<SObjectField> mappedTargetFields =
                                            new List<SObjectField> (targetFieldsByTargetObject.get(targetSObjType));
                                    if(mappedTargetFields.size() > 0) {
                                        targetField = mappedTargetFields[0].getDescribe().getName();
                                    }
                                }
                            }
                            DescribeFieldResult targetDFR = UTIL_Describe.getFieldDescribe(targetObject, targetField);

                            Column col = new Column();

                            col.label = dataImportDFR.label;
                            col.fieldName = dataImportDFR.name;
                            col.defaultValue = field.defaultValue;
                            col.required = field.requiredInEntryForm;
                            col.hide = field.hide;
                            col.type = UTIL_LightningComponentSupport.getLightningDataTableDataType(dataImportDFR.type);
                            // lookups aren't editable in the grid since we don't have lookup support there
                            col.readOnly = col.type == 'reference' ? true : false;
                            col.typeAttributes = '{}';
                            col.options = BGE_BatchGiftEntry_UTIL.getPicklistOptions(col.fieldName);

                            if (dataImportDFR.type == Schema.DisplayType.Reference) {
                                if (targetDFR.getReferenceTo() == dataImportDFR.getReferenceTo()) {
                                    // manually construct EXTRA column for lookup link
                                    Column linkCol = new Column();
                                    linkCol.label = dataImportDFR.getLabel();
                                    String fieldLabel = dataImportDFR.name + '_label';
                                    String fieldName = dataImportDFR.name + '_link';
                                    linkCol.fieldName = fieldName;
                                    linkCol.readOnly = true;
                                    linkCol.required = field.requiredInEntryForm;
                                    linkCol.type = 'url';
                                    linkCol.typeAttributes = '{"label":{"fieldName":"' + fieldLabel + '"},"target":"_blank"}';

                                    columns.add(linkCol);
                                    columns.add(col);
                                }
                            } else {
                                columns.add(col);
                            }

                            if (!UTIL_Permissions.canUpdate(targetDFR, false)) {
                                unpermittedFields.add(targetDFR);
                            }
                        } else {
                            unpermittedFields.add(dataImportDFR);
                        }

                    }
                }

                BGE_BatchGiftEntry_UTIL.handleMissingPermissions(unpermittedFields);

                if (!unmappedFields.isEmpty()) {
                    notices.add(new UnmappedFieldsNotice(unmappedFields));
                }
            }

            return columns;
        }
    }

    /**
    * @description The Notice displayed to the User when fields that are selected for
    * display on the Batch do not have field mappings configured in the Advanced Mapping
    * settings.
    */
    @TestVisible
    private class UnmappedFieldsNotice extends UTIL_LightningComponentSupport.Notice {
        private Set<String> unmappedFieldNames = new Set<String>();

        public UnmappedFieldsNotice(Set<String> unmappedFieldNames) {
            this.unmappedFieldNames = unmappedFieldNames;
            this.header = Label.bgeUnmappedFieldsNoticeHeader;
            this.title = Label.bgeUnmappedFieldsNoticeTitle;
            this.message = getMessage();
            setVariant(UTIL_LightningComponentSupport.Variant.WARNING);
        }

        private String getMessage() {
            String fieldNames = String.join(new List<String>(unmappedFieldNames), ', ');
            String unmappedFieldsTemplate = '';
            String fieldMappingMethod =
                    UTIL_CustomSettingsFacade.getDataImportSettings().Field_Mapping_Method__c;

            if (fieldMappingMethod == BDI_DataImportService.FM_DATA_IMPORT_FIELD_MAPPING) {
                unmappedFieldsTemplate =
                        Label.bgeUnmappedFieldsNoticeMessageAdvancedMapping;
            } else if (fieldMappingMethod == BDI_DataImportService.FM_HELP_TEXT) {
                unmappedFieldsTemplate =
                        Label.bgeUnmappedFieldsNoticeMessageHelpTextMapping;
            }

            return String.format(
                    unmappedFieldsTemplate, new List<String>{
                            fieldNames
                    });
        }
    }

    /*******************************************************************************************************
    * @description a class to retrieve DataImport__c records with derived donor information.
    */
    public class DataImportRow {
        @AuraEnabled public String donorName;
        @AuraEnabled public String donorLink;
        @AuraEnabled public String matchedRecordUrl;
        @AuraEnabled public String matchedRecordLabel;
        @AuraEnabled public DataImport__c record;
        @AuraEnabled public List<String> errors;

        public DataImportRow(DataImport__c record) {
            getDonorInfo(record);
            setDryRunRecordInfo(record);
            this.record = record;
        }

        private void getDonorInfo(DataImport__c record) {
            String donorName = '';
            if (record.Donation_Donor__c == 'Account1' && record.Account1Imported__c != null) {
                this.donorName = record.Account1Imported__r.Name;
                this.donorLink = '/'+record.Account1Imported__c;
            }
            if (record.Donation_Donor__c == 'Contact1' && record.Contact1Imported__c != null) {
                this.donorName = record.Contact1Imported__r.Name;
                this.donorLink = '/'+record.Contact1Imported__c;
            }
        }

        /***************************************************************************************************
        * @description sets DataImport__c record with matching url or failure information matching based on
        * the BDI_Donations setDryRunDonationStatuses
        * @param record: the DataImport__c record to check for matches
        */
        private void setDryRunRecordInfo(DataImport__c record) {
            try {
                String matchedUrl = '';
                String matchedUrlLabel = '';
                List<String> errors = new List<String>();

                Boolean donationMatched = (record.DonationImported__c != null);
                Boolean paymentMatched = (record.PaymentImported__c != null);
                Boolean importFailure = (record.FailureInformation__c != null);

                if (paymentMatched) {
                    //if there is a match, set url, preferably for the payment
                    String importedId = record.PaymentImported__c;
                    matchedUrlLabel = record.PaymentImported__r.Name;
                    matchedUrl = URL.getSalesforceBaseUrl().toExternalForm() + '/' + importedId;
                } else if (donationMatched) {
                    String importedId = record.DonationImported__c;
                    matchedUrlLabel = record.DonationImported__r.Name;
                    matchedUrl = URL.getSalesforceBaseUrl().toExternalForm() + '/' + importedId;
                }

                if (importFailure) {

                    //if Donation and Payment didn't have matched or matched none status, then an error was set
                    if (record.DonationImportStatus__c != null
                            && !donationMatched) {
                        errors.add(record.DonationImportStatus__c);
                    }
                    if (record.PaymentImportStatus__c != null
                            && !paymentMatched
                            && record.PaymentImportStatus__c != record.DonationImportStatus__c) {
                        errors.add(record.PaymentImportStatus__c);
                    }

                    //get any additional errors
                    if (record.FailureInformation__c != record.PaymentImportStatus__c
                            && record.FailureInformation__c != record.DonationImportStatus__c) {
                        errors.add(record.FailureInformation__c);
                    }
                }

                this.matchedRecordUrl = matchedUrl;
                this.matchedRecordLabel = matchedUrlLabel;
                this.errors = errors;

            }
            catch (Exception ex) {
                throw new AuraHandledException(ex.getMessage());
            }
        }
    }
}