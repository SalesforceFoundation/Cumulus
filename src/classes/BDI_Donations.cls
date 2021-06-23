/*
    Copyright (c) 2019 Salesforce.org
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
* @group Batch Data Import
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Helper class for the Batch Data Importer, dealing with Donations, ie, Opps and Payments
*
*/
public class BDI_Donations {

    /*******************************************************************************************************
    * @description constructor for the BDI Donations helper
    * @param bdi The Batch Data Import Service the helper should use
    * @return void
    */ 
    public BDI_Donations(BDI_DataImportService bdi) {
        this.bdi = bdi;
    }

    /*******************************************************************************************************
    * @description The Batch Data Import Service the helper should use
    */ 
    private BDI_DataImportService bdi { get; set; }

    /*******************************************************************************************************
    * @description map to track the Opportunity created/matched for each DI record
    */ 
    private Map<Id, Opportunity> opportunitiesByDataImportId = new Map<Id, Opportunity>();

    /*******************************************************************************************************
    * @description map to track the Payment created/matched for each DI record
    */ 
    private Map<Id, npe01__OppPayment__c> paymentsByDataImportId = new Map<Id, npe01__OppPayment__c>();
    
    /*******************************************************************************************************
    * @description provides a valid Close Won Opportunity Stage
    */
    private static String defaultClosedWonStage {
        get {   
            if (defaultClosedWonStage == null){
                List<OpportunityStage> stages = [
                    SELECT MasterLabel
                    FROM OpportunityStage
                    WHERE IsActive = true
                        AND IsWon = true
                ];
                if (stages.size() > 0) {
                    defaultClosedWonStage = stages[0].MasterLabel;
                } else {
                    defaultClosedWonStage = '';
                }
            }
            return defaultClosedWonStage;
        }
        set;
    }

    /*******************************************************************************************************
    * @description the class object that supports the BDI_IMatchDonations interface
    */
    private BDI_IMatchDonations iMatchDonations {
        get {
            if (iMatchDonations == null) {
                iMatchDonations = (BDI_IMatchDonations)BDI_DataImportService.instantiateClassForInterface(
                    'BDI_IMatchDonations',
                    bdi.diSettings.Donation_Matching_Implementing_Class__c
                );
                if (iMatchDonations == null) {
                    iMatchDonations = new BDI_MatchDonations();
                }
            }
            return iMatchDonations;
        }
        set;
    }
    
    /*******************************************************************************************************
    * @description the map of DI Donation Fields to Opportunity Fields
    */
    public Map<String, String> dataImportFieldToOpportunityField {
        get {
            if (dataImportFieldToOpportunityField == null) {
                dataImportFieldToOpportunityField = bdi.mapDataImportFields(
                    'Opportunity', 'Opportunity',
                    BDI_DataImportService.listStrDataImportFields
                );
            }
            return dataImportFieldToOpportunityField;
        }
        set;
    }
    
    /*******************************************************************************************************
    * @description the map of DI Donation Fields to Payment Fields
    */
    public Map<String, String> dataImportFieldToPaymentField {
        get {
            if (dataImportFieldToPaymentField == null) {
                dataImportFieldToPaymentField = bdi.mapDataImportFields(
                    'Payment', 'npe01__OppPayment__c',
                    BDI_DataImportService.listStrDataImportFields);
            }
            return dataImportFieldToPaymentField;
        }
        set;
    }

    /*******************************************************************************************************
    * @description Imports the appropriate Donations into NPSP, following matching rules and criteria
    * to potentially match existing Opportunities or Payments.
    * @return void
    */ 
    public void importDonations() {
    
        // get our matching behavior to use
        String matchBehavior = bdi.diSettings.Donation_Matching_Behavior__c;

        // get the list of DI records that have donations to process
        List<DataImport__c> dataImportDonations = validateDonationsToProcess(matchBehavior);

        List<DataImport__c> elevateDIs = new List<DataImport__c>();
        List<DataImport__c> nonElevateDIs = new List<DataImport__c>();

        for (DataImport__c di : dataImportDonations) {
            if (isElevatePaymentDI(di)) {
                elevateDIs.add(di);
            } else {
                nonElevateDIs.add(di);
            }
        }

        // call the extension to match against existing donations
        if (matchBehavior != BDI_DataImport_API.DoNotMatch && nonElevateDIs.size() > 0) {
            BDI_PerfLogger.PerfLog logger = BDI_DataImportService.perfLogger.newPerfLog('iMatchDonations.match');
            iMatchDonations.match(bdi, nonElevateDIs, opportunitiesByDataImportId, paymentsByDataImportId);
            logger.stop();
        }
        
        // now go thru the new & existing donations and update them
        List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        List<DataImport__c> dataImportsToInsert = new List<DataImport__c>();
        List<DataImport__c> dataImportsToUpdate = new List<DataImport__c>();

        for (DataImport__c dataImport : dataImportDonations) {
            try {
                if (dataImport.DonationImportStatus__c == Label.bdiMatchedApplyNewPayment) {
                    // park a new empty payment in the map if the user specified Apply New Payment
                    paymentsByDataImportId.put(
                            dataImport.Id,
                            new npe01__OppPayment__c(
                                    npe01__Opportunity__c = dataImport.DonationImported__c
                            )
                    );
                    dataImport.PaymentImportStatus__c = Label.bdiCreated;
                } else {
                    // Validate our desired matching behavior (exact match, best match, new, etc.) unless its a Elevate
                    // Payment that was not matched in the first place.
                    if (!isElevatePaymentDI(dataImport) && !isValidMatchBehavior(dataImport, matchBehavior)) {
                        continue;
                    }

                    // update the new or existing Opp with the DI's field data
                    Opportunity opp = prepareOppForUpdateInsert(dataImport);

                    // handle any error from the prepare
                    if (opp == null) {
                        continue;
                    }

                    if (shouldSetDonationBatchNumber(opp, dataImport)) {
                        opp.put(Opportunity.Batch_Number__c, dataImport.NPSP_Data_Import_Batch__r.Batch_Number__c);
                    }

                    if (opp.Id == null) {
                        opportunitiesToInsert.add(opp);
                        dataImportsToInsert.add(dataImport);
                    } else {
                        opportunitiesToUpdate.add(opp);
                        dataImportsToUpdate.add(dataImport);
                    }

                    // for some error handling detection tests
                    if (Test.isRunningTest() && opp.Name != null && opp.Name.startsWith('FailTest')) {
                        opp.Name = null;
                    }
                }
            } catch (Exception ex) {
                bdi.LogBDIError(dataImport, ex.getMessage(), 'DonationImportStatus__c');
            }
        }

        if (bdi.isDryRun) {
            setDryRunDonationStatuses(dataImportDonations);
            return;
        }

        // insert our new Opps
        List<Database.SaveResult> results = UTIL_DMLService.insertRecords(opportunitiesToInsert, false);
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            if (!result.isSuccess()) {
                bdi.LogBDIError(dataImportsToInsert[i], result.getErrors()[0].getMessage(), 'DonationImportStatus__c');
            } else {
                dataImportsToInsert[i].DonationImported__c = opportunitiesToInsert[i].Id;
                if (dataImportsToInsert[i].DonationImportStatus__c != System.Label.bdiMatchedByUserNewOpp) {
                    dataImportsToInsert[i].DonationImportStatus__c = System.Label.bdiCreated;
                }
            }
        }

        // update our matched Opps
        results = UTIL_DMLService.updateRecords(opportunitiesToUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            if (!result.isSuccess()) {
                bdi.LogBDIError(dataImportsToUpdate[i], result.getErrors()[0].getMessage(), 'DonationImportStatus__c');
            } else {

                // Setting status to updated for elevate opportunities that were updated.
                // Non-Elevate Donations would typically have a matched status instead.
                if (isElevatePaymentDI(dataImportsToUpdate[i])) {
                    dataImportsToUpdate[i].DonationImportStatus__c = System.label.bdiUpdated;
                }
            }
        }

        // when we mark Payments paid, ensure they will close our Opp.
        npe01__Contacts_And_Orgs_Settings__c cs = UTIL_CustomSettingsFacade.getContactsSettings();
        if (cs.Payments_Auto_Close_Stage_Name__c == null) {
            cs.Payments_Auto_Close_Stage_Name__c = defaultClosedWonStage;
        }

        if (elevateDIs.size() > 0) {
            // Handle construction/update of Elevate Related Payments
            processPaymentsForElevateDIs(elevateDIs);

        }

        if (nonElevateDIs.size() > 0) {
            // mark any non-Elevate paid Payments we matched
            markPaidPayments(nonElevateDIs);

            // add any new non-Elevate payments to our map
            trackPayments(nonElevateDIs);
        }

        // update payments with any data from the DI record
        updatePayments(dataImportDonations);
    }

    /*******************************************************************************************************
    * @description Determine if the data import batch number should be set on the opportunity or payment
    * @param targetObject The opportunity or payment SObject record
    * @param dataImport The data import record being processed
    * @return Boolean TRUE when the Data Import Batch has a batch number, is not a dry run,
    * and the current SObject is an Opportunity or Opportunity Payment
    */
    @TestVisible
    private Boolean shouldSetDonationBatchNumber(SObject targetObject, DataImport__c dataImport) {
        if (bdi.isDryRun ||
            String.isBlank(dataImport.NPSP_Data_Import_Batch__c) ||
            String.isBlank(dataImport.NPSP_Data_Import_Batch__r.Batch_Number__c)) {
            return false;
        }

        SObjectType objectType = targetObject.getSObjectType();


        if (objectType == Opportunity.SObjectType) {
            return targetObject.get(Opportunity.Id) == null;
        } else if (objectType == npe01__OppPayment__c.SObjectType) {
            return targetObject.get(npe01__OppPayment__c.npe01__Paid__c) == true;
        }
        return false;
    }

    /*******************************************************************************************************
    * @description validate bdi records for donations and return those to process
    * @param matchBehavior The match behavior to validate against
    * @return List<DataImport__c> The list of BDI records that have donations to process
    */
    private List<DataImport__c> validateDonationsToProcess(String matchBehavior) {
        List<DataImport__c> dataImportDonations = new List<DataImport__c>();
        for (DataImport__c dataImport : bdi.listDI) {
            Boolean anyDonationFieldsPopulated =
                    BDI_DataImportService.anyFieldsPopulatedForObjectMapping(dataImport,
                            dataImportFieldToOpportunityField);
            Boolean anyPaymentFieldsPopulated =
                    BDI_DataImportService.anyFieldsPopulatedForObjectMapping(dataImport,dataImportFieldToPaymentField);

            // skip di's that already have an error
            if (dataImport.Status__c == BDI_DataImport_API.bdiFailed) {
               continue;
            }

            //If there are no Donation Fields or Payment Fields populated and no donation amount populated then
            //do not continue with donation processing.
            if (dataImport.Donation_Amount__c == null && !anyDonationFieldsPopulated && !anyPaymentFieldsPopulated) {
                continue;
            }

            // Skip DIs that have no fields populated for donation and no DonationImported Id, which means they are
            // not new Donations and not in the DI to serve as a parent for a new payment.
            if (dataImport.DonationImported__c == null && !anyDonationFieldsPopulated) {
                continue;
            }

            // If the donation was created / matched / updated on a previous run, and there aren't any payment fields
            // that may need to populated then skip over this DI record.

            if (dataImport.DonationImported__c != null
                    && !anyPaymentFieldsPopulated
                    && (dataImport.DonationImportStatus__c == System.Label.bdiCreated
                    || dataImport.DonationImportStatus__c == System.Label.bdiMatched
                    || dataImport.DonationImportStatus__c == System.Label.bdiUpdated)) {
                continue;
            }

            // skip di's that have an OppId or PaymentId, but we were told to do no matching.  in this case
            // they must have already been created for this di on a previous run, and we don't want to create another.
            // Elevate DIs should be specifically excluded from this for update processing.
            if ((dataImport.DonationImported__c != null || dataImport.PaymentImported__c != null)){

                if (isElevatePaymentDI(dataImport)) {
                    dataImportDonations.add(dataImport);
                    continue;
                } else if (matchBehavior == BDI_DataImport_API.DoNotMatch) {
                    continue;
                }
            }

            if (dataImport.Donation_Donor__c == 'Contact1' || (dataImport.Donation_Donor__c == null && dataImport.Donation_Amount__c != null)) {
                dataImport.Donation_Donor__c = 'Contact1';
                Contact con = bdi.ContactFromDi(dataImport, 1);
                if (con == null) {
                    bdi.LogBDIError(dataImport, System.Label.bdiErrorInvalidDonor, 'DonationImportStatus__c');
                    continue;
                }
            } else if (dataImport.Donation_Donor__c == 'Account1') {
                Account acc = bdi.AccountFromDi(dataImport, 1);
                if (acc == null) {
                    bdi.LogBDIError(dataImport, System.Label.bdiErrorInvalidDonor, 'DonationImportStatus__c');
                    continue;
                }
            } else if (dataImport.Donation_Donor__c != null) {
                bdi.LogBDIError(dataImport, System.Label.bdiErrorInvalidDonor, 'DonationImportStatus__c');
                continue;
            } else {
                // this DI record does not have a donation!
                continue;
            }
            // add the donation to our list
            dataImportDonations.add(dataImport);
        }
        return dataImportDonations;
    }

    /*******************************************************************************************************
    * @description validate whether the current donation record was appropriately matched to an exact,
    * best, or new donation record given the matchingBehavior.  Invalid matches will be marked as an
    * error in the DI record.
    *
    * @param dataImport The DataImport record to validate
    * @param matchBehavior The match behavior to validate against
    * @return boolean True if valid, False if not
    */
    private Boolean isValidMatchBehavior(DataImport__c dataImport, String matchBehavior) {
        String errorMessage;

        // always allow matching by Id, regardless of specified behavior
        if (dataImport.DonationImportStatus__c == System.Label.bdiMatchedId
                || dataImport.DonationImportStatus__c == System.Label.bdiMatchedByUser) {
            return true;
        }
        // always error if they provided Donation or Payment ID, but it wasn't valid
        if ((dataImport.DonationImported__c != null || dataImport.PaymentImported__c != null) &&
            dataImport.DonationImportStatus__c == System.Label.bdiMatchedNone) {

            errorMessage = System.Label.bdiErrorDonationLookupMatch;
            // usually we clear the payment status, but if it's Id might have been at fault, let's put the message there too!
            if (dataImport.PaymentImported__c != null) {
                dataImport.PaymentImportStatus__c = System.Label.bdiErrorDonationLookupMatch;
            }
        } else if (matchBehavior == BDI_DataImport_API.RequireNoMatch && dataImport.DonationImported__c != null) {
            errorMessage = System.Label.bdiErrorDonationRequireNoMatch;
        } else if (matchBehavior == BDI_DataImport_API.RequireExactMatch && dataImport.Payment_Possible_Matches__c != null) {
            errorMessage = System.Label.bdiErrorPaymentMultiMatch;
        } else if (matchBehavior == BDI_DataImport_API.RequireExactMatch && dataImport.Donation_Possible_Matches__c != null) {
            errorMessage = System.Label.bdiErrorDonationMultiMatch;
        } else if (matchBehavior == BDI_DataImport_API.RequireExactMatch && dataImport.DonationImported__c == null) {
            errorMessage = System.Label.bdiErrorDonationNoMatch;
        } else if (matchBehavior == BDI_DataImport_API.ExactMatchOrCreate && dataImport.Donation_Possible_Matches__c != null) {
            errorMessage = System.Label.bdiErrorDonationMultiMatch;
        } else if (matchBehavior == BDI_DataImport_API.RequireBestMatch && dataImport.DonationImported__c == null) {
            errorMessage = System.Label.bdiErrorDonationNoMatch;
        }
        else {
            // valid behavior
            return true;
        }

        // Since we have a hard time constraining the length of translated labels, truncate here
        if(errorMessage.length() > 255) {
            errorMessage = errorMessage.substring(0,255);
        }

        // clear the match so it won't be used (but only if we think the user didn't put it in themselves!)
        if (errorMessage != System.Label.bdiErrorDonationLookupMatch) {

            // move any match that we reject to possible matches
            if (dataImport.Donation_Possible_Matches__c == null) {
                dataImport.Donation_Possible_Matches__c = dataImport.DonationImported__c;
            }
            if (dataImport.Payment_Possible_Matches__c == null) {
                dataImport.Payment_Possible_Matches__c = dataImport.PaymentImported__c;
            }

            dataImport.DonationImported__c = null;
            dataImport.PaymentImported__c = null;
            dataImport.PaymentImportStatus__c = errorMessage;
        }

        // invalid behavior
        bdi.LogBDIError(dataImport, errorMessage, 'DonationImportStatus__c');
        return false;
    }

    /*******************************************************************************************************
    * @description for the provided DataImport record, create or update the appropriate Opp (in memory)
    * with data from the DI record, and return it unsaved.
    *
    * @param dataImport The DataImport record to prepare the Opportunity for
    * @return Opportunity A new or existing Opportunity. Null if there was an error.
    */
    private Opportunity prepareOppForUpdateInsert(DataImport__c dataImport) {
        Opportunity opp = opportunitiesByDataImportId.get(dataImport.Id);
        String opportunityName;

        if (isElevatePaymentDI(dataImport) && dataImport.DonationImported__c != null) {
            opp = new Opportunity (Id = dataImport.DonationImported__c);
            opportunitiesByDataImportId.put(dataImport.Id,opp);
        }

        // If the opportunity doesn't have any fields mapped, then no creation or update for the oppt is necessary.  If
        // it has a DonationImported__c value then it is likely there to serve as parent to a payment.  Return a null
        // oppt so no DML happens for it, and set the DonationImportStatus to matched by Id if it isn't already.
        if (!BDI_DataImportService.anyFieldsPopulatedForObjectMapping(dataImport,dataImportFieldToOpportunityField)) {
            opp = null;

            if (dataImport.DonationImportStatus__c == null && dataImport.DonationImported__c != null) {
                dataImport.DonationImportStatus__c = System.label.bdiMatchedId;
            }

            return opp;
        }

        // if there is no opp matched, create one for it
        Boolean isNew = (opp == null);
        if (isNew) {
            opp = new Opportunity();
            opportunitiesByDataImportId.put(dataImport.Id, opp);

            if (dataImport.RecurringDonationImported__c != null
                && (dataImport.RecurringDonationImportStatus__c == System.label.bdiMatched ||
                    dataImport.RecurringDonationImportStatus__c == System.label.bdiCreated ||
                    dataImport.RecurringDonationImportStatus__c == System.label.bdiUpdated)) {
                opp.npe03__Recurring_Donation__c = dataImport.RecurringDonationImported__c;
            }
            
            if (dataImport.Donation_Donor__c == 'Account1') {
                Account acc = bdi.AccountFromDi(dataImport, 1);
                opp.AccountId = acc.Id;
                opportunityName = acc.Name;
            } else { // we can assume it's for Contact1
                Contact con = bdi.ContactFromDi(dataImport, 1);
                opp.npe01__Contact_Id_for_Role__c = con.Id;
                opp.Primary_Contact__c = con.Id;
                opp.Primary_Contact_Campaign_Member_Status__c = dataImport.Campaign_Member_Status__c;
                opp.AccountId = con.AccountId;
                opportunityName =  (!String.isBlank(con.FirstName)
                                    ? con.FirstName + ' '
                                    : '')
                                    + con.LastName;
            }
        }

        if (dataImport.Donation_Record_Type_Name__c != null) {
            Id donationRecordTypeId = UTIL_RecordTypes.getRecordTypeId(Opportunity.sObjectType,
                                                        dataImport.Donation_Record_Type_Name__c);
            if (donationRecordTypeId == null) {
                bdi.LogBDIError(dataImport, System.Label.bdiErrorInvalidOppRTName, 'DonationImportStatus__c');
                return null;
            }
            opp.RecordTypeId = donationRecordTypeId;
            opportunityName += ' ' + dataImport.Donation_Record_Type_Name__c;
        } else {
            opportunityName += ' ' + System.Label.bdiDonation;
        }

        if (bdi.isDryRun) {
            return opp;
        }

        if (dataImport.Donation_Date__c == null) {
            if (isNew) {
                dataImport.Donation_Date__c = System.today();
            } else {
                dataImport.Donation_Date__c = opp.CloseDate;
            }
        }

        if (dataImport.Donation_Name__c == null) {
            if (isNew) {
                dataImport.Donation_Name__c = opportunityName + ' ' + dataImport.Donation_Date__c.format();
            } else {
                dataImport.Donation_Name__c = opp.Name;
            }
        }

        if (dataImport.Donation_Stage__c == null && defaultClosedWonStage != ''
                && dataImport.PaymentImported__c == null) {
            dataImport.Donation_Stage__c = defaultClosedWonStage;
        }

        //Suppressing automatic payment creation for Elevate Payment DIs, since we always want to create it
        if (isElevatePaymentDI(dataImport)) {
            opp.npe01__Do_Not_Automatically_Create_Payment__c = true;
        }

        Boolean useCustomMappingInsteadOfCurrencyIsoCode = false;

        // Set useCustomMappingInsteadOfCurrencyIsoCode
        for (String dataImportField : dataImportFieldToOpportunityField.keySet()) {
            String currentValue = dataImportFieldToOpportunityField.get(dataImportField);

            // If we have a custom mapping against the field CurrencyIsoCode of the Data Import object.
            if (dataImportField != 'CurrencyIsoCode' && currentValue == 'CurrencyIsoCode') {
                String customCurrencyIsoCodeFieldOnDataImport = (String) dataImport.get(dataImportField);
                if (!String.isEmpty(customCurrencyIsoCodeFieldOnDataImport)) {
                    useCustomMappingInsteadOfCurrencyIsoCode = true;
                    break;
                }
            }
        }

        String donationRecordTypeName = UTIL_Namespace.StrTokenNSPrefix('Donation_Record_Type_Name__c');
        String donationStage = UTIL_Namespace.StrTokenNSPrefix('Donation_Stage__c');
        String donationAmount = UTIL_Namespace.StrTokenNSPrefix('Donation_Amount__c');

        // now copy over all the data to the Opp
        for (String dataImportField : dataImportFieldToOpportunityField.keySet()) {

            // skip recordtype which we special cased above
            if (dataImportField == donationRecordTypeName) {
                continue;
            }

            // Don't copy over Stage or Amount if we are applying a new Payment or updating a Payment
            // Exclude elevate updates of Opportunity since we do want to copy the stage
            if (!isElevatePaymentDI(dataImport)) {
                if (dataImportField == donationStage || dataImportField == donationAmount) {
                    if (dataImport.DonationImportStatus__c != System.Label.bdiMatchedApplyNewPayment
                            && dataImport.PaymentImported__c != null) {
                        continue;
                    }
                }
            }

            // If the user has a custom field on the Data Import which maps to CurrencyIsoCode
            if (dataImportField == 'CurrencyIsoCode' && useCustomMappingInsteadOfCurrencyIsoCode) {
                continue;
            }
            BDI_DataImportService.copyDIFieldToDestinationRecord(dataImport,
                    dataImportField,
                    opp,
                    dataImportFieldToOpportunityField);
        }

        // the Opp is ready!
        return opp;
    }

    /*******************************************************************************************************
    * @description Updates the Donation Status in the provided donations to the Dry Run appropriate Status.
    * @param dataImportDonations The DI Records that have donations to import
    * @return void
    */
    private void setDryRunDonationStatuses(List<DataImport__c> dataImportDonations) {

        Map<String, String> importStatusToDryRunStatus = new Map<String, String>{
            BDI_DataImport_API.bdiFailed => bdi.statusDIFailed(),
            System.Label.bdiMatched => bdi.statusMatchedExisting(),
            System.Label.bdiMatchedBest => bdi.statusMatchedBest(),
            System.Label.bdiMatchedNone => bdi.statusMatchedNone(),
            System.Label.bdiMatchedId => bdi.statusMatchedById()
        };

        for (DataImport__c dataImport : dataImportDonations) {
            String donationImportStatus = importStatusToDryRunStatus.get(dataImport.DonationImportStatus__c);
            if (donationImportStatus != null) {
                dataImport.DonationImportStatus__c = donationImportStatus;
            }

            String paymentImportStatus = importStatusToDryRunStatus.get(dataImport.PaymentImportStatus__c);
            if (paymentImportStatus != null) {
                dataImport.PaymentImportStatus__c = paymentImportStatus;
            }

            String donationCampaignImportStatus = importStatusToDryRunStatus.get(dataImport.DonationCampaignImportStatus__c);
            if (donationCampaignImportStatus != null) {
                dataImport.DonationCampaignImportStatus__c = donationCampaignImportStatus;
            }
        }
    }

    /*******************************************************************************************************
    * @description marks Payments that we matched as Paid, and with correct date and amount
    * @param dataImportDonations The DI Records that have donations to import
    * @return void
    */
    public void markPaidPayments(List<DataImport__c> dataImportDonations) {

        // mark existing Payments paid.
        for (DataImport__c dataImport : dataImportDonations) {
            // skip di's that already have an error
            if (dataImport.Status__c == BDI_DataImport_API.bdiFailed) {
                continue;
            }
            if (dataImport.PaymentImported__c != null
                    || dataImport.DonationImportStatus__c == System.Label.bdiMatchedApplyNewPayment) {
                npe01__OppPayment__c payment = paymentsByDataImportId.get(dataImport.Id);
                payment.npe01__Paid__c = true;
                payment.npe01__Payment_Amount__c = dataImport.Donation_Amount__c;
                if (payment.npe01__Payment_Date__c == null) {
                    payment.npe01__Payment_Date__c = dataImport.Donation_Date__c;
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description Updates our map of DI records to Payments to include the Payments just auto-created
    * when we created new Opps, or pmt's for matched Opps that we haven't yet tracked.
    * @param dataImportDonations The DI Records that have donations to import
    * @return void
    */
    public void trackPayments(List<DataImport__c> dataImportDonations) {

        // find the Opps for our missing payments and mark existing Payments paid.
        List<Id> opportunityIds = new List<Id>();
        for (DataImport__c dataImport : dataImportDonations) {
            // skip di's that already have an error
            if (dataImport.Status__c == BDI_DataImport_API.bdiFailed) {
                continue;
            }
            // skip DIs where user selected Apply New Payment
            if (dataImport.DonationImportStatus__c == System.Label.bdiMatchedApplyNewPayment) {
                continue;
            }
            if (dataImport.DonationImported__c != null && dataImport.PaymentImported__c == null) {
                opportunityIds.add(dataImport.DonationImported__c);
            }
        }

        // query for the new payments
        if (opportunityIds.size() > 0) {
            Map<Id, npe01__OppPayment__c> mapOppIdToPayment = new Map<Id, npe01__OppPayment__c>();
            String paymentQuery = buildPaymentQuery('opportunityIds');
            for (npe01__OppPayment__c payment : Database.query(paymentQuery)) {
                mapOppIdToPayment.put(payment.npe01__Opportunity__c, payment);
            }

            // store the Payments into our shared map and update their DI record
            for (DataImport__c dataImport : dataImportDonations) {
                // skip di's that already have an error
                if (dataImport.Status__c == BDI_DataImport_API.bdiFailed) {
                    continue;
                }
                if (dataImport.DonationImported__c != null && dataImport.PaymentImported__c == null) {
                    npe01__OppPayment__c payment = mapOppIdToPayment.get(dataImport.DonationImported__c);
                    if (payment != null) {
                        dataImport.PaymentImported__c = payment.Id;
                        // could be new or matched
                        dataImport.PaymentImportStatus__c = dataImport.DonationImportStatus__c;
                        paymentsByDataImportId.put(dataImport.Id, payment);
                    }
                }
            }
        }
    }

    /*******************************************************************************************************
    * @description returns the soql to use for querying Payments
    * @return String the soql string
    */
    private String buildPaymentQuery(String eligibleOpportunitiesVariableName) {
        // the set of Payment fields for our soql
        Set<String> setPmtFields = new Set<String>();
        setPmtFields.add('Id');
        setPmtFields.add('npe01__Opportunity__c');
        setPmtFields.add('npe01__Payment_Amount__c');
        setPmtFields.add('npe01__Payment_Date__c');
        setPmtFields.add('npe01__Scheduled_Date__c');
        setPmtFields.add('npe01__Paid__c');

        // need to include any Pmt fields we may update, so we can compare against them
        setPmtFields.addAll(dataImportFieldToPaymentField.values());

        String soql = 'SELECT ' + String.join(new List<String>(setPmtFields), ',');
        soql += ' FROM npe01__OppPayment__c WHERE ' +
                'npe01__Written_Off__c = false ' +
                'AND npe01__Opportunity__c in :' + eligibleOpportunitiesVariableName;

        return soql;
    }

    /*******************************************************************************************************
    * @description Updates any fields on payment objects created for the Data Import opportunities.
    * @param dataImportsWithDonations The DI Records that have donations to import
    * @return void
    */
    public void updatePayments(List<DataImport__c> dataImportsWithDonations) {

        List<npe01__OppPayment__c> paymentsToUpdate = new List<npe01__OppPayment__c>();
        List<DataImport__c> dataImportsToUpdate = new List<DataImport__c>();

        // update payments
        for (DataImport__c dataImport : dataImportsWithDonations) {
            // skip di's that already have an error
            if (dataImport.Status__c == BDI_DataImport_API.bdiFailed) {
                continue;
            }
            if (dataImport.PaymentImported__c != null
                    || dataImport.DonationImportStatus__c == Label.bdiMatchedApplyNewPayment
                    || isElevatePaymentDI(dataImport)) {
                npe01__OppPayment__c payment = paymentsByDataImportId.get(dataImport.Id);
                if (payment != null) {
                    if (shouldSetDonationBatchNumber(payment, dataImport)) {
                        payment.put(npe01__OppPayment__c.Batch_Number__c,
                            dataImport.NPSP_Data_Import_Batch__r.Batch_Number__c);
                    }

                    Integer numberOfCopiedFields = 0;
                    for (String dataImportField : dataImportFieldToPaymentField.keySet()) {
                        if (BDI_DataImportService.copyDIFieldToDestinationRecord(dataImport,
                                                                                 dataImportField,
                                                                                 payment,
                                                                                 dataImportFieldToPaymentField)) {
                            numberOfCopiedFields++;
                        }
                    }
                    // if it's marked paid, we know we need to update it regardless of any copied fields
                    if (numberOfCopiedFields > 0 || payment.npe01__Paid__c) {
                        paymentsToUpdate.add(payment);
                        dataImportsToUpdate.add(dataImport);
                    }
                }
            }
        }
        List<Database.UpsertResult> results = UTIL_DMLService.upsertRecords(paymentsToUpdate, false);
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult result = results[i];
            if (!result.isSuccess()) {                
                bdi.LogBDIError(
                    dataImportsToUpdate[i], 
                    result.getErrors()[0].getMessage(), 
                    'PaymentImportStatus__c'
                );               
            } else {
                if(isElevatePaymentDI(dataImportsToUpdate[i])) {
                    if (result.isCreated()) {
                        dataImportsToUpdate[i].PaymentImportStatus__c = System.label.bdiCreated;
                        dataImportsToUpdate[i].PaymentImported__c =result.getId();
                    } else {
                        dataImportsToUpdate[i].PaymentImportStatus__c = System.label.bdiUpdated;
                    }
                }
            }
        }

        for (DataImport__c dataImport : dataImportsWithDonations) {
            if (dataImport.DonationImportStatus__c == Label.bdiMatchedApplyNewPayment) {
                dataImport.PaymentImported__c = paymentsByDataImportId.get(dataImport.Id).Id;
            }
        }
    }

    /*******************************************************************************************************
    * @description helper method to return true if the record is an elevate oppt/payment and false if not.
    * @param dataImportToReview the DI to determine if it is from Elevate
    * @return result 
    */
    private Boolean isElevatePaymentDI(DataImport__c di) {
        return di.Payment_Elevate_Id__c != null;
    }


    /*******************************************************************************************************
    * @description Populates new and updates existing payments as needed for elevate related transactions.
    * @param dataImportsById map of Data import records by their ids. 
    */
    private void processPaymentsForElevateDIs (DataImport__c[] dataImports) {

        if (dataImports != null && dataImports.size() > 0) {
            DataImport__c[] newPaymentDIs = new DataImport__c[]{};
    
            for (DataImport__c di : dataImports) {

                // For new opportunities, and thus new payments, add to a list for querying the existing oppt.
                if (di.DonationImportStatus__c == System.Label.bdiCreated) {
                    newPaymentDIs.add(di);
                // For existing payments determine if any fields are populated before attempting update
                } else if (di.PaymentImported__c != null 
                    && BDI_DataImportService.anyFieldsPopulatedForObjectMapping(di,dataImportFieldToPaymentField)){
                    paymentsByDataImportId.put(di.Id,new npe01__OppPayment__c(Id = di.PaymentImported__c));
                }
            }

            //If there are DIs that need new Payments then construct
            if (newPaymentDIs.size() > 0) {
                constructNewPayments(newPaymentDIs);
            }
        }
    }

    /*******************************************************************************************************
    * @description Queries Opportunities from DIs that have a DonationImported__c value.  This is primarily to 
    * retreive Oppt field data for Elevate Payments to be constructed inside of the BDI code.
    * @param disWithOpptForQuery Data Import records that have the DonationImported__c field populated
    * @return opportunitiesById the opportunities returned by the query
    */
    private Map<Id, Opportunity> queryElevateOppts(DataImport__c[] disWithOpptForQuery) {
        Set<Id> opptIdsForQuery = new Set<Id>();
        Map<Id, Opportunity> resultOpptsById = new Map<Id,Opportunity>();

        for (DataImport__c di : disWithOpptForQuery) {
            opptIdsForQuery.add(di.DonationImported__c);
        }

        Set<String> fieldNamesForQuery = new Set<String>{'id','stagename','closedate','amount','isclosed'};

        if (UserInfo.isMultiCurrencyOrganization()) {
            fieldNamesForQuery.add('currencyisocode');
        }

        // Add all the payment mappings to the list of fields to be queried since they will
        // need to be copied to the payment.
        for (npe01__Payment_Field_Mapping_Settings__c pfms : PMT_PaymentCreator.paymentMappings.values()) {
            fieldNamesForQuery.add(pfms.npe01__Opportunity_Field__c.toLowerCase());
        }

        String query = 'SELECT ';
        
        // Build SELECT portion of query
        for (String opptField : fieldNamesForQuery) {
            query += opptField + ',';
        }

        // Remove trailing comma and space
        query = query.removeEnd(',');

        // add FROM and WHERE clauses
        query += ' FROM Opportunity WHERE Id IN: opptIdsForQuery';

        Opportunity[] oppts = Database.query(query);
        
        if (oppts != null) {
            resultOpptsById = new Map<Id,Opportunity>(oppts);
        }

        return resultOpptsById;
    }

    /*******************************************************************************************************
    * @description Queries the parent opportunities for new Elevate payments and constructs a the new Payment
    * record using the existing logic in PMT_PaymentCreator for consistency.
    * @param disWithOpptForQuery Data Import records that have the DonationImported__c field populated
    * @return opportunitiesById the opportunities returned by the query
    */
    private void constructNewPayments (DataImport__c[] disForNewPayment) {

        Map<Id, Opportunity> parentOpptsByDiId = queryElevateOppts(disForNewPayment);

        // Cycle through the DI records and
        for (DataImport__c di : disForNewPayment) {
            Opportunity parentOppt = parentOpptsByDiId.get(di.DonationImported__c);
            if (parentOppt != null) {
                npe01__OppPayment__c newPayment = PMT_PaymentCreator.constructOppPayment(parentOppt,
                                                                    PMT_PaymentCreator.PaymentCurrencyField,
                                                                    PMT_PaymentCreator.OppCurrencyField);
                paymentsByDataImportId.put(di.Id,newPayment);
            }
        }
    }
} // BDI_Donations
