/*******************************************************************************
* @description Stubs of object and field mapping developer names. Used to collect
* the org specific mapping developer names for the widget geFormWidgetAllocation.
*/
const ALLOCATION_WIDGET_DEVELOPER_NAME_STUBS = {
    objectMappingDeveloperNameStubs: 'GAU_Allocation_1_',
    fieldMappingDeveloperNameStubs: [
        'GAU_Allocation_1_GAU_',
        'GAU_Allocation_1_Amount_',
        'GAU_Allocation_1_Percent_'
    ]
}

/*******************************************************************************
* @description Stubs of object and field mapping developer names. Used to collect
* the org specific mapping developer names for the widget geFormWidgetSoftCredits. 
*/
const SOFT_CREDIT_WIDGET_DEVELOPER_NAME_STUBS = {
    objectMappingDeveloperNameStubs: 'Opportunity_Contact_Role_1_',
    fieldMappingDeveloperNameStubs: [
        'Opportunity_Conct_Role_1_Role_',
        'Opportunity_ConRole_1_Contact_'
    ]
}

/*******************************************************************************
* @description Stubs of object and field mapping developer names. Used to collect
* the org specific mapping developer names for the widget geFormWidgetTokenizeCard.
* The tokenize card widget doesn't utilize an object mapping. This stub is just
* here to support the way we render widgets in the builder and form.
*/
const TOKENIZE_CARD_WIDGET_NAME_STUBS = {
    objectMappingDeveloperNameStubs: 'Tokenize_Card',
    fieldMappingDeveloperNameStubs: []
}

export {
    ALLOCATION_WIDGET_DEVELOPER_NAME_STUBS,
    SOFT_CREDIT_WIDGET_DEVELOPER_NAME_STUBS,
    TOKENIZE_CARD_WIDGET_NAME_STUBS
}