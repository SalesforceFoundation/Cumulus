# Persistent Sandbox Org 

Customizable Rollup and other Batch Job performance tests are executed in a persistent "LDV" Sandbox.

Sandboxes are provisioned by the Release Engineering Team upon request.

## Sandbox Configuration:
https://salesforce.quip.com/aoqmAzdgQYJL

1. Connect the Sandbox to CCI using `cci org connect`
2. Install NPSP, ideally unmanaged
    * `cci task run max_feature_parameter_limit_work_around --org {orgalias}`
    * `cci flow run unmanaged_ee --org {orgalias}`
    * `cci flow run config_trial --org {orgalias}`
    * `cci task run npsp_default_settings --org {orgalias}`
    * `cci task run update_admin_profile —org {orgalias}`
3. Enable Enhanced Recurring Donations:
    * `cci flow run enable_rd2 --org {orgalias}`
4. Deploy additional unmanaged configuration:
    * `cci task run deploy --path unpackaged/config/config_ldv_org_for_testing --org {orgalias}`
    * `cci task run deploy --path unpackaged/config/perf_test_utils --org {orgalias}`
    * `cci task run create_permission_set --api_name BulkApiPerms --label "Bulk Api Permissions" --user_permissions PermissionsBulkApiHardDelete --org {orgalias}`
5. Create Test Data (this creates 500K contacts with approx 1.8M Opps):
   * `cci flow run ldv_test_data --org {orgalias} -o generate_and_load_from_yaml__num_records 500000`
6. Log into the Org and set any additional NPSP configuration parameters:
   * Rollup Batch Sizes
   * Other?