import logging
import warnings
import json
import os
import time
import random
import string
from datetime import datetime
from datetime import timedelta


from robot.libraries.BuiltIn import RobotNotRunningError
from selenium.common.exceptions import ElementNotInteractableException
from selenium.common.exceptions import StaleElementReferenceException
from selenium.common.exceptions import NoSuchElementException
from selenium.common.exceptions import NoSuchWindowException
from selenium.common.exceptions import WebDriverException
from selenium.webdriver.common.keys import Keys
from SeleniumLibrary.errors import ElementNotFound
from simple_salesforce import SalesforceMalformedRequest
from simple_salesforce import SalesforceResourceNotFound
from selenium.webdriver import ActionChains
from cumulusci.robotframework.utils import selenium_retry
from cumulusci.robotframework.utils import capture_screenshot_on_error
from email.mime import text

from cumulusci.tasks.apex.anon import AnonymousApexTask
from cumulusci.core.config import TaskConfig
from cumulusci.tasks.apex.batch import BatchApexWait
from robot.api import logger
from cgi import escape

from tasks.salesforce_robot_library_base import SalesforceRobotLibraryBase
from BaseObjects import BaseNPSPPage

from locators_48 import npsp_lex_locators as locators_48
from locators_47 import npsp_lex_locators as locators_47
locators_by_api_version = {
    48.0: locators_48,   # spring '20
    47.0: locators_47,   # winter '20
}
# will get populated in _init_locators
npsp_lex_locators = {}

@selenium_retry
class NPSP(BaseNPSPPage,SalesforceRobotLibraryBase):
    
    ROBOT_LIBRARY_SCOPE = 'GLOBAL'
    ROBOT_LIBRARY_VERSION = 1.0

    def __init__(self, debug=False):
        self.debug = debug
        self.current_page = None
        self._session_records = []
        self.val=0
        self.payment_list= []
        # Turn off info logging of all http requests 
        logging.getLogger('requests.packages.urllib3.connectionpool').setLevel(logging.WARN)
        self._init_locators()

    def _init_locators(self):
        try:
            client = self.cumulusci.tooling
            response = client._call_salesforce(
                'GET', 'https://{}/services/data'.format(client.sf_instance))
            self.latest_api_version = float(response.json()[-1]['version'])
            if not self.latest_api_version in locators_by_api_version:
                warnings.warn("Could not find locator library for API %d" % self.latest_api_version)
                self.latest_api_version = max(locators_by_api_version.keys())
        except RobotNotRunningError:
            # We aren't part of a running test, likely because we are
            # generating keyword documentation. If that's the case, assume
            # the latest supported version
            self.latest_api_version = max(locators_by_api_version.keys())
        locators = locators_by_api_version[self.latest_api_version]
        npsp_lex_locators.update(locators)

    def get_namespace_prefix(self, name):
        parts = name.split('__')
        if parts[-1] == 'c':
            parts = parts[:-1]
        if len(parts) > 1:
            return parts[0] + '__'
        else:
            return ''

    def get_npsp_namespace_prefix(self):
        if not hasattr(self.cumulusci, '_describe_result'):
            self.cumulusci._describe_result = self.cumulusci.sf.describe()
        objects = self.cumulusci._describe_result['sobjects']
        level_object = [o for o in objects if o['label'] == 'Level'][0]
        return self.get_namespace_prefix(level_object['name'])

    
    def populate_campaign(self,loc,value):
        """This is a temporary keyword added to address difference in behaviour between summer19 and winter20 release"""
        self.search_field_by_value(loc, value)
        print(self.latest_api_version)       
        self.selenium.click_link(value)
            

    def click_record_button(self, title):
        """ Pass title of the button to click the buttons on the records edit page. Usually save and cancel are the buttons seen.
        """
        locator = npsp_lex_locators['record']['button'].format(title)
        self.selenium.set_focus_to_element(locator)
        button = self.selenium.get_webelement(locator)
        button.click()
        time.sleep(5)
    
    @capture_screenshot_on_error    
    def select_tab(self, title):
        """ Switch between different tabs on a record page like Related, Details, News, Activity and Chatter
            Pass title of the tab
        """
        tab_found = False
        locators = npsp_lex_locators["tabs"].values()
        for i in locators:
            locator = i.format(title)
            if self.check_if_element_exists(locator):
                print(locator)
                buttons = self.selenium.get_webelements(locator)
                for button in buttons:
                    print(button)
                    if button.is_displayed():
                        print("button displayed is {}".format(button))
                        self.salesforce._focus(button)
                        button.click()
                        time.sleep(5)
                        tab_found = True
                        break

        assert tab_found, "tab not found"    
        
    def click_special_related_list_button(self, heading, button_title):
        """ To Click on a related list button which would open up a new lightning page rather than a modal.
            Pass the list name and button name"""
        self.salesforce.load_related_list(heading)
        b_found = False
        locator = npsp_lex_locators["record"]["related"]["button"].format(
            heading, button_title
        )
        buttons = self.selenium.driver.find_elements_by_xpath(locator)
        for button in buttons:
            if button.is_displayed():
                self.selenium.driver.execute_script('arguments[0].click()', button)
                b_found = True
                break
            
        assert b_found, "{} related list with button {} not found.".format(heading, button_title)
     
    @capture_screenshot_on_error              
    def click_related_list_dd_button(self, heading, dd_title, button_title):
        """ To Click on a related list dropdown button.
            Pass the list name, dd name and button name"""
        self.salesforce.load_related_list(heading)
        locator = npsp_lex_locators["record"]["related"]["button"].format(heading, dd_title)
        element = self.selenium.driver.find_element_by_xpath(locator)
        self.selenium.driver.execute_script('arguments[0].click()', element) 
        time.sleep(1)
        loc=npsp_lex_locators["record"]["related"]["dd-link"].format(button_title)
        self.selenium.wait_until_element_is_visible(loc)
        element = self.selenium.driver.find_element_by_xpath(loc)
        self.selenium.driver.execute_script('arguments[0].click()', element)
           
        
    @capture_screenshot_on_error
    def click_flexipage_dropdown(self, title,value):
        """Click the lightning dropdown to open it and select value"""
        locator = npsp_lex_locators['record']['flexipage-list'].format(title)
        self.selenium.wait_until_page_contains_element(locator)
        self.selenium.get_webelement(locator).click()
        self.wait_for_locator('flexipage-popup')
        option=npsp_lex_locators['span'].format(value)
        self.selenium.click_element(option)   

    def open_date_picker(self, title):
        locator = npsp_lex_locators['record']['list'].format(title)
        self.selenium.set_focus_to_element(locator)
        self.selenium.get_webelement(locator).click()

    def pick_date(self, value):
        """To pick a date from the date picker"""
        locator = npsp_lex_locators['record']['datepicker'].format(value)
        self.selenium.set_focus_to_element(locator)
        self.selenium.get_webelement(locator).click() 

    def change_month(self, value):    
        """To pick month in the date picker"""
        locator = npsp_lex_locators['record']['month_pick'].format(value)
        self.selenium.set_focus_to_element(locator)
        self.selenium.get_webelement(locator).click()
        
#     def select_row(self,value):
#         """To select a row on object page based on name and open the dropdown"""    
#         drop_down = npsp_lex_locators['locating_delete_dropdown'].format(value)
#         self.selenium.get_webelement(drop_down).click()
#         #self.selenium.get_webelement(drop_down).click()

#     def select_row(self,value):
#         """To select a row on object page based on name and open the dropdown"""    
#         locator = npsp_lex_locators['select_name'].format(value)
#         self.selenium.set_focus_to_element(locator)
#         drop_down = npsp_lex_locators['locating_delete_dropdown'].format(value)
#         time.sleep(1)
#         return drop_down

    def select_row(self, value):
        """To select a row on object page based on name and open the dropdown"""
        locators = npsp_lex_locators['name']
        list_ele = self.selenium.get_webelements(locators)
        for index, element in enumerate(list_ele):
            if element.text == value:
                drop_down = npsp_lex_locators['locate_dropdown'].format(index + 1)
                self.selenium.get_webelement(drop_down).click()
                self.selenium.wait_until_page_contains("Delete")

    def select_related_row(self, value):
        """To select a row on object page based on name and open the dropdown"""
        locators = npsp_lex_locators['related_name']
        list_ele = self.selenium.get_webelements(locators)
        for index, element in enumerate(list_ele):
            if element.text == value:
                drop_down = npsp_lex_locators['rel_loc_dd'].format(index + 1)
                self.selenium.get_webelement(drop_down).click()
                time.sleep(1)

#     def select_row(self, value ):
#         """To select a row on object page based on name and open the dropdown"""
#         locators = npsp_lex_locators['name']
#         list_ele = self.selenium.get_webelements(locators)
#         index= 1
#         for locator in list_ele:
#             global index
#             if locator.text != value:
#                 index = index+1
#             else:
#                 drop_down = npsp_lex_locators['locate_dropdown'].format(index)
#                 self.selenium.get_webelement(drop_down).click()
#                 self.selenium.get_webelement(drop_down).click()
            
#     def select_related_row(self, value ):
#         """To select row from a related list based on name and open the dropdown"""
#         locators = npsp_lex_locators['related_name']
#         list_ele = self.selenium.get_webelements(locators)
#         index= 1
#         for locator in list_ele:
#             global index
#             if locator.text != value:
#                 index = index+1
#             else:
#                 drop_down = npsp_lex_locators['rel_loc_dd'].format(index)
#                 self.selenium.get_webelement(drop_down).click()
#                 self.selenium.get_webelement(drop_down).click()      
                


    def click_id(self, title):  
        locator=npsp_lex_locators['aff_id'].format(title)
        self.selenium.get_webelement(locator).click()     
         
    def select_object_dropdown(self): 
        locator=npsp_lex_locators['object_dd']
        self.selenium.get_webelement(locator).click()   
        
    def check_status(self, acc_name):
        aff_list = npsp_lex_locators['aff_status'].format(acc_name)
        aff_list_text=self.selenium.get_webelement(aff_list).text 
        self.aff_id=npsp_lex_locators['aff_id'].format(acc_name)
        self.aff_id_text=self.selenium.get_webelement(self.aff_id).text
        return self.aff_id_text,aff_list_text     
            
            
    def get_id(self):
        locator=npsp_lex_locators['click_aff_id'].format(self.aff_id_text)
        self.selenium.get_webelement(locator).click()   
        
#     @capture_screenshot_on_error    
#     def navigate_to_and_validate_field_value(self, field,status,value,section=None):
#         """If status is 'contains' then the specified value should be present in the field
#                         'does not contain' then the specified value should not be present in the field
#         """
#         if section is not None:
#             section="text:"+section
#             self.selenium.scroll_element_into_view(section)
#         list_found = False
#         locators = npsp_lex_locators["confirm"].values()
#         for i in locators:
#             locator = i.format(field,value)
#             if self.check_if_element_exists(locator): 
#                 print(f"element exists {locator}")  
#                 actual_value=self.selenium.get_webelement(locator).text
#                 print(f"actual value is {actual_value}")
#                 if status == "contains":
#                     assert value == actual_value, "Expected value to be {} but found {}".format(value, actual_value)
#                 elif status == "does not contain":
#                     assert value != actual_value, "Expected value {} and actual value {} should not match".format(value, actual_value)   
#                 list_found = True
#                 break
#  
#         assert list_found, "locator not found"
    @selenium_retry
    @capture_screenshot_on_error
    def navigate_to_and_validate_field_value(self, field,status,value,section=None):
        """If status is 'contains' then the specified value should be present in the field
                        'does not contain' then the specified value should not be present in the field
        """
        if section is not None:
            section="text:"+section
            self.selenium.scroll_element_into_view(section)
        list_found = False
        locators = npsp_lex_locators["confirm"].values()
        if status == "contains":
            for i in locators:
                print("inside for loop")
                locator = i.format(field,value)
                if self.check_if_element_exists(locator):
                    print(f"element exists {locator}")
                    actual_value=self.selenium.get_webelement(locator).text
                    print(f"actual value is {actual_value}")
                    assert value == actual_value, "Expected {} value to be {} but found {}".format(field,value, actual_value)
                    list_found=True
                    break
        if status == "does not contain":
            for i in locators:
                locator = i.format(field,value)
                if self.check_if_element_exists(locator):
                    print(f"locator is {locator}")
                    raise Exception(f"{field} should not contain value {value}")
            list_found = True    
 
        assert list_found, "locator not found" 
    @capture_screenshot_on_error
    def verify_record(self, name):
        """ Checks for the record in the object page and returns true if found else returns false
        """
        locator=npsp_lex_locators['account_list'].format(name)
        self.selenium.wait_until_page_contains_element(locator, error="could not find "+name+" on the page")

            
    def select_option(self, name):  
        """selects various options in Contact>New opportunity page using name
        """
        locator=npsp_lex_locators['dd_options'].format(name)
        self.selenium.get_webelement(locator).click()
        
    def verify_related_list_items(self,list_name,value):
        """Verifies a specified related list has specified value(doesn't work if the list is in table format)"""
        self.salesforce.load_related_list(list_name)
        locator=npsp_lex_locators['related_list_items'].format(list_name,value)
        self.selenium.page_should_contain_element(locator)
    
    def click_span_button(self,title):  
        """clicks on the button under span tag"""      
        locator=npsp_lex_locators['span_button'].format(title)
        self.selenium.get_webelement(locator).click()  
        
    def header_field_value(self,title,value):   
        """Validates if the specified header field has specified value"""   
        locator= npsp_lex_locators['header_field_value'].format(title,value)
        self.selenium.page_should_contain_element(locator)
        
    def verify_header(self,value):   
        """Validates header value"""   
        locator= npsp_lex_locators['header'].format(value)
        self.selenium.page_should_contain_element(locator)    
        
    def verify_related_list(self,list_name,status,name):   
        """If status is 'contains' then the specified related list should contain name
                        'does not contain' then the specified related list should not contain name"""
        locator = self.salesforce.get_locator('record.related.link', list_name, name)
        if status=="contains":
            self.selenium.page_should_contain_element(locator)
        elif status=="does not contain":
            self.selenium.page_should_not_contain_element(locator)
        
    def fill_address_form(self, **kwargs):
        """Validates if the affiliated contacts have the added contact details enter Y for positive case and N for negative case""" 
        for label, value in kwargs.items():
            locator= npsp_lex_locators['manage_hh_page']['address'].format(label,value)
            if label=="Street":
                locator = locator+"textarea"
                self.selenium.get_webelement(locator).send_keys(value)
            else:
                locator = locator+"input"
                self.selenium.get_webelement(locator).send_keys(value)
                
    def fill_bge_form(self, **kwargs):
        for label, value in kwargs.items():
            if label=="Batch Description" or label == "custom_textarea":
                locator= npsp_lex_locators['bge']['field-text'].format(label,value)
                self.selenium.click_element(locator)  
                self.salesforce._populate_field(locator, value)              

            else:
                locator= npsp_lex_locators['bge']['field-input'].format(label,value)
                self.selenium.click_element(locator)
                self.salesforce._populate_field(locator, value)
     
         
    def verify_address_details(self,field,value,**kwargs):
        """Validates if the details page address field has specified value
        Field is the The address type field we are trying to match to the Expected address Map that is sent through Kwargs"""

        locator= npsp_lex_locators['detail_page']['address'].format(field)
        street, city, country = self.selenium.get_webelements(locator)

        status = None
        for key, value in kwargs.items():
            if street.text == kwargs.get("street")  and  city.text == kwargs.get("city") and country.text == kwargs.get("country"):
                status = "pass"
            else:
                status = "fail"
        if value.lower() == "contains":
            assert status == "pass", "Expected address {} , {}, {} does not match".format(street.text,city.text,country.text)


    def validate_checkboxes(self,name,checkbox_title):
        """validates all 3 checkboxes for contact on manage hh page and returns locator for the checkbox thats required"""   
          
        locator=npsp_lex_locators['manage_hh_page']['mhh_checkbox'].format(name,"fauxCBInformal")
        self.selenium.page_should_contain_element(locator)
        
        locator=npsp_lex_locators['manage_hh_page']['mhh_checkbox'].format(name,"fauxCBFormal")
        self.selenium.page_should_contain_element(locator)
        
        locator=npsp_lex_locators['manage_hh_page']['mhh_checkbox'].format(name,"fauxCBExName") 
        self.selenium.page_should_contain_element(locator)
        
        if checkbox_title == "Informal Greeting":
            locator=npsp_lex_locators['manage_hh_page']['mhh_checkbox'].format(name,"fauxCBInformal")
        elif checkbox_title == "Formal Greeting":
            locator=npsp_lex_locators['manage_hh_page']['mhh_checkbox'].format(name,"fauxCBFormal") 
        elif checkbox_title.capitalize() == "Household Name":
            locator=npsp_lex_locators['manage_hh_page']['mhh_checkbox'].format(name,"fauxCBExName")       
        return locator
    
    def check_field_value(self, title, value):
        """checks value of a field in details page(section without header)"""
        fv_found=False
        locators = npsp_lex_locators['detail_page']["field-value"].values()

        for i in locators:
            locator = i.format(title,value)
            if self.check_if_element_exists(locator):
                self.selenium.page_should_contain_element(locator)
                fv_found = True
                break

        assert fv_found, "{} with {} not found".format(title,value)
        
    def click_managehh_button(self,title):  
        """clicks on the new contact button on manage hh page"""      
        locator=npsp_lex_locators['manage_hh_page']['button'].format(title)
        self.selenium.get_webelement(locator).click()  
        
    def click_managehh_link(self,title):       
        locator=npsp_lex_locators['manage_hh_page']['address_link'].format(title)
        self.selenium.get_webelement(locator).click()      
    
    def set_checkbutton_to(self,title,status):
        """If status is 'checked' then checks the box if its not already checked. Prints a warning msg if already checked
          'unchecked' then unchecks the box if its not already checked. Prints a warning msg if already unchecked
        """
        cb_found=False
        locators = npsp_lex_locators["checkbox"].values()

        for i in locators:
            locator = i.format(title)
            if self.check_if_element_exists(locator):
                checkbox=self.selenium.get_webelement(locator)
                if (status == 'checked' and checkbox.is_selected() == False) or (status == 'unchecked' and checkbox.is_selected() == True):
                    self.selenium.click_element(checkbox)
                else:
                    self.builtin.log("This checkbox is already in the expected status", "WARN")     
                cb_found = True
                break

        assert cb_found, "Checkbox not found"
        
    def select_bge_checkbox(self,title):
        locator=npsp_lex_locators['bge']['checkbox'].format(title)
        self.selenium.get_webelement(locator).click()     
        
    def populate_modal_field(self, title, value):
        locator=npsp_lex_locators['modal_field'].format(title,value)
        self.salesforce._populate_field(locator, value)
    
    def populate_field_with_id(self,id,value):
        locator=npsp_lex_locators['id'].format(id)
        if value == 'null':
            field = self.selenium.get_webelement(locator)
            self.salesforce._clear(field)
        else :    
            self.salesforce._populate_field(locator, value)

    @capture_screenshot_on_error
    def validate_related_record_count(self,title,value):

        self.select_tab("Related")
        self.salesforce.load_related_list(title)
        locator=npsp_lex_locators['record']['related']['check_occurrence'].format(title,value)
        actual_value=self.selenium.get_webelement(locator).text
        exp_value="("+value+")"
        assert exp_value == actual_value, "Expected value to be {} but found {}".format(
            exp_value, actual_value
        )  
        
    def verify_occurence(self,title,value):
        self.salesforce.load_related_list(title)
        time.sleep(1) 
        locator=npsp_lex_locators['record']['related']['check_occurrence'].format(title,value)
        actual_value=self.selenium.get_webelement(locator).text
        exp_value="("+value+")"
        assert exp_value == actual_value, "Expected value to be {} but found {}".format(
            exp_value, actual_value
        )
           
        
    def check_record_related_item(self,title,value):
        """Verifies that the given value is displayed under the related list identified by title on a record view page"""
        self.salesforce.load_related_list(title)
        locator=npsp_lex_locators['record']['related']['item'].format(title,value)
        self.selenium.wait_until_page_contains_element(locator)
        actual_value=self.selenium.get_webelement(locator).text
        assert value == actual_value, "Expected value to be {} but found {}".format(
            value, actual_value
        )      
          
     
    def select_related_dropdown(self,title):
        """Clicks on the dropdown next to Related List"""
        locator=npsp_lex_locators['record']['related']['drop-down'].format(title)
        self.selenium.get_webelement(locator).click()   
        
    def get_header_date_value(self,title):   
        """Validates if the specified header field has specified value"""   
        locator= npsp_lex_locators['header_datepicker'].format(title)
        date=self.selenium.get_webelement(locator).text   
        return date 
        
    def get_main_header(self):
        header_found = False
        locators = npsp_lex_locators["main-header"].values()

        for locator in locators:
            if self.check_if_element_exists(locator):
                header = self.selenium.get_webelement(locator).text
                header_found = True
                return header

        assert header_found, "Header with the provided locator not found"
    
    def verify_contact_role(self,name,role):
        """verifies the contact role on opportunity page"""
        locator=npsp_lex_locators['opportunity']['contact_role'].format(name,role)
        self.selenium.page_should_contain_element(locator)  
        
    def select_relatedlist(self,title):
        """click on the related list to open it"""
        locator=npsp_lex_locators['record']['related']['title'].format(title)
        element = self.selenium.driver.find_element_by_xpath(locator)
        self.selenium.driver.execute_script('arguments[0].click()', element)
 
        
    def verify_related_list_field_values(self, listname=None, **kwargs):
        """verifies the values in the related list objects page"""
        if listname is not None:
            self.selenium.wait_until_page_contains(listname)
            self.select_relatedlist(listname)
        for name, value in kwargs.items():
            locator= npsp_lex_locators['record']['related']['field_value'].format(name,value)
            self.selenium.wait_until_page_contains_element(locator,error="Could not find the "+ name +" with value " + value + " on the page")
            
    def verify_related_object_field_values(self, rel_object,**kwargs):
        """verifies the specified field,value pairs in the related object page (table format)""" 
        self.salesforce.load_related_list(rel_object)
        self.select_relatedlist(rel_object)
        for name, value in kwargs.items():
            locator= npsp_lex_locators['object']['field-value'].format(name,value)
            self.selenium.wait_until_page_contains_element(locator,error="Could not find the "+ name +" with value " + value + " on the page")
    
    
    def page_contains_record(self,title):   
        """Validates if the specified record is present on the page"""   
        locator= npsp_lex_locators['object']['record'].format(title)
        self.selenium.wait_until_page_does_not_contain_element(locator) 

    def click_special_object_button(self, title):
        """Clicks a button in an object's actions but doesn't wait for a model to open"""
        locator = npsp_lex_locators['object']['button'].format(title)
        self.selenium.wait_until_element_is_visible(locator,error="Button "+ title +" not found on the page")
        self.selenium.get_webelement(locator).click()



    def check_related_list_values(self,list_name,*args):
        """Verifies the value of custom related list"""
        self.salesforce.load_related_list(list_name)
        for value in args:
            locator = npsp_lex_locators['check_related_list_item'].format(list_name,value)
            self.selenium.page_should_contain_element(locator)

    def check_activity_tasks(self, *args):
        """verifies that the specified tasks are present under activity tab """
        for value in args:
            locator = npsp_lex_locators['engagement_plan']['tasks'].format(value)
            self.selenium.page_should_contain_element(locator)

    def select_app_launcher_link(self,title):
        locator = npsp_lex_locators['app_launcher']['select-option'].format(title) 
        self.selenium.get_webelement(locator).click()
        time.sleep(1)
        
    def click_on_first_record(self):  
        """selects first record of the page"""
        locator = npsp_lex_locators['select_one_record']
        self.selenium.get_webelement(locator).click()
        time.sleep(1)  
        
    def select_search(self, index, value):
        """"""
        locator = npsp_lex_locators["click_search"].format(index)
        loc_value = self.selenium.get_webelement(locator).send_keys(value)
        loc = self.selenium.get_webelement(locator)
        #loc.send_keys(Keys.TAB+ Keys.RETURN)
        time.sleep(1)  
        
    def enter_gau(self, value):
        id = "lksrch"
        locator = npsp_lex_locators["id"].format(id)
        loc = self.selenium.get_webelement(locator)
        loc.send_keys(value)
        self.selenium.get_webelement("//*[@title='Go!']").click()
        time.sleep(1)




    def click_save(self, page):
        if  page== "GAU":
            id="j_id0:theForm:j_id9:j_id10:saveBTN"
            locator = npsp_lex_locators["id"].format(id)
            self.selenium.get_webelement(locator).click()

    def enter_payment_schedule(self, *args):
        """Enter values into corresponding fields in Levels page"""
        #if name == "Payments":
        #id = ["paymentCount","intervals","intervalunits"]
        id = ["paymentCount","vfForm:intervalnumber","intervalunits"]
        for i in range(len(args)):
            locator = npsp_lex_locators['id'].format(id[i])
            loc = self.selenium.get_webelement(locator)
            self.selenium.set_focus_to_element(locator)
            self.selenium.select_from_list_by_label(loc,args[i])
            time.sleep(2)

    def verify_payment_split(self, amount, no_payments):
        #loc = "//input[@value= '{}']"
        input_loc = npsp_lex_locators['button']
        values = int(amount)/int(no_payments)
        values_1 = "{:0.2f}".format(values)
        self.val = str(values_1)
        input_field =  input_loc.format(self.val)
        list_payments = self.selenium.get_webelements(input_field)
        self.t_loc=len(list_payments)
        if  self.t_loc == int(no_payments):
            for i in list_payments:
                self.selenium.page_should_contain_element(i)
            return str(self.t_loc)
        else:
            return str(self.t_loc)

    def verify_date_split(self,date, no_payments, interval):
        ddate=[]
        mm, dd, yyyy = date.split("/")
        mm, dd, yyyy = int(mm), int(dd), int(yyyy)
        locator = npsp_lex_locators['payments']['date_loc'].format(date)
        t_dates = self.selenium.get_webelement(locator)
        self.selenium.page_should_contain_element(t_dates)
#            for i in range(int(no_payments) + 1):
        if mm <= 12:
            date_list = [mm, dd, yyyy]
            dates = list(map(str, date_list))
            new_date = "/".join(dates)
            mm = mm + int(interval)
            dates = list(map(str, date_list))
            #if new_date not in t_dates:
            date_locator = npsp_lex_locators['payments']['date_loc'].format(new_date)
            t_dates = self.selenium.get_webelement(date_locator)
            self.selenium.page_should_contain_element(t_dates)
        elif mm > 12:
            yyyy = yyyy + 1
            mm = (mm + int(interval))-(12+int(interval))
            #return "pass"
#         else:
#             return "fail"

    def click_viewall_related_list (self,title):  
        """clicks on the View All link under the Related List"""      
        locator=npsp_lex_locators['record']['related']['viewall'].format(title)
        element = self.selenium.driver.find_element_by_xpath(locator)
        self.selenium.driver.execute_script('arguments[0].click()', element)
        
    def click_button_with_value (self,title):  
        """clicks on the button on the payments page"""      
        locator=npsp_lex_locators['button'].format(title)
        self.selenium.get_webelement(locator).click()

    def verify_details(self, **kwargs):
       """To verify no. of records with given same column values
          key is value in a table column, value is expected count of rows with that value     
       """
       for key, value in kwargs.items():
           locators = npsp_lex_locators['payments']['pays'].format(key)
           list_ele = self.selenium.get_webelements(locators)
           p_count=len(list_ele)
           assert p_count == int(value), "Expected {} payment with status {} but found {}".format(value, key, p_count)  
           
           
    def verify_allocations(self,header, **kwargs):
       """To verify allocations, header is related list
          key is value in 1st td element, value is value in 2nd element     
       """
       self.salesforce.load_related_list(header)
       for key, value in kwargs.items():
           locator = npsp_lex_locators['record']['related']['allocations'].format(header,key,value)
           self.selenium.wait_until_page_contains_element(locator,error="Expected {} allocation of {} was not found".format(key,value))
#            ele = self.selenium.get_webelement(locator).text
#            assert ele == value, "Expected {} allocation to be {} but found {}".format(key,value,ele)                      
                
    def verify_occurrence_payments(self,title,value=None):
        """"""
        locator=npsp_lex_locators['payments']['check_occurrence'].format(title)
        occ_value=self.selenium.get_webelement(locator).text
        return occ_value        

    def verify_payment(self):
        locators=npsp_lex_locators['payments']['no_payments']
        list_ele=self.selenium.get_webelements(locators)
        l_no_payments = len(list_ele)
        #return list_ele
        #return l_no_payments, self.t_loc
        #if self.t_loc == l_no_payments:
        for element in list_ele:
            payment_com=self.selenium.get_webelement(element).text
            cc=payment_com.replace("$","")
            if cc == str(self.val) and self.t_loc == l_no_payments :
                return 'pass'
            #return cc, self.val
            else:
                return "fail"
        

        
    def select_value_from_bge_dd(self, list_name,value):
        list_found = False
        locators = npsp_lex_locators["bge-lists"].values()

        for i in locators:
            locator = i.format(list_name)
            if self.check_if_element_exists(locator):
                loc=self.selenium.get_webelement(locator)
                self.selenium.set_focus_to_element(locator)       
                self.selenium.select_from_list_by_label(loc,value)
                list_found = True
                break

        assert list_found, "Dropdown with the provided locator not found"

    def check_if_element_exists(self, xpath):
        elements =self.selenium.get_element_count(xpath)
        return True if elements > 0 else False
    
    def select_multiple_values_from_list(self,list_name,*args): 
        """Pass the list name and values to be selected from the dropdown. Please note that this doesn't unselect the existing values"""
        locator = npsp_lex_locators['npsp_settings']['multi_list'].format(list_name)
        loc = self.selenium.get_webelement(locator)
        self.selenium.set_focus_to_element(locator)       
        self.selenium.select_from_list_by_label(loc,*args) 
        
    def choose_frame(self, value):
        """Returns the first displayed iframe on the page with the given name or title"""
        locator = npsp_lex_locators['frame_new'].format(value,value)
        frames = self.selenium.get_webelements(locator)
        self.selenium.capture_page_screenshot()
        print(f'list of frames {frames}')
        for frame in frames:
            print(f'inside for loop for {frame}')
            self.selenium.capture_page_screenshot()
            if frame.is_displayed():
                try:
                    print("inside try")
                    self.selenium.select_frame(frame)
                except NoSuchWindowException:
                    print("inside except")
                    self.builtin.log("caught NoSuchWindowException;trying gain..","WARN")
                    time.sleep(.5)
                    self.selenium.select_frame(frame)
                return frame
        raise Exception('unable to find visible iframe with title "{}"'.format(value))

    @capture_screenshot_on_error
    def select_frame_and_click_element(self,iframe,path, *args, **kwargs):
        """Waits for the iframe and Selects the first displayed frame with given name or title and scrolls to element identified by locator and clicks """
        self.wait_for_locator('frame_new',iframe,iframe)
        self.choose_frame(iframe)
        loc = self.get_npsp_locator(path, *args, **kwargs)
        self.selenium.wait_until_element_is_visible(loc, timeout=60)
        self.selenium.scroll_element_into_view(loc)
        self.selenium.click_element(loc)

    def get_npsp_locator(self, path, *args, **kwargs):
        """ Returns a rendered locator string from the npsp_lex_locators
            dictionary.  This can be useful if you want to use an element in
            a different way than the built in keywords allow.
        """ 
        locator = npsp_lex_locators
        for key in path.split('.'):
            locator = locator[key]
        main_loc = locator.format(*args, **kwargs)
        return main_loc   

    def wait_for_locator(self, path, *args, **kwargs):
        """Waits for 60 sec for the specified locator"""
        main_loc = self.get_npsp_locator(path,*args, **kwargs)    
        self.selenium.wait_until_element_is_visible(main_loc, timeout=60)

    def wait_for_locator_is_not_visible(self, path, *args, **kwargs):
        """Waits for 60 sec for the specified locator"""
        main_loc = self.get_npsp_locator(path,*args, **kwargs)
        self.selenium.wait_until_element_is_not_visible(main_loc, timeout=60)

    @capture_screenshot_on_error    
    def wait_for_batch_to_complete(self, path, *args, **kwargs):
        """Checks every 15 secs for upto 3.5mins for batch with given status
        """
        i = 0
        locator = self.get_npsp_locator(path,*args, **kwargs)
        while True:
            i += 1
            if i > 14:
                self.selenium.capture_page_screenshot()
                raise AssertionError(
                    "Timed out waiting for batch with locator {} to load.".format(locator)
                )
            else:    
                try:
                    self.selenium.wait_until_element_is_visible(locator)
                    break
                except Exception:
                    time.sleep(15)   
     
    @capture_screenshot_on_error                
    def wait_for_batch_to_process(self, batch,status):
        """Checks every 30 secs for upto 9mins for batch with given status
        """
        i = 0
        sec=0
        expected = npsp_lex_locators['batch_status'].format(batch,status)
        error = npsp_lex_locators['batch_status'].format(batch,"Errors")
        while True:
            i += 1
            if i > 18:
                self.selenium.capture_page_screenshot()
                raise AssertionError("Timed out waiting for batch {} with status {} to load.".format(batch,status))
            elif self.check_if_element_exists(error):
                if status != "Errors":
                    raise AssertionError("Batch {} failed with Error".format(batch))
                break
            else:    
                try:
                    self.selenium.wait_until_element_is_visible(expected)
                    break
                except Exception:
                    sec= sec+30
                    print("Batch processing is not finished with {} status in {} seconds".format(status,sec))                 

    def get_npsp_settings_value(self,field_name): 
        locator = npsp_lex_locators['npsp_settings']['field_value'].format(field_name)
        loc = self.selenium.get_webelement(locator).text  
        return loc 
    



    def verify_payment_details(self, numpayments):
        """Gets the payment details from the UI and compares with the expected number of payments"""
        locator = "//tbody/tr/td[2]/span/span"
        locs1 = self.selenium.get_webelements(locator)
        locator2 = "//tbody/tr/td[3]/span/span"
        locs2 = self.selenium.get_webelements(locator2)
        for i, j in list(zip(locs1, locs2)):
            #loc1_vaue = self.selenium.get_webelemt(i).text
            #loc2_vaue = self.selenium.get_webelemt(j).text
            if i.text == "Pledged" and j.text == "$100.00":
                pass
            else:
                return "fail"
        self.builtin.should_be_equal_as_strings(len(locs1), numpayments)

    # def verify_opportunities(self, len_value):
    #     locator = "//tbody/tr[12]/th"
    #     s = self.selenium.get_webelement(locator).text
    #     #return s
    #     strip_list = s.split(" ")
    #     date = strip_list[-1]
    #     date = date.split("/")
    #     date = list(map(int, date))
    #     mm, dd, yyyy = date
    #     for _ in range(int(len_value)):
    #         if mm == 12:
    #             mm = 1
    #             yyyy = yyyy + 1
    #             date = [mm, dd, yyyy]
    #             date = list(map(str, date))
    #             date = "/".join(date)
    #             loctor_contains = "//tbody//a[contains(@title , '{}')]".format(date)
    #             self.selenium.page_should_contain_element(loctor_contains)            
    #         else:
    #             mm = mm + 1
    #             date = [mm, dd, yyyy]
    #             date = list(map(str, date))
    #             date = "/".join(date)
    #             loctor_contains = "//tbody//a[contains(@title , '{}')]".format(date)
    #             self.selenium.page_should_contain_element(loctor_contains)

    def click_object_manager_button(self,title):  
        """clicks on the buttons in object manager"""      
        locator=npsp_lex_locators['object_manager']['button'].format(title)
        self.selenium.get_webelement(locator).click()  
        
    def click_bge_button(self,text):  
        """clicks on buttons for BGE"""  
        self.builtin.log("This test is using javascript to click on button as regular click wouldn't work with Summer19", "WARN")    
        locator=npsp_lex_locators['bge']['button'].format(text)
        time.sleep(1)
        element = self.selenium.driver.find_element_by_xpath(locator)
        self.selenium.driver.execute_script('arguments[0].click()', element)
    
    def verify_title(self,title,value):
        """"""
        locator=npsp_lex_locators['bge']['title'].format(title,value)
        actual_value=self.selenium.get_webelement(locator).text
        assert value == actual_value, "Expected value to be {} but found {}".format(
            value, actual_value
        )             
    
    def page_scroll_to_locator(self, path, *args, **kwargs):
        locator = self.get_npsp_locator(path, *args, **kwargs)
        self.selenium.scroll_element_into_view(locator)   

    def get_bge_card_header(self,title):   
        """Validates if the specific header field has specified value"""   
        locator= npsp_lex_locators['bge']['card-header'].format(title)
        id=self.selenium.get_webelement(locator).text   
        return id    
        
    def click_bge_edit_button(self, title):  
        """clicks the button in the table by using name mentioned in data-label"""
        locator=npsp_lex_locators['bge']['edit_button'].format(title)
        #self.selenium.get_webelement(locator).click()
        self.selenium.click_button(locator)
            
    def populate_bge_edit_field(self, title, value):
        """Clears the data in input field and enters the value specified """
        locator=npsp_lex_locators['bge']['edit_field'].format(title)
        field=self.salesforce._populate_field(locator, value)
        
    def verify_row_count(self,value):
        """verifies if actual row count matches with expected value"""
        locator=npsp_lex_locators['bge']['count']
        actual_value=self.selenium.get_webelements(locator)
        count=len(actual_value)
        assert int(value) == count, "Expected rows to be {} but found {}".format(
            value, count
        )       
     
    def return_locator_value(self, path, *args, **kwargs): 
        """Returns the value pointed by the specified locator"""
        locator=self.get_npsp_locator(path, *args, **kwargs)
        self.selenium.wait_until_page_contains_element(locator)
        value=self.selenium.get_webelement(locator).text   
        return value
        
    def return_list(self, path, *args, **kwargs): 
        """Returns all the values pointed by the specified locator"""
        locator=self.get_npsp_locator(path, *args, **kwargs)
        values=self.selenium.get_webelements(locator)
        return [i.text for i in values]

    def select_bge_row(self, value):
        """To select a row on object page based on name and open the dropdown"""
        locators = npsp_lex_locators['bge']['name']
        list_ele = self.selenium.get_webelements(locators)
        for index, element in enumerate(list_ele):
            if element.text == value:
                drop_down = npsp_lex_locators['bge']['locate_dropdown'].format(index+1)
                self.selenium.click_element(drop_down)
                time.sleep(1)

    def click_link_with_text(self, text):
        self.builtin.log("This test is using the 'Click link with text' workaround", "WARN")
        locator = npsp_lex_locators['link-text'].format(text)
        self.selenium.wait_until_page_contains_element(locator)
        element = self.selenium.driver.find_element_by_xpath(locator)
        self.selenium.driver.execute_script('arguments[0].click()', element)  
    
    def verify_expected_batch_values(self, batch_id,**kwargs):
        """To verify that the data in Data Import Batch matches expected value provide batch_id and the data u want to verify"""    
        ns=self.get_npsp_namespace_prefix()
        table=ns + "DataImportBatch__c"
        bge_batch=self.salesforce.salesforce_get(table,batch_id)
        for key, value in kwargs.items():
            label=ns + key
            self.builtin.should_be_equal_as_strings(bge_batch[label], value)
            
    def click_element_with_locator(self, path, *args, **kwargs):
        """Pass the locator and its values for the element you want to click """
        locator=self.get_npsp_locator(path, *args, **kwargs)  
        self.selenium.click_element(locator)      
            
    def wait_for_record_to_update(self, id, value):
        """Waits for specified record header to be updated by checking every second for 10 times.
        """
        i = 0
        while True:
            i += 1
            if i > 10:
                raise AssertionError(
                    "Timed out waiting for record name to be {} .".format(value)
                )
            self.salesforce.go_to_record_home(id)
            try:
                self.verify_header(value)
                break
            except Exception:
                time.sleep(1)
                     
    def load_locator(self, locator):
        """Scrolls down until the specified locator is found.
        """
        i = 0
        while True:
            i += 1
            if i > 20:
                raise AssertionError(
                    "Timed out waiting for locator {} to load.".format(locator)
                )
            self.selenium.execute_javascript("window.scrollBy(0, 100)")
            self.wait_for_aura()
            try:
                self.selenium.get_webelement(locator)
                break
            except ElementNotFound:
                time.sleep(0.2)
                        
    def select_multiple_values_from_duellist(self,path,list_name,section,*args): 
        """Pass the list name and values to be selected from the dropdown. """
        main_loc = npsp_lex_locators
        for key in path.split('.'):
            main_loc = main_loc[key]
        for i in args:
            locator = main_loc.format(list_name,section,i)
            if args.index(i)==0:
                self.selenium.click_element(locator)
            else:
                self.selenium.click_element(locator,'COMMAND')
                
    def click_duellist_button(self, list_name,button):
        list_found = False
        locators = npsp_lex_locators["bge-duellist-btn"].values()

        for i in locators:
            locator = i.format(list_name,button)
            if self.check_if_element_exists(locator):
                loc=self.selenium.get_webelement(locator)
                self.selenium.click_element(locator)
                list_found = True
                break

        assert list_found, "Dropdown with the provided locator not found"            
    
    def verify_expected_values(self,ns_ind,obj_api,rec_id,**kwargs):
       """To verify that the data in database table match with expected value, 
       provide ns if object has namespace prefix otherwise nonns,
       object api name, record_id and the data u want to verify"""    
       if(ns_ind=='ns'):
           ns=self.get_npsp_namespace_prefix()
           table=ns + obj_api
       else:
            table=obj_api
       try :
           rec=self.salesforce.salesforce_get(table,rec_id)
           for key, value in kwargs.items():
               print(f"executing {key}, {value} pair")
               self.builtin.should_be_equal_as_strings(rec[key], value)
       except Exception :
           print("Retrying after exception")
           time.sleep(10)
           rec=self.salesforce.salesforce_get(table,rec_id)
           for key, value in kwargs.items():
               print(f"executing {key}, {value} pair")
               self.builtin.should_be_equal_as_strings(rec[key], value)

    def get_org_namespace_prefix(self):
        if self.cumulusci.org.namespaced:
            return "npsp__" 
        else:
            return ""       
     
    @capture_screenshot_on_error      
    def click_first_matching_related_item_popup_link(self,heading,rel_status,link):
        '''Clicks a link in the popup menu for first matching related list item.
        heading specifies the name of the list,
        rel_status specifies the status or other field vaule to identify a particular item,
        and link specifies the name of the link''' 
        self.salesforce.load_related_list(heading)
        locator = npsp_lex_locators["record"]["related"]["link"].format(heading, rel_status)
        mylist=self.selenium.get_webelements(locator)
        title=mylist[0].text
        print(f"title is {title}")
        self.click_special_related_item_popup_link(heading, title, link)
        
    def click_special_related_item_popup_link(self, heading, title, link):
        """Clicks a link in the popup menu for a related list item.

        heading specifies the name of the list,
        title specifies the name of the item,
        and link specifies the name of the link
        """
        self.salesforce.load_related_list(heading)
        locator = npsp_lex_locators["record"]["related"]["popup_trigger"].format(heading, title)
        self.selenium.wait_until_page_contains_element(locator)
        self.salesforce._jsclick(locator)
        locator = npsp_lex_locators["popup-link"].format(link)
        self.salesforce._jsclick(locator)
        self.salesforce.wait_until_loading_is_complete()    
        
    def verify_field_values(self,**kwargs):
        """Verifies values in the specified fields""" 
        for key, value in kwargs.items():
            locator=npsp_lex_locators["field-value"].format(key)
            res=self.selenium.get_webelement(locator).text
            assert value == res, "Expected {} value to be {} but found {}".format(key,value,res)
            
    def checkbox_status(self,cbx_name,status):
        """verifies if the specified checkbox is with expected status in readonly mode"""
        locator=npsp_lex_locators["custom_settings"]["cbx_status"].format(cbx_name,status)
        self.selenium.page_should_contain_element(locator, message='{cbx_name} checkbox is supposed to be {status}')
                
    def go_to_setup_page(self,page):
        """ Navigates to the specified page in Salesforce Setup """
        url = self.cumulusci.org.lightning_base_url
        url = "{}/lightning/setup/{}/home".format(url,page)
        self.selenium.go_to(url)
        self.salesforce.wait_until_loading_is_complete()

    def click_wrapper_related_list_button(self,heading,button_title):  
        """Clicks a button in the heading of a related list when the related list is enclosed in wrapper.
           Waits for a modal to open after clicking the button.
        """  
        locator = npsp_lex_locators["record"]["related"]["button"].format(heading, button_title)
        element = self.selenium.driver.find_element_by_xpath(locator)
        self.selenium.driver.execute_script('arguments[0].click()', element)  

# Keywords below this line are for accessibility testing 



    def inject_axe_core_library(self):
        path = os.path.dirname(os.path.abspath(__file__))
        self.selenium.execute_javascript(path + "/axe.js")
    
    
    def get_axe_analysis_results(self,cssSelector = None):    
        context = "document"
        if cssSelector != None:
            context = "{include: [['%s']]}" % cssSelector
    
        runScript = """
            var callback = arguments[arguments.length - 1];
            var options = {runOnly: {type: "tag", values: ["wcag2a", "wcag2aa", "best-practice"]}};
            var cb = function(error, results) { if (error) { throw error }; callback(results) };
            axe.run(%s, options, cb);
        """ % context
        results = self.selenium.execute_async_javascript(runScript)
        self.selenium.capture_page_screenshot()
        return results
    
    
    def log_summary_of_results(self,results):
        """This keyword just logs the summary of results"""
        logger.debug(results)
    
        passed = results["passes"]
        inapplicable = results["inapplicable"]
        incomplete = results["incomplete"]
        violations = results["violations"]
    
        numPasses = len(results["passes"])
        numInapplicable = len(results["inapplicable"])
        numIncomplete = len(results["incomplete"])
        numViolations = len(results["violations"])
    
        logger.info("Passed: %d, Inapplicable: %d, Incomplete: %d, Violations: %d" % (numPasses, numInapplicable, numIncomplete, numViolations))
    
    
    def log_raw_results(self,results):
        logger.info(json.dumps(results, indent=4));
    
    
    def warn_on_incomplete_rules(self,results):
        """ Prints a warn for any rules that couldn't be determined automatically. Returns the number of such warnings. """
        for rule in results["incomplete"]:
            self.print_result(rule, "Incomplete (requires manual review)", logger.warn)
        return len(results["incomplete"])
    
    def warn_on_violations_rules(self,results):
        """ If there are violations on the page, logs as warning and gives the details of violations on the page """
        for rule in results["violations"]:
            self.print_result(rule, "violation", logger.warn)
        return len(results["violations"])
    
    def fail_if_there_are_violations(self,results):
        """If there are violations on the page, returns the keyword as failed and gives the details of violations on the page"""
        failures = ""
        for rule in results["violations"]:
            self.print_result(rule, "Violation")
            failures += "  - %s: %s\n" % (rule["id"], rule["help"])
    
        numViolations = len(results["violations"])
        if numViolations > 0:
            raise Exception("Found %d violations:\n%s" % (numViolations, failures))
    
    
    def print_result(self,result, preamble=None, logFunc=logger.info):
        impact = result["impact"]
        desc = result["description"]
        url = result["helpUrl"]
        ruleId = result["id"]
        helpString = result["help"] # short string
        tags = result["tags"] #array
    
        header = ""
        if preamble != None: header = "<b>" + preamble + "</b><br/>"
    
        header += "[<b>%s</b>:<a href='%s'>%s</a>] %s" % (impact, url, ruleId, escape(helpString))
        header += " (<em>Tags: " + ", ".join(result["tags"]) + "</em>)"
        header += "<br />%s" % (escape(desc))
        #logger.warn(header, html=True)
    
        message = header
        message += "<ul>"
    
        for node in result["nodes"]:
            targetString = ""
            for target in node["target"]:
                if type(target) is str :
                    targetString += target
                elif type(target) is list:
                    for frame_target in target:
                        targetString += ">> %s" % frame_target
    
            message += "<li>Target: <b>%s</b><br/>HTML: %s" % (targetString, escape(node["html"]))
            if len(node["any"]) > 0:
                any_message = "<br/><b>Fix at least one of:</b><ul>"
                for check in node["any"]:
                    any_message += "<li>" + check["message"] + "</li>"
                any_message += "</ul>"
                message += any_message
    
            all_message = ""
            if len(node["all"]) > 0:
                all_message = "<br/><b>Fix all of:</b><ul>"
                for check in node["all"]:
                    all_message += "<li>" + check["message"] + "</li>"
                all_message += "</ul>"
                message += all_message
    
        message += "</ul>"
    
        logFunc(message, html=True)
        logger.debug(json.dumps(result, indent=4))
    
    # End of Accessibility keywords         
   
     
    @capture_screenshot_on_error    
    def change_view_to(self,view_name): 
        """Selects a different view for the object records in listing page""" 
        locator=npsp_lex_locators['object_dd']
        view=npsp_lex_locators['link'].format(view_name,view_name)
        self.selenium.wait_until_page_contains("List Views")
        self.selenium.get_webelement(locator).click()
        element = self.selenium.driver.find_element_by_xpath(view)
        self.selenium.driver.execute_script('arguments[0].click()', element)
        self.selenium.wait_until_page_contains(view_name)
        

    def search_field_by_value(self, fieldname, value):
         """ Searches the field with the placeholder given by 'fieldname' for the given 'value'
         """
         xpath = npsp_lex_locators["placeholder"].format(fieldname)
         field = self.selenium.get_webelement(xpath)
         self.selenium.clear_element_text(field)
         field.send_keys(value)
         time.sleep(2)
         field.send_keys(Keys.ENTER)
        
    def save_current_record_id_for_deletion(self,object_name): 
        """Gets the current page record id and stores it for specified object 
           in order to delete record during suite teardown """  
#         self.pageobjects.current_page_should_be("Details",object_name)    
        id=self.salesforce.get_current_record_id()
        self.salesforce.store_session_record(object_name,id)   
        return id
    
    def verify_record_is_created_in_database(self,object_name,id):
        """Verifies that a record with specified id is saved 
           in specified object table in database and returns the record"""
        record=self.salesforce.salesforce_get(object_name,id)
        self.builtin.should_not_be_empty(record, msg="The database object {} with id {} is not in the database".format(object_name,id))
        return record
    
    @capture_screenshot_on_error
    def select_value_from_dropdown(self,dropdown,value): 
        """Select given value in the dropdown field"""
        locator = npsp_lex_locators['record']['list'].format(dropdown)
        self.selenium.scroll_element_into_view(locator)
        self.selenium.get_webelement(locator).click()
        self.wait_for_locator('popup')
        self.selenium.click_link(value) 
        
    def edit_record(self):
        """Clicks on the edit button on record page for standard objects
           and waits for the modal to open"""  
        self.salesforce.click_object_button("Edit")
        self.salesforce.wait_until_modal_is_open()

    def randomString(self,stringLength=10):
        """Generate a random string of fixed length """
        letters = string.ascii_lowercase
        return ''.join(random.choice(letters) for i in range(stringLength))

    @capture_screenshot_on_error
    def scroll_button_into_view_and_click_using_js(self, value):
        """Scrolls the button element into view and clicksthe button using JS """
        xpath = npsp_lex_locators['button'].format(value)
        self.selenium.wait_until_element_is_visible(xpath)
        javascript = (
            "window.document.evaluate("
            f"    '{xpath}', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null"
            ").singleNodeValue.scrollIntoView(true)"

        )
        self.selenium.execute_javascript(javascript)
        time.sleep(2)
        self.npsp.click_button_with_value(value)

    def setupdata(self, name, contact_data=None, opportunity_data=None, account_data=None, payment_data=None, engagement_data=None,
                  recurringdonation_data=None, gau_data=None):
        """ Creates an Account if account setup data is passed
            Creates a contact if contact_data is passed
            Creates an opportunity for the contact if opportunit_data is provided
            Creates a contact and sets an opportunity simultaneously if both the
            contact_data and opportunity_data is specified
            Creates a contact and sets up an engagement plan with both contact and engagement plan information is provided
         """

        # get the data variable, or an empty dictionary if not set

        data = self.builtin.get_variable_value("${data}", {})
        ns=self.get_npsp_namespace_prefix()

        if account_data is not None:
            # create the account based on the user input specified account type
            acctname = self.randomString(10);
            rt_id = self.salesforce.get_record_type_id("Account",account_data["Type"])
            account_data.update( {'Name' : acctname,'RecordTypeId' : rt_id})
            account_id = self.salesforce.salesforce_insert("Account", **account_data)
            account = self.salesforce.salesforce_get("Account",account_id)
            # save the account object to data dictionary
            data[name] = account

        if contact_data is not None:
            # create the contact
            firstname = self.randomString(10);
            lastname = self.randomString(10);
            contact_data.update( {'Firstname' : firstname,'Lastname' : lastname})
            contact_id = self.salesforce.salesforce_insert("Contact", **contact_data)
            contact = self.salesforce.salesforce_get("Contact",contact_id)
            # save the contact object to data dictionary
            data[name] = contact

        if engagement_data is not None:
            # set up enegagement template based on the user input specified and link the contact to the engagement template
            engobjname = "Engagement_Plan_Template__c"
            contactobjname = "Contact__c"
            # Fromatting the objects names with namespace prefix
            formattedengobjname = "{}{}".format(self.cumulusci.get_namespace_prefix(), engobjname)
            formattedcontactobjname = "{}{}".format(self.cumulusci.get_namespace_prefix(), contactobjname)
            engagement_id = self.salesforce.salesforce_insert(formattedengobjname, **engagement_data)
            engagement = self.salesforce.salesforce_get(formattedengobjname,engagement_id)

          # If the keyword is contact, link the contact to the engagement plan created
            if name.lower() == 'contact':
                testdata={}
                testdata.update( {formattedcontactobjname : data[name]["Id"], formattedengobjname: engagement_id } )
                self.salesforce.salesforce_insert(formattedengobjname, **testdata)

            # save the engagement object to data dictionary

            if name.lower() == 'contact':
                data[f"{name}_engagement"] = engagement
            else:
                data[name] = engagement
        # set a recurring donation for a contact
        if recurringdonation_data is not None:
            recurringdonation_data.update( {'npe03__Contact__c' : data[name]["Id"] } )
            rd_id = self.salesforce.salesforce_insert("npe03__Recurring_Donation__c", **recurringdonation_data)
            recurringdonation = self.salesforce.salesforce_get("npe03__Recurring_Donation__c",rd_id)
            data[f"{name}_rd"] = recurringdonation
        #set gau data
        if gau_data is not None:
            object_key =  f"{ns}General_Accounting_Unit__c"
            gauname = gau_data['Name']
            random = self.randomString(10);
            gau_data.update( {'name' : f"{random}{gauname}"} )
            gau_id = self.salesforce.salesforce_insert(object_key, **gau_data)
            gau = self.salesforce.salesforce_get(object_key,gau_id)
            data[name] = gau
        # set opportunity association with a contact or account
        if opportunity_data is not None:
            # create opportunity
            rt_id = self.salesforce.get_record_type_id("Opportunity",opportunity_data["Type"])
            # if user did not specify any date value add the default value
            if 'CloseDate' not in opportunity_data:
                date = datetime.now().strftime('%Y-%m-%d')
                opportunity_data.update({'CloseDate' : date})
            if 'npe01__Do_Not_Automatically_Create_Payment__c' not in opportunity_data:
                Automatically_create_key = 'npe01__Do_Not_Automatically_Create_Payment__c'
                Automatically_create_value = 'true'
                opportunity_data.update({Automatically_create_key : Automatically_create_value})
            if 'StageName' not in opportunity_data:
                opportunity_data.update( {'StageName' : 'Closed Won'} )
            if 'AccountId' not in opportunity_data:
                opportunity_data.update( {'AccountId' : data[name]["AccountId"] } )

            opportunity_data.update( {'RecordTypeId': rt_id } )
            opportunity_id = self.salesforce.salesforce_insert("Opportunity", **opportunity_data)
            opportunity = self.salesforce.salesforce_get("Opportunity",opportunity_id)
            # save the opportunity
            data[f"{name}_opportunity"] = opportunity

            if payment_data is not None:
                numdays = 30
                i = 1
                while i <= int(payment_data['NumPayments']):
                    payment_schedule_data = {}
                    numdays = numdays*2
                    scheduled_date =  (datetime.now() + timedelta(days = numdays)).strftime('%Y-%m-%d')
                    payment_schedule_data.update( {'npe01__Opportunity__c' : data[f"{name}_opportunity"]["Id"] , 'npe01__Scheduled_Date__c' : scheduled_date, 'npe01__Payment_Amount__c' : payment_data['Amount'] } )
                    payment_id = self.salesforce.salesforce_insert("npe01__OppPayment__c", **payment_schedule_data)
                    i = i+1

        self.builtin.set_suite_variable('${data}', data)

        return data

    def delete_record(self,value):
        """Select the row to be deleted on the listing page, click delete
           and wait till the focus is back on the listings page."""
        self.select_row(value)
        self.selenium.click_link("Delete")
        self.selenium.wait_until_location_contains("/list")
        self.selenium.wait_until_page_does_not_contain(value)
    
    @capture_screenshot_on_error    
    def populate_modal_form(self,**kwargs):
        """Populates modal form with the field-value pairs 
        supported keys are any input, textarea, lookup, checkbox, date and dropdown fields"""
        
        for key, value in kwargs.items():
            locator = npsp_lex_locators["modal-form"]["label"].format(key)
            if self.check_if_element_exists(locator):
                ele=self.selenium.get_webelements(locator)
                for e in ele:
                    classname=e.get_attribute("class")
#                     print("key is {} and class is {}".format(key,classname))
                    if "Lookup" in classname and "readonly" not in classname:
                        self.salesforce.populate_lookup_field(key,value)
                        print("Executed populate lookup field for {}".format(key))
                        break
                    elif "Select" in classname and "readonly" not in classname:
                        self.select_value_from_dropdown(key,value)
                        print("Executed select value from dropdown for {}".format(key))
                        break
                    elif "Checkbox" in classname and "readonly" not in classname:
                        if value == "checked":
                            locator = npsp_lex_locators["checkbox"]["model-checkbox"].format(key)
                            self.selenium.get_webelement(locator).click()
                            break 
                    elif "Date" in classname and "readonly" not in classname:
                        self.open_date_picker(key)
                        self.pick_date(value)
                        print("Executed open date picker and pick date for {}".format(key))
                        break
                    else:
                        try :
                            self.search_field_by_value(key,value)
                            print("Executed search field by value for {}".format(key))
                        except Exception :
                            try :
                                self.salesforce.populate_field(key,value)
                                print("Executed populate field for {}".format(key))
                                   
                            except Exception:
                                print ("class name for key {} did not match with field type supported by this keyword".format(key))
                                     
            else:
                raise Exception("Locator for {} is not found on the page".format(key))   
     
    def verify_toast_message(self,value):
        """Verifies that toast contains specified value"""       
        locator=npsp_lex_locators["toast-msg"]
        self.selenium.wait_until_page_contains_element(locator)
        msg=self.selenium.get_webelement(locator).text
        if msg == value:
            print("Toast message verified")
        else:
            raise Exception("Expected Toast message not found on page")    


    def edit_record_field_value(self,field,value):
        """Scrolls just a little below the field
           Clicks on Edit icon next to field and enters a value into the field"""
        scroll_loc=npsp_lex_locators["span_button"].format(field)
        # To make sure the field we want to edit has rendered
        # and is not obscured by the footer, scroll down a little below the element
        self.selenium.scroll_element_into_view(scroll_loc)
        self.selenium.execute_javascript("window.scrollBy(0,50)")
        btn="Edit "+field
        self.selenium.click_button(btn)
        footer=npsp_lex_locators["record"]["footer"]
        self.selenium.wait_until_page_contains_element(footer)
        self.salesforce.populate_lookup_field(field,value)

    def edit_record_dropdown_value(self,field,value):
        """Scrolls just a little below the field
           Clicks on Edit icon next to field and enters a value into the field"""
        scroll_loc=npsp_lex_locators["span_button"].format(field)
        # To make sure the field we want to edit has rendered
        # and is not obscured by the footer, scroll down a little below the element
        self.selenium.scroll_element_into_view(scroll_loc)
        self.selenium.execute_javascript("window.scrollBy(0,50)")
        btn="Edit "+field
        self.selenium.click_button(btn)
        footer=npsp_lex_locators["record"]["footer"]
        self.selenium.wait_until_page_contains_element(footer)
        time.sleep(2)
        self.click_flexipage_dropdown(field, value)

    def edit_record_checkbox(self,field,status):
        """Scrolls just a little below the field
           Clicks on Edit icon next to field
           checks if status is 'checked' 
           unchecks if status in 'unchecked'"""
        scroll_loc=npsp_lex_locators["span_button"].format(field)
        # To make sure the field we want to edit has rendered
        # and is not obscured by the footer, scroll down a little below the element
        self.selenium.scroll_element_into_view(scroll_loc)
        self.selenium.execute_javascript("window.scrollBy(0,50)")
        btn="Edit "+field
        self.selenium.click_button(btn)
        footer=npsp_lex_locators["record"]["footer"]
        self.selenium.wait_until_page_contains_element(footer)
        self.set_checkbutton_to(field,status)    
        
    def save_record(self): 
        """Saves record by clicking on footer button 'Save'"""
        footer=npsp_lex_locators["record"]["footer"]
        self.click_record_button("Save")
        self.selenium.wait_until_page_does_not_contain_element(footer)
        #Once the record is saved, scroll to top in order to be able to interact with elements above this
        self.selenium.execute_javascript("window.scrollTo(0,0)")   
    
    def Delete_record_field_value(self,field,value):
        """Scrolls just a little below the field
           Clicks on Edit icon next to field and delete the value by clicking on 'X'"""
        scroll_loc=npsp_lex_locators["span_button"].format(field)
        # To make sure the field we want to edit has rendered
        # and is not obscured by the footer, scroll down a little below the element
        self.selenium.scroll_element_into_view(scroll_loc)
        self.selenium.execute_javascript("window.scrollBy(0,50)")
        btn="Edit "+field
        self.selenium.click_button(btn)
        footer=npsp_lex_locators["record"]["footer"]
        self.selenium.wait_until_page_contains_element(footer)
        locator=npsp_lex_locators['delete_icon_record'].format(field,value)
        self.selenium.get_webelement(locator).click()        
        
    def select_date_from_datepicker(self,field,value):
        field_loc=npsp_lex_locators["bge"]["field-input"].format(field)
        self.selenium.click_element(field_loc)
        locator=npsp_lex_locators["bge"]["datepicker_open"].format(field)  
        self.selenium.wait_until_page_contains_element(locator)
        self.click_bge_button(value)
        self.selenium.wait_until_page_does_not_contain_element(locator,error="could not open datepicker")    
        
    def click_more_actions_button(self):
        """clicks on the more actions dropdown button in the actions container on record page"""
        locator=npsp_lex_locators['link'].format("more actions","more actions")
        self.salesforce._jsclick(locator)
        
        
    @capture_screenshot_on_error
    def click_related_table_item_link(self, heading, title):
        """Clicks a table header field link in the related list identified with the specified heading.
           This keyword will automatically call `Wait until loading is complete`
        """
        self.builtin.log("loading related list...", "DEBUG")
        self.salesforce.load_related_list(heading)
        locator = npsp_lex_locators["record"]["related"]["link"].format(heading, title)
        self.builtin.log("clicking...", "DEBUG")
        self.salesforce._jsclick(locator)
        self.builtin.log("waiting...", "DEBUG")
        self.salesforce.wait_until_loading_is_complete()      

    def click_actions_link(self,title):
        """Clicks on the link in the actions container on top right corner of the page using Javascript"""
        locator=npsp_lex_locators["link-title"].format(title)
        self.salesforce._jsclick(locator)
     
    def click_more_activity_button(self): 
        """Clicks on View More button on Activity tab of the record""" 
        locator = npsp_lex_locators["record"]["activity-button"].format('showMoreButton') 
        self.salesforce._jsclick(locator) 

    def click_button_with_title(self,title):
        """Clicks button identified by title using Javascript"""
        locator = npsp_lex_locators["button-title"].format(title)
        self.salesforce._jsclick(locator)

    def click_show_more_actions_button(self,title):
        """Clicks on more actions dropdown and click the given title"""   
        locator=npsp_lex_locators['link-contains'].format("more actions")
        self.selenium.click_element(locator)
        self.selenium.wait_until_page_contains(title)
        link_locator=npsp_lex_locators['custom_objects']['actions-link'].format(title,title)
        self.selenium.click_link(link_locator)

    def get_url_formatted_object_name(self,name):
        """Returns a map with BaseURl and the namespace formatted object name"""
        out = {}
        base_url = self.cumulusci.org.lightning_base_url
        object_name = "{}{}".format(self.cumulusci.get_namespace_prefix(), name)
        out['baseurl'] = base_url
        out['objectname'] = object_name
        return out