public inherited sharing class CRLP_PlatformCache {    

    // ====================================================================
    // CACHEBUILDER CLASS TO MANAGE RETRIEVING/PUTTING ELEMENTS INTO THE CACHE
    // ====================================================================

    /**
     * @description CacheBuilder implementation to retrieve/load Rollup__Mdt records.
     * CacheBuilder is smart enough to use the values in the cache if they exist and if not it will call the
     * code witin the doLoad() method below to retrieve the values and then store them in the cache so they're
     * available on the next call.
     */
    public class RollupDefinitionsCache implements Cache.CacheBuilder {
        public List<Rollup__mdt> doLoad(String dummyParam) {
            return CRLP_Rollup_SEL.queryRollupRecords();
        }
    }

    /**
     * @description CacheBuilder implementation to retrieve/load Filter_Group__mdt records.
     */
    public class RollupFilterGroupsCache implements Cache.CacheBuilder {
        public List<Filter_Group__mdt> doLoad(String dummyParam) {
            return CMT_FilterRule_SEL.queryFilterGroupRecords();
        }
    }

    /**
     * @description CacheBuilder implementation to retrieve/load Filter_Rule__mdt records.
     */
    public class RollupFilterRulesCache implements Cache.CacheBuilder {
        public List<Filter_Rule__mdt> doLoad(String dummyParam) {
            return CMT_FilterRule_SEL.queryFilterRuleRecords();
        }
    }
}
