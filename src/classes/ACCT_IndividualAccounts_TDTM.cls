/*
    Copyright (c) 2009, Salesforce.org
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
* @date 2011 (1.x)
* @group Accounts
* @description Implements one of three account models, 1x1 or bucket or HH - controls syncing within the model
*/
public class ACCT_IndividualAccounts_TDTM extends TDTM_Runnable {

    /*******************************************************************************************************************
     * @description Trigger Handler on Contact that handles account management.  Depending on the Account
     * Model, creates a Household Account, One-to-One Account, or uses the Individual Bucket Account.
     * @param newSObjects the list of Contacts from trigger new.
     * @param oldSObjects the list of Contacts from trigger old.
     * @param triggerAction which trigger event (BeforeInsert, AfterInsert, etc.).
     * @param objResult the describe for Contacts
     * @return dmlWrapper.
     ********************************************************************************************************************/
    public override DmlWrapper run(List<SObject> newSObjects, List<SObject> oldSObjects,
        TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult) {

        HouseholdsApp householdsApp = new HouseholdsApp();
        Contacts contacts;
        DmlWrapper dmlWrapper = new DmlWrapper();

        switch on triggerAction {
            when BeforeInsert {
                contacts = new Contacts(newSObjects);
                householdsApp.onBeforeInsertOf(contacts);
            }
            when AfterInsert {
                contacts = new Contacts(newSObjects, oldSObjects);
                householdsApp.onAfterInsertOf(contacts, dmlWrapper);
            }
            when BeforeUpdate {
                contacts = new Contacts(newSObjects, oldSObjects);
                householdsApp.onBeforeUpdateOf(contacts);
            }
            when AfterUpdate {
                contacts = new Contacts(newSObjects, oldSObjects);
                householdsApp.onAfterUpdateOf(contacts, dmlWrapper);
            }
            when AfterDelete {
                contacts = new Contacts(oldSObjects);
                householdsApp.onAfterDeleteOf(contacts, dmlWrapper);
            }
            when AfterUndelete {
                contacts = new Contacts(newSObjects, oldSObjects);
                householdsApp.onAfterUndeleteOf(contacts, dmlWrapper);
            }
        }
        return dmlWrapper;
    }

}