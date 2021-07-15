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
* @description Utilities for working with the Platform Organization Cache
*/
public class UTIL_PlatformCache implements UTIL_PlatformCache.Interface_x {

    // ====================================================================
    // INSTANCE METHODS IN THE INTERFACE AVAILBLE FOR MOCKING IN TESTS
    // ====================================================================

    /**
     * @description public Interface to enable mocking of this class functionality for unit tests in orgs
     * that may or may not have multicurrency and/or platform cache enabled.
     */
    public interface Interface_x {
        Boolean isOrgCacheAvailable();
        void fireInvalidatePlatformCacheEvent(String context);
        void invalidatePlatformCacheImmediate();
    }


    /**
     * @description The CacheBuilder.doLoad() method always requries a string parameter, even if it's not being used
     * This acts as a placeholder for implementations of CacheBuilder that are not using the parameter
     */
    public static final String CacheBuilderStubParameter = 'npsp';

    /**
     * @description The expected name for the platform cache partition created in the customer org
     */
    private static final String NPSP_CACHE_NAME = 'local.npsp';

    /** @description Store instance for Singleton pattern; testVisible to allow for a mocked version */
    @TestVisible
    private static UTIL_PlatformCache instance;

    /**
     * @description Platform Organization Cache. This is set by isOrgCacheAvailabe() when called
     */
    public Cache.OrgPartition orgCache {
        get {
            return orgCache;
        } set;
    }

    /**
     * @description Is there a cache available?
     */
    public Boolean isOrgCacheAvailable {
        get {
            return isOrgCacheAvailable;
        } set;
    }

    /**
     * @description Has the Org Cache been retrieved? (OrgCache can still be null if there is no cache to retrieve)
     */
    private Boolean orgCacheRetrieved = false;

    /**
     * @description Get the singleton instance of the UTIL_CurrencyCache class
     * @return UTIL_CurrencyCache.Interface_x
     */
    public static UTIL_PlatformCache getInstance() {
        if (instance == null) {
            instance = new UTIL_PlatformCache();
        }
        return instance;
    }

    private UTIL_PlatformCache() {
        this.isOrgCacheAvailable = initCacheProperties();
    }

    public Boolean isOrgCacheAvailable() {
        return this.isOrgCacheAvailable;
    }

    /**
    * @description Returns true if an organization cache is available for npsp AND initializes the
    * organization cache static var above.
    */
    private Boolean initCacheProperties() {
        if (!this.orgCacheRetrieved) {
            try {
                this.orgCache = Cache.Org.getPartition(NPSP_CACHE_NAME);
            } catch (Exception ex) {
                // no cache available, so ignore the error and continue, but set the boolean var to true
                // so we don't go through this code a second time
            }
            this.orgCacheRetrieved = true;
        }
        return this.orgCache != null;
    }

    /**
     * @description Remove all CacheBuilder implementations in the current organization cache
     */
    public void fireInvalidatePlatformCacheEvent(String context) {
        CacheInvalidation__e ci = new CacheInvalidation__e(
            DataModified__c = context
        );
        EventBus.publish(ci);
    }

    /**
     * @description Remove all CacheBuilder implementations in the current organization cache
     */
    public void invalidatePlatformCacheImmediate() {
        if (!isOrgCacheAvailable() || orgCache.getKeys().size() == 0) {
          return;
        }

        orgCache.remove(UTIL_CurrencyCache.CurrencyCache.class, CacheBuilderStubParameter);
        orgCache.remove(TDTM_ObjectDataGateway.TriggerHandlerCache.class, CacheBuilderStubParameter);
        orgCache.remove(CRLP_PlatformCache.RollupDefinitionsCache.class, CacheBuilderStubParameter);

        this.orgCacheRetrieved = false;
    }
}