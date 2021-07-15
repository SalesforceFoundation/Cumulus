import getFieldMappingSet from '@salesforce/apex/BDI_MappingServiceAdvanced.getFieldMappingSet';
import { handleError } from 'c/utilTemplateBuilder';
import { mutable } from 'c/utilCommon';
import GeWidgetService from 'c/geWidgetService';
import labelGeHeaderFieldBundles from '@salesforce/label/c.geHeaderFieldBundles';
import checkForElevateCustomer from '@salesforce/apex/GE_GiftEntryController.isElevateCustomer';

class GeTemplateBuilderService {
    fieldMappingByDevName = null;
    fieldMappingsByObjMappingDevName = null;
    objectMappingByDevName = null;
    isElevateCustomer = null;

    init = async (fieldMappingSetName, refresh) => {
        if (this.isElevateCustomer === null) {
            this.isElevateCustomer = await checkForElevateCustomer();
        }

        if (this.fieldMappingByDevName === null ||
            this.fieldMappingsByObjMappingDevName === null ||
            this.objectMappingByDevName === null ||
            refresh === true) {
            await this.handleGetFieldMappingSet(fieldMappingSetName);
        }
    }

    /*******************************************************************************
    * @description Method makes an imperative apex call and populates various
    * field and object maps using the class BDI_MappingServiceAdvanced.
    *
    * @param {string} fieldMappingSetName: Name of a Data_Import_Field_Mapping_Set__mdt
    * record.
    *
    * @return {object} promise: Promise from the imperative apex call
    * getFieldMappingSet.
    */
    handleGetFieldMappingSet = (fieldMappingSetName) => {
        return new Promise((resolve, reject) => {
            getFieldMappingSet({ fieldMappingSetName: fieldMappingSetName, includeUtilityFields: true })
                .then(data => {
                    // data is immutable after Promise resolution.  Since the
                    // addWidgetsPlaceholder adds properties to these objects, using
                    // mutable (JSON.parse/stringify) to store as new objects rather than
                    // pointing to the data props.
                    this.fieldMappingByDevName =
                        mutable(data.fieldMappingByDevName);
                    this.objectMappingByDevName =
                        mutable(data.objectMappingByDevName);
                    this.fieldMappingsByObjMappingDevName =
                        mutable(data.fieldMappingsByObjMappingDevName);

                    this.addWidgetsPlaceholder(this.fieldMappingByDevName,
                        this.objectMappingByDevName,
                        this.fieldMappingsByObjMappingDevName);

                    resolve(data);
                })
                .catch(error => {
                    handleError(error);
                    reject(error);
                });
        });
    }

    /*******************************************************************************
    * @description Method will strip off the NPSP prefix of a field or object
    * name and replace it with the passed in namespace if appropriate.
    *
    * @return {string} newName: String aligned with the passed in namespace
    */
    alignSchemaNSWithEnvironment = (name, namespace) => {
        if (namespace) {
            const namespacePrefix = `${namespace}__`;
            let newName = name.replace('npsp__', '');

            return newName.includes(namespacePrefix) ? newName : `${namespacePrefix}${newName}`;
        }

        return name;
    }

    /*******************************************************************************
    * @description Placeholder method for mocking widgets in the UI.
    *
    * @param {object} fieldMappingByDevName: Map of field mappings.
    * @param {object} objectMappingByDevName: Map of object mappings.
    */
    addWidgetsPlaceholder = (fieldMappingByDevName, objectMappingByDevName, fieldMappingsByObjMappingDevName) => {
        GeWidgetService.init(objectMappingByDevName, fieldMappingByDevName);

        fieldMappingByDevName.geFormWidgetAllocation =
            GeWidgetService.definitions.geFormWidgetAllocation;
        
        fieldMappingByDevName.geFormWidgetSoftCredit =
            GeWidgetService.definitions.geFormWidgetSoftCredit;

        objectMappingByDevName.Widgets = {
            DeveloperName: 'Widgets',
            MasterLabel: labelGeHeaderFieldBundles
        };

        fieldMappingsByObjMappingDevName.Widgets = [
            fieldMappingByDevName.geFormWidgetAllocation,
            fieldMappingByDevName.geFormWidgetSoftCredit
        ];

        // If the org is an Elevate customer, add the Salesforce.org Elevate widget
        if (this.isElevateCustomer) {
            fieldMappingByDevName.geFormWidgetTokenizeCard = GeWidgetService.definitions.geFormWidgetTokenizeCard;
            fieldMappingsByObjMappingDevName.Widgets.push(fieldMappingByDevName.geFormWidgetTokenizeCard);
        }
    }
}

export default new GeTemplateBuilderService();
