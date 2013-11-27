/**
 * @TODO: this trigger can be deleted. We were just using it to test the alternative TDTM designs. 
 */
trigger CMP_Campaigns on Campaign (after delete, after insert, after undelete, 
after update, before delete, before insert, before update) {
    
    if(Trigger.new[0].Name.startsWith('ObjectTest')) { //Use object
        System.debug('****Using object');
        run(new TDTM_ObjectDataGateway());
    } else if(Trigger.new[0].Name.startsWith('CustomSettingTest')) { //Use custom settings
        System.debug('****Using custom settings');
        run(new TDTM_SettingsDataGateway());
    }
    
    private void run(TDTM_iTableDataGateway dao) {
    	TDTM_TriggerHandler handler = new TDTM_TriggerHandler();
    	
    	handler.initialize(Trigger.isBefore, Trigger.isAfter, Trigger.isInsert, 
    	                               Trigger.isUpdate, Trigger.isDelete, Trigger.isUnDelete, Trigger.new, Trigger.old, 
	                                   Schema.Sobjecttype.Campaign);
	    handler.runClasses(dao);
    }
}