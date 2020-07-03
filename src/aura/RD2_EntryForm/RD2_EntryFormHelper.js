({
    /**
     * @description: Create the modal when initializing the component
     */
    handleShowModal: function (component, event, helper) {
        let recordId = component.get('v.recordId');
        let parentId;

        if (!recordId) {
            parentId = helper.getParentId();
            component.set('v.parentId', parentId);
        }

        $A.createComponent("c:rd2EntryForm", { parentId, recordId },
            function (content, status, error) {
                if (status === "SUCCESS") {
                    const modalBody = content;

                    let modalReference = component.find('overlayLib').showCustomModal({
                        body: modalBody,
                        cssClass: component.getName() + ' slds-modal_medium custom-modal',
                        showCloseButton: true,
                        closeCallback: function () {
                            helper.redirectToPage(component);
                        }
                    });
                    component.set('v.modal', modalReference);
                } else {
                    console.error(JSON.stringify(error));
                }
            });
    },

    /**
    * @description Handle events sent from the modal
    */
    handleModalEvent: function (component, event) {
        component.set('v.recordId', event.getParams('detail').recordId);
        this.redirectToPage(component);
    },

    /**
     * @description: Redirect the page to either parent or RD record
     */
    redirectToPage: function (component) {
        component.get('v.modal').then(modal => {
            modal.close();
        });
        let navigateToId = component.get('v.parentId') || component.get('v.recordId');

        let navEvt = this.constructNavigationEvent(navigateToId);

        navEvt.fire();
    },

    /**
     * @description: Determine where the page should be redirect and construct the event
     */
    constructNavigationEvent: function (navigateToId) {
        let navEvt;

        if (navigateToId) {
            navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                "recordId": navigateToId,
                "slideDevName": "related"
            });

        } else {
            navEvt = $A.get("e.force:navigateToObjectHome");
            navEvt.setParams({
                "scope": "npe03__Recurring_Donation__c"
            });
        }

        return navEvt;
    },

    /**
    * @description: Extract and decode the Base64 component fragment from the URL to get the parent Id.
    * If the target fragment is not found, return a blank string or null.
    * @variable syntax A hardcoded text that is present in the URL when clicking 'New' button from Related List
    * @variable regex This regex expression targets the specific base64 encoded parameter in the URL.
    * @variable encodedParameters Extract out the target base64 encoded fragment. The regex should return 3 parts of parameters
    *   (with syntax, with '=1.', and pure base64 encoded fragment). The third part is the pure based64 encoded fragment
    * @variable decodedFragment Replace any '+' sign since it's replaced from space in URL
    *   and using the standard decodeURIComponent() function to decode the component
    * @return ParentId using wubdiw.atob() to convert the base64 string.
    * 
    */
    getParentId: function () {
        try {
            let syntax = 'inContextOfRef';
            syntax = syntax.replace(/[\[\]]/g, "\\$&");
            var url = window.location.href;
            var regex = new RegExp("[?&]" + syntax + "(=1\.([^&#]*)|&|#|$)");
            var encodedParameters = regex.exec(url);

            if (!encodedParameters) {
                return null;
            } else if (!encodedParameters[2]) {
                return '';
            }

            const decodedFragment = decodeURIComponent(encodedParameters[2].replace(/\+/g, " "));
            return JSON.parse(window.atob(decodedFragment)).attributes.recordId;

        } catch (error) {
            console.error(JSON.stringify(error));
        }
    }
})