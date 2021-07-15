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
*  ***************************************************************************************************************************************************
*                                               DO NOT INCLUDE THIS CLASS IN THE MANAGED PACKAGE
*                   DO NOT CALL THIS CLASS DIRECTLY TO LOG. USE THE PROVIDED SFDOINSTRUMENTATIONSERVICE IMPLEMENTATION INSTEAD.
*  ***************************************************************************************************************************************************
*
*
* Core Work Item: W-9167918
* Core Module: "sfdo"
* Core File-Based Apex Code: https://codesearch.data.sfdc.net/source/xref/app_main_core/app/main/core/sfdo/apex/
*
* @author Salesforce.org
* @date 2021
* @group Product Instrumentation
* @description: Mock class is ONLY necessary when unmanaged code is deployed into an org without a namespace.
* - The method signatures in this class MUST match the core implementation of the "SfdoLogUtils" file-based apex class. 
* - The methods in this class mock the identical exposed methods in the core version of the class, however the core class is ONLY available to
*   managed code with the product namespace. 
* - By deploying this unmanaged class to the org BEFORE the rest of the product code is deployed, it will allow any package code that references
*   the SfdoLogUtils.log() methods to compile property by redirecting it to "this" mock class (which does nothing)
*
*/
public without sharing class SfdoLogUtils {

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     * @param payload Map of additional content as context to include in the log (DO NOT INCLUDE PII or NON-GPDR COMPLIANT DATA)
     */
    public static void log(String featureName, String componentName, String actionName, Map<String, Object> payload) { }

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     * @param payload Map of additional content as context to include in the log (DO NOT INCLUDE PII or NON-GPDR COMPLIANT DATA)
     * @param value Duration or other value to include in the log
     */
    public static void log(String featureName, String componentName, String actionName, Map<String, Object> payload, Integer value) { }

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     * @param value Duration or other value to include in the log
     */
    public static void log(String featureName, String componentName, String actionName, Integer value) { }

    /**
     * @param featureName - Feature name within the product the log is for
     * @param componentName String - defines the underlying component within the feature
     * @param actionName String - define the action of the feature or component
     */
    public static void log(String featureName, String componentName, String actionName) { }

}