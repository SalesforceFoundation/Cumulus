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
* @description Unit of Work in NPSP.
*/
public inherited sharing class UnitOfWork {

    @TestVisible
    private List<SObject> objectsToInsert = new List<SObject>();
    @TestVisible
    private List<SObject> objectsToUpdate = new List<SObject>();

    public Database.SaveResult[] save() {
        List<Database.SaveResult> saveResults = new List<Database.SaveResult>();
        if (!objectsToInsert.isEmpty()) {
            saveResults.addAll(UTIL_DMLService.insertRecords(objectsToInsert, false));
        }
        if (!objectsToUpdate.isEmpty()) {
            saveResults.addAll(UTIL_DMLService.updateRecords(objectsToUpdate, false));
        }
        return saveResults;
    }

    public void registerNew(List<SObject> sObjects) {
        objectsToInsert.addAll(sObjects);
    }

    public void registerDirty(List<SObject> sObjects) {
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>(objectsToUpdate);
        for (SObject sobj : sObjects) {
            SObject inMap = sObjectMap.get(sobj.Id);
            if (inMap != null) {
                updateFields(sobj, inMap);
            } else {
                objectsToUpdate.add(sobj);
            }
        }
    }

    private void updateFields(SObject sobj, SObject inMap) {
        for (String field : sobj.getPopulatedFieldsAsMap().keySet()) {
            Object newVal = sobj.get(field);
            Object val = inMap.get(field);

            if (val == null || !val.equals(newVal)) {
                inMap.put(field, newVal);
            }

            // Specifically handle Strings to enforce case-sensitivity
            if (val instanceof String) {
                String strVal = (String) val;
                if (!strVal.equals(newVal)) {
                    inMap.put(field, newVal);
                }
            }
        }
    }

}