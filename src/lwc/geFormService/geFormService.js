import getRenderWrapper from '@salesforce/apex/GE_TemplateBuilderCtrl.retrieveFormRenderWrapper';
import saveAndProcessGift from '@salesforce/apex/GE_FormRendererService.saveAndProcessSingleGift';
import saveAndDryRunRow from '@salesforce/apex/BGE_DataImportBatchEntry_CTRL.saveAndDryRunRow';

const inputTypeByDescribeType = {
    'BOOLEAN': 'checkbox',
    'CURRENCY': 'number',
    'DATE': 'date',
    'DATETIME': 'datetime-local',
    'EMAIL': 'email',
    'NUMBER': 'number',
    'PERCENT': 'number',
    'STRING': 'text',
    'PHONE': 'tel',
    'TEXT': 'text',
    'TIME': 'time',
    'URL': 'url'
};
//todo: add text area

const numberFormatterByDescribeType = {
  'PERCENT': 'percent-fixed'
};

// TODO: remove once we retrieve the template name from custom settings
const sgeTemplate = 'Single Gift Entry Template';

class GeFormService {

    fieldMappings;
    objectMappings;

    /**
     * Retrieve the default form render wrapper.
     * @returns {Promise<FORM_RenderWrapper>}
     */
    getFormTemplate() {
        return new Promise((resolve, reject) => {
            getRenderWrapper({templateName: sgeTemplate})
                .then((result) => {
                    this.fieldMappings = result.fieldMappingSetWrapper.fieldMappingByDevName;
                    this.objectMappings = result.fieldMappingSetWrapper.objectMappingByDevName;
                    resolve(result);
                })
                .catch(error => {
                    console.error(JSON.stringify(error));
                });
        });
    }

    /**
     * Get the type of lightning-input that should be used for a given field type.
     * @param dataType  Data type of the field
     * @returns {String}
     */
    getInputTypeFromDataType(dataType) {
        return inputTypeByDescribeType[dataType];
    }

    /**
     * Get the formatter for a lightning-input that should be used for a given field type
     * @param dataType  Data type of the field
     * @returns {String | undefined}
     */
    getNumberFormatterByDescribeType(dataType) {
        return numberFormatterByDescribeType[dataType];
    }

    /**
     * Get a field info object by dev name from the render wrapper object
     * @param fieldDevName  Dev name of the object to retrieve
     * @returns {BDI_FieldMapping}
     */
    getFieldMappingWrapper(fieldDevName) {
        return this.fieldMappings[fieldDevName];
    }

    /**
     * Get a object info object by dev name from the render wrapper object
     * @param objectDevName
     * @returns {BDI_ObjectMapping}
     */
    getObjectMappingWrapper(objectDevName) {
        return this.objectMappings[objectDevName];
    }

    /**
     * Takes a Data Import record, processes it, and returns the new Opportunity created from it.
     * @returns {Promise<Id>}
     */
    createOpportunityFromDataImport(createdDIRecord) {
        return new Promise((resolve, reject) => {
            saveAndProcessGift({diRecord: createdDIRecord})
                .then((result) => {
                    resolve(result);
                })
                .catch(error => {
                    console.error(JSON.stringify(error));
                });
        });
    }

    /**
     * Takes a list of sections, reads the fields and values, creates a di record, and creates an opportunity from the di record
     * @param sectionList
     * @returns opportunityId
     */
    handleSave(sectionList) {
        let diRecord = this.getDataImportRecord(sectionList);
        const opportunityID = this.createOpportunityFromDataImport(diRecord);
        return opportunityID;
    }

    saveAndDryRun(batchId, dataImport) {
        return new Promise((resolve, reject) => {
            saveAndDryRunRow({batchId: batchId, dataImport: dataImport})
                .then((result) => {
                    resolve(JSON.parse(result));
                })
                .catch(error => {
                    reject(error);
                });
        });
    }

    getDataImportRecord(sectionList){
        // Gather all the data from the input
        let fieldData = {};

        sectionList.forEach(section => {
            fieldData = { ...fieldData, ...(section.values)};
        });

        // Build the DI Record
        let diRecord = {};

        for (let key in fieldData) {
            if (fieldData.hasOwnProperty(key)) {
                let value = fieldData[key];

                // Get the field mapping wrapper with the CMT record name (this is the key variable). 
                let fieldWrapper = this.getFieldMappingWrapper(key);

                diRecord[fieldWrapper.Source_Field_API_Name] = value;
            }
        }
        diRecord.Donation_Donor__c = 'Account1'; //temporary to allow save of the form
        diRecord.Account1Imported__c = '0018A00000L8yYtQAJ'; //temporary to allow save of the form
        return diRecord;
    }

    buildColumns(sections) {
        const columns = [];
        sections.forEach(
            (section) => {
                console.log(JSON.parse(JSON.stringify(section)));
                section.elements.forEach(
                    element => {
                        const fmw = this.getFieldMappingWrapper(element.value);
                        const column = {
                            label: element.label,
                            fieldName: this.getFieldMappingWrapper(element.value).Source_Field_API_Name,
                            type: this.getInputTypeFromDataType(element.dataType)
                        };
                        columns.push(column);
                    }
                );
            }
        );
        return columns;
    }
}

const geFormServiceInstance = new GeFormService();

export default geFormServiceInstance;