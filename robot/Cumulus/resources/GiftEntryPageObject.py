import time
import re
from cumulusci.robotframework.utils import capture_screenshot_on_error
from cumulusci.robotframework.pageobjects import BasePage
from cumulusci.robotframework.pageobjects import pageobject
from selenium.common.exceptions import ElementClickInterceptedException
from selenium.common.exceptions import ElementNotInteractableException
from BaseObjects import BaseNPSPPage
from NPSP import npsp_lex_locators
from logging import exception

OID_REGEX = r"^(%2F)?([a-zA-Z0-9]{15,18})$"

@pageobject("Landing", "GE_Gift_Entry")
class GiftEntryLandingPage(BaseNPSPPage, BasePage):


    def _go_to_page(self,default=None):
        """Go to Gift Entry page and waits for error msg if default=error
        otherwise waits until page contains batches table"""
        url_template = "{root}/lightning/n/{object}"
        name = self._object_name
        object_name = "{}{}".format(self.cumulusci.get_namespace_prefix("Nonprofit Success Pack"), name)
        url = url_template.format(root=self.cumulusci.org.lightning_base_url, object=object_name)
        self.selenium.go_to(url)
        self.salesforce.wait_until_loading_is_complete()
        if default=='error':
            self.selenium.wait_until_page_contains("Enable Advanced Mapping and Gift Entry")
        else:
            locator=npsp_lex_locators["gift_entry"]["id"].format("datatable Batches")
            self.selenium.wait_until_page_contains_element(locator,timeout=60,error="Gift Entry page with Batches table did not load in 1 min")

    def _is_current_page(self):
        """
        Verifies that current page is Gift Entry landing page
        """
        self.selenium.wait_until_location_contains("GE_Gift_Entry", timeout=60,
                                                   message="Current page is not Gift Entry landing page")
        locator=npsp_lex_locators["gift_entry"]["id"].format("datatable Batches")
        self.selenium.wait_until_page_contains_element(locator)


    def click_gift_entry_button(self,title):
        """clicks on Gift Entry button identified with title"""
        locator=npsp_lex_locators["gift_entry"]["button"].format(title)
        self.selenium.wait_until_page_contains_element(locator)
        self.selenium.scroll_element_into_view(locator)
        self.selenium.click_element(locator)

    def select_template_action(self,name,action):
        """From the template table, select template with name and select an action from the dropdown"""
        locator=npsp_lex_locators["gift_entry"]["actions_dropdown"].format(name)
        self.selenium.click_element(locator)
        element=self.selenium.get_webelement(locator)
        status=element.get_attribute("aria-expanded")
        if status=="false":
            self.selenium.wait_until_page_contains("Clone")
        self.selenium.click_link(action)
        if action=="Edit" or action=="Clone":
            self.selenium.wait_until_page_contains("Gift Entry Template Information",timeout=60)
        elif action=="Delete":
            self.selenium.wait_until_page_does_not_contain(name)

    def verify_template_is_not_available(self,template):
        """Verify that a gift template is not available for selection while creating a new batch"""
        field=npsp_lex_locators["adv_mappings"]["field_mapping"].format("Template")
        self.selenium.click_element(field)
        element=self.selenium.get_webelement(field)
        status=element.get_attribute("aria-activedescendant")
        if status is not None:
            self.selenium.page_should_not_contain(template)
        else:
            self.selenium.wait_until_page_contains("Default Gift Entry Template")
            self.selenium.page_should_not_contain(template)
        self.selenium.click_button("Cancel")

    def select_template(self,template):
        """selects the specified template while creating a new batch"""
        field=npsp_lex_locators["adv_mappings"]["field_mapping"].format("Template")
        self.selenium.wait_until_page_contains_element(field)
        self.selenium.click_element(field)
        self.selenium.wait_until_page_contains(template)
        self.npsp.click_span_button(template)
        self.selenium.click_button("Next")

    def get_template_record_id(self,template):
        """ Parses the current url to get the object id of the current record.
            Expects url format like: [a-zA-Z0-9]{15,18}
        """
        locator=npsp_lex_locators["link-text"].format(template)
        self.selenium.wait_until_page_contains_element(locator)
        element = self.selenium.get_webelement(locator)
        e=element.get_attribute("href")
        print(f"url is {e}")
        for part in e.split("="):
            oid_match = re.match(OID_REGEX, part)
            if oid_match is not None:
                return oid_match.group(2)
        raise AssertionError("Could not parse record id from url: {}".format(e))

    def store_template_record_id(self,template):
        """ Parses the template href to get the object id of the current record.
            Expects url format like: [a-zA-Z0-9]{15,18}
        """
        id=self.get_template_record_id(template)
        self.salesforce.store_session_record("Form_Template__c",id)


@pageobject("Template", "GE_Gift_Entry")
class GiftEntryTemplatePage(BaseNPSPPage, BasePage):


    def _is_current_page(self):
        """
        Verifies that current page is Template Builder edit page
        """
        self.selenium.wait_until_page_contains("Gift Entry Template Information")

    def enter_value_in_field(self,**kwargs):
        """Enter value in specified field"""
        for key,value in kwargs.items():
            if key=='Description':
                locator=npsp_lex_locators["gift_entry"]["field_input"].format(key,"textarea")
                self.selenium.wait_until_page_contains_element(locator)
                self.salesforce._populate_field(locator, value)
            else:
                locator=npsp_lex_locators["gift_entry"]["field_input"].format(key,"input")
                self.selenium.wait_until_page_contains_element(locator)
                self.salesforce._populate_field(locator, value)

    @capture_screenshot_on_error
    def perform_action_on_object_field(self,action,object_group,field):
        """If action is 'select' then selects the specified field under specified object group to add the field to gift entry form and verify field is added
        If action is 'unselect'then Unselects the specified field under specified object group to remove the field from gift entry template"""
        locator=npsp_lex_locators["gift_entry"]["form_object_dropdown"].format(object_group)
        self.salesforce._jsclick(locator)
        element=self.selenium.get_webelement(locator)
        status=element.get_attribute("aria-expanded")
        if status=="false":
            time.sleep(2)
        field_checkbox=npsp_lex_locators["gift_entry"]["object_field_checkbox"].format(object_group,field)
        check=self.selenium.get_webelement(field_checkbox)
        if action.lower()=='select':
            if not check.is_selected():
                try:
                    self.salesforce._jsclick(field_checkbox)
                except ElementClickInterceptedException:
                    self.selenium.execute_javascript("window.scrollBy(0,0)")
                    self.salesforce._jsclick(field_checkbox)
            label=": "+field
            self.selenium.wait_until_page_contains(label)
        elif action.lower()=='unselect':
            if check.is_selected():
                try:
                    self.salesforce._jsclick(field_checkbox)
                except ElementClickInterceptedException:
                    self.selenium.execute_javascript("window.scrollBy(0,0)")
                    self.salesforce._jsclick(field_checkbox)
            label=": "+field
            self.selenium.wait_until_page_does_not_contain(label)


    @capture_screenshot_on_error
    def verify_template_builder(self,check,field):
        """If check is 'contains'then verifies that template builder form contains the specified field
        If check is 'does not contain' then verifies that template builder form doesn't contain the field"""
        field_checkbox=npsp_lex_locators["gift_entry"]["field_input"].format(field,"input")
        self.selenium.wait_until_page_contains("Field Bundles")
        if check.lower()=='contains':
            self.selenium.page_should_contain_element(field_checkbox)
        elif check.lower()=='does not contain':
            self.selenium.page_should_not_contain_element(field_checkbox)

    @capture_screenshot_on_error
    def fill_template_form(self,**kwargs):
        """Add default values to template builder form fields or set fields as required.
        Key is field main label name and value is again another dictionary of field type and value
        ex: Payment: Payment Method is Main Label with Default Value as field type and ChecK is value"""
        self.selenium.execute_javascript("window.scrollBy(0,0)")
        for field,option in kwargs.items():
            for section,value in option.items():
                if section=="Required":
                    label=f'{section} {field}'
                    if value=='checked':
                        field_checkbox=npsp_lex_locators["gift_entry"]["field_input"].format(label,"input")
                        self.selenium.scroll_element_into_view(field_checkbox)
                        cb_loc=self.selenium.get_webelement(field_checkbox)
                        if not cb_loc.is_selected():
                            self.salesforce._jsclick(field_checkbox)
                    elif value=='unchecked':
                        field_checkbox=npsp_lex_locators["gift_entry"]["field_input"].format(label,"input")
                        self.selenium.scroll_element_into_view(field_checkbox)
                        cb_loc=self.selenium.get_webelement(field_checkbox)
                        if cb_loc.is_selected():
                            self.salesforce._jsclick(field_checkbox)
                elif section=="Default Value":
                    key=f'{section} {field}'
                    field_loc=npsp_lex_locators["gift_entry"]["field_input"].format(key,"input")
                    placeholder=self.selenium.get_webelement(field_loc).get_attribute("placeholder")
                    self.selenium.scroll_element_into_view(field_loc)
                    try:
                        self.selenium.click_element(field_loc)
                    except ElementClickInterceptedException:
                        self.selenium.execute_javascript("window.scrollBy(0,100)")
                        self.selenium.click_element(field_loc)
                    if placeholder=="Select an Option":
                        popup=npsp_lex_locators["flexipage-popup"]
                        self.selenium.wait_until_page_contains_element(popup)
                        option=npsp_lex_locators["span_button"].format(value)
                        self.selenium.click_element(option)
                    elif placeholder=="Search...":
                        self.salesforce.populate_lookup_field(key,value)
                    elif "Date" in field:
                        locator=npsp_lex_locators["bge"]["datepicker_open"].format("Date")
                        self.selenium.wait_until_page_contains_element(locator)
                        self.selenium.click_button(value)
                        self.selenium.wait_until_page_does_not_contain_element(locator,error="could not open datepicker")
                    else:
                        self.salesforce._populate_field(field_loc,value)
                elif section=="Field Label":
                    key=f'{section} {field}'
                    field_name=npsp_lex_locators["gift_entry"]["field_input"].format(key,"input")
                    self.selenium.input_text(field_name,value,clear=True)


    def add_field_bundle_to_section(self,bundle,section=None):
        """Adds the specified field bundle to the template builder form if not already added.
           If section is not specified then adds to the first section of the form,
           else creates a new section and adds to it"""
        label_text=bundle+' field bundle includes the following fields:'
        bundle_label=npsp_lex_locators["label"].format(label_text)
        new_section_bundle_label=npsp_lex_locators["gift_entry"]["new-section-field-bundle"].format(label_text)
        if section is not None:
            try:
                self.selenium.click_button("Add Section")
            except ElementClickInterceptedException:
                self.selenium.execute_javascript("window.scrollBy(0,100)")
                self.selenium.click_button("Add Section")
        checkbox=npsp_lex_locators["gift_entry"]["field_input"].format(bundle,"input")
        self.selenium.scroll_element_into_view(checkbox)
        cb_loc=self.selenium.get_webelement(checkbox)
        if not cb_loc.is_selected():
            try:
                self.salesforce._jsclick(checkbox)
            except ElementClickInterceptedException:
                self.selenium.execute_javascript("window.scrollBy(0,100)")
                self.salesforce._jsclick(checkbox)
        if section is not None:
            self.selenium.wait_until_page_contains_element(new_section_bundle_label)
        else:
            self.selenium.wait_until_page_contains_element(bundle_label)

    def add_batch_table_columns(self,*args):
        """Adds specified batch columns to the visible section if they are not already added"""
        first_element=True
        position=0
        for i in args:
            locator=npsp_lex_locators["gift_entry"]["duellist"].format("Available Fields",i)
            if self.npsp.check_if_element_exists(locator):
                if first_element:
                    self.selenium.click_element(locator)
                    first_element=False
                    position=args.index(i)
                else:
                    self.selenium.click_element(locator,'COMMAND')
        self.selenium.click_button("Move selection to Visible Fields")
        verify_field=npsp_lex_locators["gift_entry"]["duellist"].format("Available Fields",args[position])
        print (f'verify locator is {verify_field}')
        self.selenium.wait_until_page_does_not_contain_element(verify_field)


@pageobject("Form", "Gift Entry")
class GiftEntryFormPage(BaseNPSPPage, BasePage):

    def _is_current_page(self,title=None):
        """Verifies that current page is Gift Entry form page by making sure page contains given title if mentioned,
        if not then title as Donor Information"""
        if title is not None:
            self.selenium.wait_until_page_contains(title)
        else:
            self.selenium.wait_until_page_contains("Donor Information")

    def verify_field_default_value(self,**kwargs):
        """verifies that the field contains given default value
        where key=field name and value=default value"""
        for key,value in kwargs.items():
            locator=npsp_lex_locators["gift_entry"]["id"].format(key)
            type=self.selenium.get_element_attribute(locator,"data-qa-locator")
            if 'textarea' in type :
                field=npsp_lex_locators["gift_entry"]["field_input"].format(key,"textarea")
            else:
                field=npsp_lex_locators["gift_entry"]["field_input"].format(key,"input")
            self.selenium.wait_until_page_contains_element(field)
            time.sleep(1)
            element=self.selenium.get_webelement(field)
            default_value=element.get_attribute("value")
            assert value == default_value, f"Expected {key} default value to be {value} but found {default_value}"

    def fill_gift_entry_form(self,**kwargs):
        """Fill the gift entry form fields with specified values.
        Key is field name and value is value to be entered for field """
        for key,value in kwargs.items():
            locator=npsp_lex_locators["gift_entry"]["id"].format(key)
            self.selenium.wait_until_page_contains_element(locator)
            type=self.selenium.get_element_attribute(locator,"data-qa-locator")
            field_locator=npsp_lex_locators["gift_entry"]["field_input"].format(key,"input")
            print(f"type is {type}")
            if 'input autocomplete' in type :
                self.salesforce._populate_field(locator,value)
                value_locator=npsp_lex_locators["gift_entry"]["id"].format("Select "+value)
                self.selenium.wait_until_page_contains_element(value_locator)
                self.selenium.scroll_element_into_view(value_locator)
                self.selenium.click_element(value_locator)
            elif type.startswith("autocomplete"):
                self.salesforce._populate_field(field_locator,value)
                option=npsp_lex_locators["gift_entry"]["lookup-option"].format(value)
                self.selenium.wait_until_page_contains_element(option)
                try:
                    self.selenium.click_element(option)
                except ElementNotInteractableException:
                    self.salesforce._jsclick(option)
            elif 'combobox' in type :
                self.selenium.wait_until_page_contains_element(field_locator)
                self.selenium.click_element(field_locator)
                popup=npsp_lex_locators["flexipage-popup"]
                self.selenium.wait_until_page_contains_element(popup)
                option=npsp_lex_locators["span_button"].format(value)
                self.selenium.click_element(option)
            elif 'textarea' in type :
                field_locator=npsp_lex_locators["gift_entry"]["field_input"].format(key,"textarea")
                self.selenium.scroll_element_into_view(field_locator)
                self.salesforce._populate_field(field_locator,value)
            elif 'datetime' in type :
                locator=npsp_lex_locators["bge"]["datepicker_open"].format("Date")
                self.selenium.click_element(field_locator)
                self.selenium.wait_until_page_contains_element(locator)
                self.selenium.click_button(value)
                self.selenium.wait_until_page_does_not_contain_element(locator,error="could not open datepicker")
            else:
                self.selenium.scroll_element_into_view(field_locator)
                self.salesforce._populate_field(field_locator,value)

    def verify_error_for_field(self,**kwargs):
        """Verify that the given field contains specified error message
        Key should be field name and value should be the error message expected for field"""
        for key,value in kwargs.items():
            locator=npsp_lex_locators["gift_entry"]["field_alert"].format(key,value)
            self.selenium.wait_until_page_contains_element(locator)

    def verify_gift_count(self,count):
        """Verify that the no. of gifts on the page match with count"""
        locator=npsp_lex_locators["gift_entry"]["count"].format("Count of Gifts",count)
        self.selenium.wait_until_page_contains_element(locator)

    def click_field_value_link(self,field_name):
        """clicks on the link present in the given field"""
        value=self.npsp.return_locator_value("bge.value",field_name)
        self.npsp.click_link_with_text(value)

    def verify_table_field_values(self,name,byname=None,**kwargs):
        """Verifies that table has given field name with value.
        Arguments are: name which could be table name or a specific contact name, byname to search by contact name,
        fieldname=fieldvalue
        if the validation is to ensure the value exists in the table
        Eg: |Verify Table Field Values  |  Batch Gifts  |  Opportunity Amount=$150.00  |
        If the validation is to ensure the value specified exists for a specific contact in the table
        Eg: |Verify Table Field Values  |  John Doe  | True | Opportunity Amount=$150.00  |
        """
        if byname == "True":
            for field,value in kwargs.items():
                locator=npsp_lex_locators["gift_entry"]["datatable_field_by_name"].format(name,field,value)
            self.selenium.wait_until_page_contains_element(locator,timeout=60,error=f'{field} does not contain {value} for row with {name}')
        else:
            for field,value in kwargs.items():
                locator=npsp_lex_locators["gift_entry"]["table"].format(name,field,value)
            self.selenium.wait_until_page_contains_element(locator,timeout=60,error=f'{field} does not contain {value} in {name} table')

    def perform_action_on_datatable_row(self,name,action):
        """Select the specific gift entry data row based on the name parameter and
        selects the action from the dropdown menu.
        Eg: |Perform Action On Datatable Row  | ${contact2}[Name]     |     Delete
        """
        locator=npsp_lex_locators["gift_entry"]["datatable_options_icon"].format(name)
        self.selenium.wait_until_page_contains_element(locator)
        self.selenium.scroll_element_into_view(locator)
        self.selenium.click_element(locator)
        menuitem=npsp_lex_locators["gift_entry"]["datatable-menu-item"].format(action)
        self.selenium.wait_until_element_is_visible(menuitem,error= f"'{action}' is not displayed on the page")
        self.selenium.click_element(menuitem)
        self.builtin.sleep('2s',reason='to provide enough time for action to happen')

    def verify_link_status(self, **kwargs):
        """ Verify the link is disabled/enabled, pass the name of the link
        and the expected status of the link as either enabled or disabled
        Eg: |Verify Link Status  |  Update this Payment=enabled
             ...                    Update this Opportunity=disabled  |"""
        for key,value in kwargs.items():
            locator = npsp_lex_locators["button-with-text"].format(key)
            self.selenium.wait_until_element_is_visible(locator,error= f"'{key}' is not displayed on the page")
            if value=="disabled":
                actual_value = self.selenium.get_webelement(locator).get_attribute(value)
                if actual_value == None or actual_value == False:
                    raise Exception (f"Expected {key} status to be {value} but found {actual_value}")
            elif value=="enabled":
                actual_value = self.selenium.get_webelement(locator).get_attribute("disabled")
                if not (actual_value == None or actual_value == False):
                    raise Exception (f"Expected {key} status to be {value} but found {actual_value}")

    def validate_error_message(self,type,**kwargs):
        """Validates that page contains specified type of message.
        Example: Validate Error Message |error |Allocations Error=Test Error Message"""
        for key,value in kwargs.items():
            locator=npsp_lex_locators["gift_entry"]["alert"].format(type,key,value)
            self.selenium.wait_until_page_contains_element(locator)

    def verify_allocation_remaining_balance(self,amount):
        """Validates that the GAU allocation remaining balance is correct"""
        locator=npsp_lex_locators["gift_entry"]["element_text"].format("Remaining Allocation Amount",amount)
        self.selenium.wait_until_page_contains_element(locator,error=f'Remaining allocation amount of {amount} could not be found on page')
