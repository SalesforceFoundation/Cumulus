/*
    Copyright (c) 2017, Salesforce.org
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
* @date 2017
* @group Utilities
* @description Tests for the UTIL_CurrencyCache class
*/
@isTest
private class UTIL_CurrencyCache_TEST {

    /**
     * @description Validate advanced currency conversion logic using a defined set of effective dates and rates
     */
    static testMethod void test_AdvancedCurrencyConversion() {

        UtilCurrencyCacheMock mockcurrCache = new UtilCurrencyCacheMock();
        mockcurrCache.isOrgCacheAvailableReturn = false;
        // Dates list must always be in descending order
        mockcurrCache.effectiveDatesReturn = new List<Date>{
                Date.newInstance(2017,05,01), Date.newInstance(2017,03,01), Date.newInstance(2000,01,01)
        };
        mockcurrCache.effectiveRatesReturn = new List<Decimal>{
                1.35, 1.25, 1.5
        };
        mockcurrCache.defaultRate = 1.55;
        UTIL_CurrencyCache.instance = mockcurrCache;

        System.AssertEquals(False, UTIL_CurrencyCache.getInstance().isOrgCacheAvailable());
        System.AssertEquals( 1.25, UTIL_CurrencyCache.getEffectiveExchangeRate('CAD', Date.newInstance(2017,3,15)),
            'Should return the effective rate for 3/15/2017');
        System.AssertEquals( 1.50, UTIL_CurrencyCache.getEffectiveExchangeRate('CAD', Date.newInstance(2010,01,01)),
                'Should return the effective rate for 1/1/2010');
        System.AssertEquals( 1.55, UTIL_CurrencyCache.getEffectiveExchangeRate('CAD', null),
                'Should return the org default effective rate');

        // Add null rates value to simulate disabled currency.  Expect 1 if no rate found.
        UTIL_CurrencyCache.cachedMapOfRatesByCurrencyCode.put('AUD', null);
        System.AssertEquals(1, UTIL_CurrencyCache.getEffectiveExchangeRate('AUD', null));
    }

    /**
     * @description Validate that the cache is working, though there's really no way to know if the Org has an
     * org cache or not so this test is really just validating that the static var cache is storing and retrieving
     * the values as expected
     */
    static testMethod void test_CurrencyCache_StaticCacheVar() {
        // We won't really know if the client has a cache or not, so don't assume a response
        System.AssertNotEquals(null, UTIL_CurrencyCache.getInstance().isOrgCacheAvailable());

        // Populate the static var version of the currency cache to use for the tests below
        UTIL_CurrencyCache.cachedMapOfRatesByCurrencyCode.put('CAD', getDummyRates(Date.Today().AddYears(-1), 0.75));

        // The cache should now have one currency code
        System.AssertEquals(1, UTIL_CurrencyCache.cachedMapOfRatesByCurrencyCode.size(), 'The cache should not be empty');

        // validate that some values are returned for the CAD code
        System.AssertNotEquals(null, UTIL_CurrencyCache.getInstance().getRateMapForCurrencies(new List<String>{'CAD'}));

        // Wipe the cahce and confirm it's wiped
        UTIL_CurrencyCache.getInstance().resetCurrencyCache();
        System.AssertEquals(0, UTIL_CurrencyCache.cachedMapOfRatesByCurrencyCode.size(), 'The cache should be empty');
    }

    /**
     * @description Generate a set of effective dates and somewhat random exchange rates to
     * use for testing.
     * @param Start Date and Starting Value
     */
    private static UTIL_CurrencyCache.CurrencyData getDummyRates(Date startDt, Decimal seedValue) {
        List<Date> dts = new List<Date>();
        List<Decimal> rates = new List<Decimal>();
        Date dt = startDt;
        Decimal rtStart = seedValue;
        Decimal rt = rtStart;
        while (dt < Date.Today()) {
            dts.add(dt);
            rates.add(rt);
            dt = dt.addMonths(1);
            Decimal multiplier = (Math.random() > 0.5 ? 1 : -1);
            rt = ((rtStart + ((Math.random()/100) * multiplier))*1000000).round(System.RoundingMode.HALF_UP);
            rt = rt.divide(1000000,4);
        }
        UTIL_CurrencyCache.CurrencyData currData = new UTIL_CurrencyCache.CurrencyData();
        currData.effectiveDates = dts;
        currData.rates = rates;
        currData.defaultRate = seedValue;
        return currData;
    }

    /**
     * @description A mock implementation of UTIL_CurrencyCache.Interface_x that can
     * be used to provide pre-set return values from methods and store
     * parameters passed to methods.
     */
    public class UtilCurrencyCacheMock implements UTIL_CurrencyCache.Interface_x {
        public Boolean isOrgCacheAvailableReturn;
        public List<Date> effectiveDatesReturn;
        public List<Decimal> effectiveRatesReturn;
        public Decimal defaultRate;
        public String orgDefaultCurrencyReturn;

        public boolean isOrgCacheAvailable() {
            return isOrgCacheAvailableReturn;
        }

        public void resetCurrencyCache() {
            UTIL_CurrencyCache.cachedMapOfRatesByCurrencyCode.clear();
        }

        public Map<String, UTIL_CurrencyCache.CurrencyData> getRateMapForCurrencies(List<String> currCodes) {
            Map<String, UTIL_CurrencyCache.CurrencyData> mapOfCurrencyDataByCurrencyCode
                    = new Map<String, UTIL_CurrencyCache.CurrencyData>();

            UTIL_CurrencyCache.CurrencyData currData = new UTIL_CurrencyCache.CurrencyData();
            currData.effectiveDates = effectiveDatesReturn;
            currData.rates = effectiveRatesReturn;
            currData.defaultRate = defaultRate;

            mapOfCurrencyDataByCurrencyCode.put(currCodes[0], currData);
            return mapOfCurrencyDataByCurrencyCode;
        }

        public Integer getCurrDecimalPlaces(String currCode) {
            return 2;
        }
    }
}