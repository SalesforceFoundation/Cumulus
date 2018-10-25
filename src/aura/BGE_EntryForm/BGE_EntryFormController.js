({
    doInit: function(component) {
        //get all required fields for easy-access validity check
        var requiredFields = [];
        var allFields = component.get("v.dataImportFields");

        allFields.forEach(function(field) {
           if (field.required) {
               requiredFields.push(field.name);
           }
        });

        component.set("v.requiredFields", requiredFields);
    },
    /**
     * @description: called during render to place the focus at the start of the form
     */
    callFocus: function(component){
        component.find('donorType').focus();
    },

    /**
     * @description: alerts parent component that form needs to be reset
     */
    cancelForm: function (component, event, helper) {
        helper.sendMessage('onCancel', '');
        component.destroy();
    },

    /**
     * @description: alerts parent component that form is loaded
     */
    onFormLoad: function (component, event, helper) {
        helper.sendMessage('hideFormSpinner', '');
    },

    /**
     * @description: alerts parent component that record is saved and needs to be reset
     */
    onSuccess: function (component, event, helper) {
        var message = {'recordId': event.getParams().response.id};
        helper.sendMessage('onSuccess', message);
        component.destroy();
    },

    /**
     * @description: override submit function in recordEditForm to handle backend fields and validation
     */
    onSubmit: function (component, event, helper) {
        debugger;
        event.preventDefault();
        var eventFields = helper.addHiddenFields(component, event);
        var validity = helper.validateFields(component, event);
        //component.find('recordEditForm').submit(eventFields);
        if (validity.isValid) {
            component.find('recordEditForm').submit(eventFields);
        } else if (validity.missingFields.length != 0) {
            helper.sendErrorToast(component, validity.missingFields);
        } else {
            //do nothing since data format errors display inline
        }
    },

    /**
     * @description: sets the donor type and alerts the parent. Used to circumvent the unhelpful labeling of Account1/Contact1.
     */
    setDonorType: function (component, event, helper) {
        var donorType = event.getSource().get('v.value');
        component.set('v.donorType', donorType);

        var message = {'donorType': donorType};
        helper.sendMessage('setDonorType', message);
    }

})