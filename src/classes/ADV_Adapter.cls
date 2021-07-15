/*
    Copyright (c) 2018, Salesforce.org
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
* @date 2018
* @group TDTM
* @group-content ../../ApexDocContent/TDTM.htm
* @description Provides an adapter for Advancement package to be able to inject customizations into NPSP and provide API to inject to other project.
**/

global virtual with sharing class ADV_Adapter {
    /*******************************************************************************************************
    * @description To be called by the NPSP TDTM trigger dispatcher. Advancement will disable some NPSP trigger
    * handlers records (since they conflict with HEDA version) and return the rest.
    * @param listTH The list of Trigger handler record for further processing.
    * @return List<Trigger_Handler__c> The list of Trigger Handler record for TDTM to use.
    ********************************************************************************************************/
    global virtual List<Trigger_Handler__c> getDefaultTdtmConfigNpspRecords(List<Trigger_Handler__c> listTH) {
        if (!ADV_PackageInfo_SVC.useAdv()) {
            throw new AdapterException(Label.adapterException);
        }

        return TDTM_Config_API.getDefaultRecords();
    }

    /*******************************************************************************************************
    * @description Since Advancement will disable some NPSP trigger handler class, we need to fill in gap
    * in HEDA. Expose this API for Advancement to inject the rollup functionality into HEDA code base
    * @param listAccountId The list of Account (Id's) that need updating.
    * @return void
    ********************************************************************************************************/
    global void rollupAccounts(List<Id> listAccountId) {
        if (!ADV_PackageInfo_SVC.useAdv()) {
            throw new AdapterException(Label.adapterException);
        }

        ACCT_IndividualAccounts_TDTM.rollupAccounts(listAccountId);
    }

    /*******************************************************************************************************
    * @description Since Advancement will disable some NPSP trigger handler class, we need to fill in gap
    * in HEDA. Expose this API for Advancement to inject the moving opportunity functionality into HEDA
    * code base.
    * @param mapContactIdAccountIdNew A map of Contact Id to Account Id, for the Accounts to move opps to.
    * @param mapContactIdAccountIdOld A map of Contact Id to Account Id, for the Accounts to move opps from.
    * @return void
    ********************************************************************************************************/
    global void moveOppsToContactAccount(Map<Id,Id> mapContactIdAccountIdNew, Map<Id,Id> mapContactIdAccountIdOld) {
        if (!ADV_PackageInfo_SVC.useAdv()) {
            throw new AdapterException(Label.adapterException);
        }

        ACCT_IndividualAccounts_TDTM.moveOppsToContactAccount(mapContactIdAccountIdNew, mapContactIdAccountIdOld);
    }

    /*******************************************************************************************************
    * @description Since Advancement will disable some NPSP trigger handler class, we need to fill in gap
    * in HEDA. Expose this API for Advancement to inject the setting NPSP's system Account fields functionality
    * into HEDA code base.
    * @param a The Account that need updating.
    * @return void
    ********************************************************************************************************/
    global void configAccountForContact(Account a) {
        if (!ADV_PackageInfo_SVC.useAdv()) {
            throw new AdapterException(Label.adapterException);
        }

        if (CAO_Constants.isBucketModel()) {
            throw new AdapterException(Label.giftProcessingAccountException);
        }
        
        a.npe01__SYSTEM_AccountType__c = CAO_Constants.isHHAccountModel() ? CAO_Constants.HH_ACCOUNT_TYPE : CAO_Constants.ONE_TO_ONE_ORGANIZATION_TYPE;
        a.Type = CAO_Constants.isHHAccountModel() ? CAO_Constants.HH_TYPE : '';
        a.npe01__SYSTEMISINDIVIDUAL__c = true;
    }

    /*******************************************************************************************************
    * @description Since Advancement will disable some NPSP trigger handler class, we need to fill in gap in HEDA.
    * Expose this API for Advancement to inject the setting NPSP's system Account fields functionality into HEDA code base
    * @param listNew The list of Account from trigger new.
    * @param listOld The list of Account from trigger old.
    * @param action The trigger event (BeforeInsert, AfterInsert, etc.).
    * @return void
    ********************************************************************************************************/
    global void configAccountTDTM(List<SObject> listNew, List<SObject> listOld, String action) {
        if (!ADV_PackageInfo_SVC.useAdv()) {
            throw new AdapterException(Label.adapterException);
        }

        TDTM_Runnable.Action triggerAction = TDTM_TriggerActionHelper.getTriggerActionFromName(action);

        Accounts accounts = new Accounts(listNew, listOld);
        switch on triggerAction {
            when BeforeInsert {
                accounts.setAccountTypeAndIndividualFieldValues();
            }

            when BeforeUpdate {
                accounts.setAccountTypeAndIndividualFieldValues();
                accounts.setSystemAccountTypeAndIndividualFieldValues();
            }
        }
    }

    /*******************************************************************************************************
    * @description This is the expection class for ADV_Adapter class
    ********************************************************************************************************/
    private class AdapterException extends Exception{}
}