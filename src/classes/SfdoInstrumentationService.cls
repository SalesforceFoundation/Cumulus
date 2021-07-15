/*
    Copyright (c) 2021 Salesforce.org
    All rights reserved.
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2021
* @group Product Instrumentation
* @description Primary class to enable product instrumentation for adoption and usage aggregation
*
*/
public inherited sharing class SfdoInstrumentationService {
    public SfdoInstrumentationService() { }

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     * @param payload Map of additional content as context to include in the log (DO NOT INCLUDE PII or NON-GPDR COMPLIANT DATA)
     */
    public static void log(SfdoInstrumentationEnum.Feature featureName, SfdoInstrumentationEnum.Component componentName, SfdoInstrumentationEnum.Action actionName, Map<String, Object> payload) { 
        SfdoLogUtils.log(featureName?.name(), componentName?.name(), actionName?.name(), payload);
    }

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     * @param payload Map of additional content as context to include in the log (DO NOT INCLUDE PII or NON-GPDR COMPLIANT DATA)
     * @param value Duration or other value to include in the log
     */
    public static void log(SfdoInstrumentationEnum.Feature featureName, SfdoInstrumentationEnum.Component componentName, SfdoInstrumentationEnum.Action actionName, Map<String, Object> payload, Integer value) { 
        SfdoLogUtils.log(featureName?.name(), componentName?.name(), actionName?.name(), payload, value);
    }

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     * @param value Duration or other value to include in the log
     */
    public static void log(SfdoInstrumentationEnum.Feature featureName, SfdoInstrumentationEnum.Component componentName, SfdoInstrumentationEnum.Action actionName, Integer value) { 
        SfdoLogUtils.log(featureName?.name(), componentName?.name(), actionName?.name(), value);
    }

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     */
    public static void log(SfdoInstrumentationEnum.Feature featureName, SfdoInstrumentationEnum.Component componentName, SfdoInstrumentationEnum.Action actionName) {
        SfdoLogUtils.log(featureName?.name(), componentName?.name(), actionName?.name());
    }

    /**
     * @description Retrieve the Action Enum for a specific TriggerHandler Event Type
     * @param  thisAction thisAction
     * @return Action enum
     */
    public static SfdoInstrumentationEnum.Action getActionFromTriggerEvent(TDTM_Runnable.Action thisAction) {
        String val = thisAction.name();

        for (SfdoInstrumentationEnum.Action a : SfdoInstrumentationEnum.Action.values()) {
            if (a.name() == val) {
                return a;
            }
        }
        return null;
    }

        /**
     * @description Retrieve the Component Enum for a specific String value, such as an object name
     * @param  String value to find in the Enum list
     * @return Component Enum
     */
    public static SfdoInstrumentationEnum.Component getComponentFromString(String val) {

        for (SfdoInstrumentationEnum.Component c : SfdoInstrumentationEnum.Component.values()) {
            if (c.name() == val) {
                return c;
            }
        }
        return null;
    }

}
