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
* @description Utilities for working with the currency exchange rate organization cahce
*/
public class UTIL_CurrencyCache implements UTIL_CurrencyCache.Interface_x {

    // ====================================================================
    // STATIC VARS USED TO HOLD VALUES THROUGH THE EXECUTION CONTEXT
    // ====================================================================

    /**
     * @description Cache of rates/effective dates by currency iso code
     */
    @TestVisible
    private static Map<String, UTIL_CurrencyCache.CurrencyData> cachedMapOfRatesByCurrencyCode =
            new Map<String, UTIL_CurrencyCache.CurrencyData>();

    /* Retrieve and cache the household settings the first time this class is loaded only */
    private static final npo02__Households_Settings__c householdSettings = UTIL_CustomSettingsFacade.getHouseholdsSettings();

    /* Platform Cache */
    private static UTIL_PlatformCache platformCache = UTIL_PlatformCache.getInstance();

    // ====================================================================
    // PRIMARY EXPOSED STATIC METHODS
    // ====================================================================

    /**
     * @description Return a specific exchange rate from the cache for the specified currency code and effective date.
     * @param currCode - The currency to retrieve a rate for
     * @param dt - Effective Date to find a rate for. Use null to return the org's default rate for this currency.
     * @return Exchange Rate
     */
    public static Decimal getEffectiveExchangeRate(String currCode, Date dt) {

        if (currCode != null) {

            // If the target currency is the org default currency, then always return 1 as the exchange rate
            if (currCode == UTIL_Currency.getInstance().getOrgDefaultCurrency()) {
                return 1;
            }

            // If the current static var cache does not have a value for the CurrencyCode
            // look in the Platform cache first (if available) and if not retrieve from the database.
            if (!cachedMapOfRatesByCurrencyCode.containsKey(currCode)) {
                retrieveAndCacheExchangeRates(currCode);
            }

            // If a set of rates was retrieved, find the effective rate based on the date
            if (cachedMapOfRatesByCurrencyCode.containsKey(currCode)) {
                UTIL_CurrencyCache.CurrencyData currData = cachedMapOfRatesByCurrencyCode.get(currCode);

                if (currData == null) {
                    return 1;
                }

                if (dt == null || currData.rates.size() == 0) {
                    return currData.defaultRate;
                }

                // The list of effective dates is in descending date order
                for (Integer n = 0; n < currData.effectiveDates.size(); n++) {
                    if (dt >= currData.effectiveDates[n]) {
                        return currData.rates[n];
                    }
                }
            }
        }

        // TODO: no rate found - now what? Throw an exception maybe; or just return 1?
        return 1;
    }

    /**
     * @description If the currency has not already been cached - either in the org cache or the static var,
     * initiate the appropriate retrieve and storage actions.
     * @returns nothing
     */
    private static void retrieveAndCacheExchangeRates(String currCode) {
        if (getInstance().isOrgCacheAvailable()) {
            cachedMapOfRatesByCurrencyCode.put(currCode, (UTIL_CurrencyCache.CurrencyData) orgCache.get(CurrencyCache.class, currCode));
        } else {
            cachedMapOfRatesByCurrencyCode.put(currCode, getInstance().getRateMapForCurrencies(new List<String>{
                    currCode
            }).get(currCode));
        }
    }

    /**
     * @description Returns the OrganizationCache object from the UTIL_PlatformCache class
     * or null if there is no npsp org cache available to use.
     */
    public static Cache.OrgPartition orgCache {
        get {
            return platformCache.orgCache;
        } private set;
    }

    /**
     * @description Returns the organizations default currency code (i.e., "Corporate" or "Home" Currency)
     */
    private static String orgDefaultCurrencyCode;
    public static String getOrgDefaultCurrency() {
        if (orgDefaultCurrencyCode == null) {
            if (UserInfo.isMultiCurrencyOrganization()) {
                // First look to see if we've already retrieved/cached the org currency.
                for (String currCode : cachedMapOfRatesByCurrencyCode.keySet()) {
                    CurrencyData cd = cachedMapOfRatesByCurrencyCode.get(currCode);
                    if (cd.isOrgDefault) {
                        orgDefaultCurrencyCode = currCode;
                        break;
                    }
                }
                // If the default currency has not already been cached into the static map,
                // Query it directly from the CurrencyType object and store in a static var
                if (orgDefaultCurrencyCode == null) {
                    String soql = 'SELECT IsoCode FROM CurrencyType WHERE IsCorporate = True LIMIT 1';
                    SObject currObj = database.query(soql);
                    orgDefaultCurrencyCode = (String) currObj.get('IsoCode');
                }
            } else {
                orgDefaultCurrencyCode = '';
            }
        }
        return orgDefaultCurrencyCode;
    }

    /** @description Store instance for Singleton pattern */
    @TestVisible
    private static Interface_x instance;

    /**
     * @description Get the singleton instance of the UTIL_CurrencyCache class
     * @return UTIL_CurrencyCache.Interface_x
     */
    public static Interface_x getInstance() {
        if (instance == null) {
            instance = new UTIL_CurrencyCache();
        }
        return instance;
    }

    /** @description Private constructor for Singleton pattern */
    @TestVisible
    private UTIL_CurrencyCache() {}

    // ====================================================================
    // CACHEBUILDER CLASS TO MANAGE RETRIEVING/PUTTING ELEMENTS INTO THE CACHE
    // ====================================================================

    /**
     * @description CacheBuilder implementation to retrieve/load dates/rates by currency code
     * CacheBuilder is smart enough to use the values in the cache if they exist and if not it will call the
     * code witin the doLoad() method below to retrieve the values and then store them in the cache so they're
     * available on the next call.
     * However, if the cache isn't available at all, the cachebuilder interface cannot be used.
     */
    public class CurrencyCache implements Cache.CacheBuilder {
        public UTIL_CurrencyCache.CurrencyData doLoad(String currCode) {
            return getInstance().getRateMapForCurrencies(new List<String>{currCode}).get(currCode);
        }
    }

    // ====================================================================
    // INSTANCE METHODS IN THE INTERFACE AVAILBLE FOR MOCKING IN TESTS
    // ====================================================================

    /**
     * @description public Interface to enable mocking of this class functionality for unit tests in orgs
     * that may or may not have multicurrency and/or platform cache enabled.
     */
    public interface Interface_x {
        Boolean isOrgCacheAvailable();
        void resetCurrencyCache();
        Integer getCurrDecimalPlaces(String currCode);
        Map<String, UTIL_CurrencyCache.CurrencyData> getRateMapForCurrencies(List<String> currCodes);
    }

    /**
    * @description Returns true if an organization cache is available
    */
    public boolean isOrgCacheAvailable() {
        return platformCache.isOrgCacheAvailable();
    }

    /**
     * @description Given a list of currency codes, returns a map of effective dates and related exchange rates
     * pulling from either the CurrencyType or DatedConversionRate object.
     * @param List of currency codes to retrieve data for
     * @return Map<CurrencyCode, Map<ListTypeConstant, List<Date|Decimal>>>
     */
    public Map<String, UTIL_CurrencyCache.CurrencyData> getRateMapForCurrencies(List<String> currCodes) {

        Map<String, UTIL_CurrencyCache.CurrencyData> mapOfCurrencyDataByCurrencyCode
            = new Map<String, UTIL_CurrencyCache.CurrencyData>();

        // Even if ACM is enabled, the Admin may choose to not use dated conversion rates for roll-ups.
        Boolean useDatedConversionRates = UTIL_Currency.getInstance().isAdvancedCurrencyManagementEnabled()
            && householdSettings.Use_Dated_Conversion_Rates__c == true;

        if (useDatedConversionRates) {
            // When ACM is enabled, query the DatedConversionRate table to retrieve the effective dates
            // but only for the specific currency code requested.
            String soql = 'SELECT IsoCode, ConversionRate, StartDate ' +
                'FROM DatedConversionRate ' +
                'WHERE IsoCode IN :currCodes ' +
                'ORDER By IsoCode, StartDate DESC';
            for (SObject dcr : database.query(soql)) {

                String currCode = (String) dcr.get('IsoCode');
                UTIL_CurrencyCache.CurrencyData currData = mapOfCurrencyDataByCurrencyCode.get(currCode);
                if (currData == null) {
                    currData = new UTIL_CurrencyCache.CurrencyData();
                }

                Date dt = (Date) dcr.get('StartDate');
                Decimal rt = (Decimal) dcr.get('ConversionRate');
                currData.IsoCode = currCode;
                currData.effectiveDates.add(dt);
                currData.rates.add(rt);
                mapOfCurrencyDataByCurrencyCode.put(currCode, currData);
            }


        }
        if (UserInfo.isMultiCurrencyOrganization()) {
            // If ACM is not enabled, query the standard rate table and create a single rate
            // instance per currency code for all currency codes with an effective date of 1/1/900.
            String soql = 'SELECT IsoCode, ConversionRate, IsCorporate, DecimalPlaces FROM CurrencyType WHERE IsActive = True';
            if (useDatedConversionRates) {
                // If dated exchange rates are in affect, we still need to capture the 'default'
                // standard rate to use in the specific scenario of determing the exchange rate
                // against the legacy rollups that are based on aggragate soql.
                soql += ' AND IsoCode IN :currCodes';
            }
            for (SObject scr : database.query(soql)) {
                String currCode = (String) scr.get('IsoCode');

                UTIL_CurrencyCache.CurrencyData currData = mapOfCurrencyDataByCurrencyCode.get(currCode);
                if (currData == null) {
                    currData = new UTIL_CurrencyCache.CurrencyData();
                }

                currData.IsoCode = currCode;
                currData.defaultRate = (Decimal)scr.get('ConversionRate');
                currData.isOrgDefault = (Boolean)scr.get('IsCorporate');
                currData.decimalPlaces = (Integer)scr.get('DecimalPlaces');
                mapOfCurrencyDataByCurrencyCode.put(currCode, currData);
            }
        }
        return mapOfCurrencyDataByCurrencyCode;
    }

    /**
     * @description Retrieve the number of decimal places for the specified currency. If the currency code has not
     * already been queried and added to the static cache, do it here.
     */
    public Integer getCurrDecimalPlaces(String currCode) {
        if (!cachedMapOfRatesByCurrencyCode.containsKey(currCode)) {
            retrieveAndCacheExchangeRates(currCode);
        }
        CurrencyData cd = cachedMapOfRatesByCurrencyCode.get(currCode);
        return (cd != null ? cd.decimalPlaces : 2); // in case there is no data found for the specified currency
    }

    /**
     * @description Wipe out the org cache for all elements in the CurrencyCache CacheBuilder
     */
    public void resetCurrencyCache() {
        if (isOrgCacheAvailable()) {
            for (String key : orgCache.getKeys()) {
                orgCache.remove(CurrencyCache.class, key);
            }
        }
        UTIL_CurrencyCache.cachedMapOfRatesByCurrencyCode.clear();
    }

    /**
     * @description Inner class for dated exchange rates. The 'defaultRate' value is the default exchange rate
     * to use when dated exchange rates are no enabled AND when the getEffectiveRate() method is called with the
     * flag to retrieve only the default (non-dated) rate.
     */
    public class CurrencyData {
        public String IsoCode { get; set; }
        public List<Date> effectiveDates {get; set; }
        public List<Decimal> rates {get; set; }
        public Decimal defaultRate {get; set; }
        public Boolean isOrgDefault {get; set;}
        public Integer decimalPlaces {get; set;}

        public CurrencyData() {
            this.effectiveDates = new List<Date>();
            this.rates = new List<Decimal>();
        }
    }
}