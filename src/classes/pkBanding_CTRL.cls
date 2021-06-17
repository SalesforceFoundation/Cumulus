public with sharing class pkBanding_CTRL {

    public transient String baseUrl {get;set;}

    public pkBanding_CTRL() {

        baseUrl = System.URL.getOrgDomainUrl().toExternalForm();

    }

    // action to clean NPSP and Org data
    public Pagereference cleanOrg() {
        
        // delete all records
//        delete [SELECT Id FROM npe03__Recurring_Donation__c LIMIT 1000];
//        delete [SELECT Id FROM Contact LIMIT 1000];
//        delete [SELECT Id FROM Account LIMIT 1000];
        delete [select id from opportunity LIMIT 5000];
        
        // refresh page
        PageReference reLoadPage = ApexPages.currentPage();
        reLoadPage.setRedirect(true);
        return reLoadPage;

    }

}

