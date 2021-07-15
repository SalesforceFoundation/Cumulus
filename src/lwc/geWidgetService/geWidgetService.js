import { getLikeMatchByKey } from 'c/utilCommon';
import {
    ALLOCATION_WIDGET_DEVELOPER_NAME_STUBS,
    SOFT_CREDIT_WIDGET_DEVELOPER_NAME_STUBS,
    TOKENIZE_CARD_WIDGET_NAME_STUBS
} from './widgetStubs';
import GeLabelService from 'c/geLabelService';

class GeWidgetService {
    objectMappingByDevName = null;
    fieldMappingByDevName = null;

    /*******************************************************************************
    * @description Initializes the GeWidgetService component with the migrated
    * object and field mappings.
    */
    init(objectMappingByDevName, fieldMappingByDevName) {
        this.objectMappingByDevName = objectMappingByDevName;
        this.fieldMappingByDevName = fieldMappingByDevName;
    }

    /*******************************************************************************
    * @description Getter all widget definitions
    * (org specific object and field mapping developer names)
    */
    get definitions() {
        return {
            geFormWidgetAllocation: {
                DeveloperName: 'geFormWidgetAllocation',
                MasterLabel: GeLabelService.CUSTOM_LABELS.commonGauAllocations,
                Target_Object_Mapping_Dev_Name: 'Widgets',
                Target_Field_Label: GeLabelService.CUSTOM_LABELS.commonGauAllocations,
                Required: 'No',
                Element_Type: 'widget',
                ...this.getMappingDeveloperNames(
                    ALLOCATION_WIDGET_DEVELOPER_NAME_STUBS.objectMappingDeveloperNameStubs,
                    ALLOCATION_WIDGET_DEVELOPER_NAME_STUBS.fieldMappingDeveloperNameStubs)
            },
            geFormWidgetSoftCredit: {
                DeveloperName: 'geFormWidgetSoftCredit',
                MasterLabel: GeLabelService.CUSTOM_LABELS.commonSoftCredits,
                Target_Object_Mapping_Dev_Name: 'Widgets',
                Target_Field_Label: GeLabelService.CUSTOM_LABELS.commonSoftCredits,
                Required: 'No',
                Element_Type: 'widget',
                ...this.getMappingDeveloperNames(
                    SOFT_CREDIT_WIDGET_DEVELOPER_NAME_STUBS.objectMappingDeveloperNameStubs,
                    SOFT_CREDIT_WIDGET_DEVELOPER_NAME_STUBS.fieldMappingDeveloperNameStubs)
            },            
            geFormWidgetTokenizeCard: {
                DeveloperName: 'geFormWidgetTokenizeCard',
                MasterLabel: GeLabelService.CUSTOM_LABELS.commonPaymentServices,
                Target_Object_Mapping_Dev_Name: 'Widgets',
                Target_Field_Label: GeLabelService.CUSTOM_LABELS.commonPaymentServices,
                Required: 'No',
                Element_Type: 'widget',
                ...this.getMappingDeveloperNames(
                    TOKENIZE_CARD_WIDGET_NAME_STUBS.objectMappingDeveloperNameStubs,
                    TOKENIZE_CARD_WIDGET_NAME_STUBS.fieldMappingDeveloperNameStubs)
            }
            //geFormWidgetSomethingElse: this.getMappingDeveloperNames...
        }
    }

    /*******************************************************************************
    * @description Method collects the org specific developer name for the given
    * mappings and stubs.
    *
    * @param {string} objectMappingDeveloperNameStub: Stub of an object mapping
    * developer name e.g. 'GAU_Allocation_1_'
    * @param {list} fieldMappingNameStubs: List of field mapping developer name
    * stub e.g. ['General_Account_1_', 'Percent_', ...]
    */
    getMappingDeveloperNames(objectMappingDeveloperNameStub, fieldMappingNameStubs) {
        const objectMappingDeveloperName = getLikeMatchByKey(
            this.objectMappingByDevName,
            objectMappingDeveloperNameStub,
            true);

        const fieldMappingDeveloperNames = fieldMappingNameStubs.map(stub => {
            return getLikeMatchByKey(this.fieldMappingByDevName, stub, true);
        });

        return {
            objectMappingDeveloperName,
            fieldMappingDeveloperNames
        }
    }
}

export default new GeWidgetService();