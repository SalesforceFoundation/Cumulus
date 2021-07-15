// Import utility method
import { format } from 'c/utilCommon';

// Import custom labels
import bgeGridNoGiftsBody from '@salesforce/label/c.bgeGridNoGiftsBody';
import bgeGridNoGiftsHeader from '@salesforce/label/c.bgeGridNoGiftsHeader';
import commonAmount from '@salesforce/label/c.commonAmount';
import commonAssistiveError from '@salesforce/label/c.commonAssistiveError';
import commonAssistiveInfo from '@salesforce/label/c.commonAssistiveInfo';
import commonAssistiveSuccess from '@salesforce/label/c.commonAssistiveSuccess';
import commonAssistiveWarning from '@salesforce/label/c.commonAssistiveWarning';
import commonBack from '@salesforce/label/c.commonBack';
import commonBatches from '@salesforce/label/c.commonBatches';
import commonCVV from '@salesforce/label/c.commonCVV';
import commonCancel from '@salesforce/label/c.commonCancel';
import commonCardLast4 from '@salesforce/label/c.commonCardLast4';
import commonCardType from '@salesforce/label/c.commonCardType';
import commonClone from '@salesforce/label/c.commonClone';
import commonCreditNumber from '@salesforce/label/c.commonCreditNumber';
import commonCriticalError from '@salesforce/label/c.commonCriticalError';
import commonDefaultValue from '@salesforce/label/c.commonDefaultValue';
import commonDelete from '@salesforce/label/c.commonDelete';
import commonEdit from '@salesforce/label/c.commonEdit';
import commonEditPaymentInformation from '@salesforce/label/c.commonEditPaymentInformation';
import commonError from '@salesforce/label/c.commonError';
import commonFieldLabel from '@salesforce/label/c.commonFieldLabel';
import commonFieldNotFound from '@salesforce/label/c.commonFieldNotFound';
import commonFieldsNotFound from '@salesforce/label/c.commonFieldsNotFound';
import commonGauAllocations from '@salesforce/label/c.commonGauAllocations';
import commonGeneralAccountUnit from '@salesforce/label/c.commonGeneralAccountUnit';
import commonLabelNone from '@salesforce/label/c.stgLabelNone';
import commonMMYY from '@salesforce/label/c.commonMMYY';
import commonMissingRequiredFields from '@salesforce/label/c.commonMissingRequiredFields';
import commonNewGift from '@salesforce/label/c.commonNewGift';
import commonNext from '@salesforce/label/c.commonNext';
import commonNo from '@salesforce/label/c.commonNo';
import commonNoItems from '@salesforce/label/c.commonNoItems';
import commonOkay from '@salesforce/label/c.commonOkay';
import commonPaymentServices from '@salesforce/label/c.commonPaymentServices';
import commonPercent from '@salesforce/label/c.commonPercent';
import commonPermissionErrorMessage from '@salesforce/label/c.commonPermissionErrorMessage';
import commonReadMore from '@salesforce/label/c.commonReadMore';
import commonRequired from '@salesforce/label/c.commonRequired';
import commonReviewForm from '@salesforce/label/c.commonReviewForm';
import commonSave from '@salesforce/label/c.commonSave';
import commonSaveAndClose from '@salesforce/label/c.commonSaveAndClose';
import commonSoftCredits from '@salesforce/label/c.commonSoftCredits';
import commonTemplate from '@salesforce/label/c.commonTemplate';
import commonTemplates from '@salesforce/label/c.commonTemplates';
import commonUnknownError from '@salesforce/label/c.commonUnknownError';
import commonUpdate from '@salesforce/label/c.commonUpdate';
import commonViewAll from '@salesforce/label/c.commonViewAll';
import commonViewMore from '@salesforce/label/c.commonViewMore';
import commonWarning from '@salesforce/label/c.commonWarning';
import commonYes from '@salesforce/label/c.commonYes';
import geAddNewAllocation from '@salesforce/label/c.geAddNewAllocation';
import geAddSoftCredit from '@salesforce/label/c.geAddSoftCredit';
import geAssistiveActiveSection from '@salesforce/label/c.geAssistiveActiveSection';
import geAssistiveBatchHeaderRemoveField from '@salesforce/label/c.geAssistiveBatchHeaderRemoveField';
import geAssistiveDescriptionFieldOptional from '@salesforce/label/c.geAssistiveDescriptionFieldOptional';
import geAssistiveDescriptionFieldRequired from '@salesforce/label/c.geAssistiveDescriptionFieldRequired';
import geAssistiveFieldDown from '@salesforce/label/c.geAssistiveFieldDown';
import geAssistiveFieldUp from '@salesforce/label/c.geAssistiveFieldUp';
import geAssistiveFormFieldsCollapseAll from '@salesforce/label/c.geAssistiveFormFieldsCollapseAll';
import geAssistiveFormFieldsExpandAll from '@salesforce/label/c.geAssistiveFormFieldsExpandAll';
import geAssistiveFormFieldsRemoveField from '@salesforce/label/c.geAssistiveFormFieldsRemoveField';
import geAssistiveFormFieldsSectionEdit from '@salesforce/label/c.geAssistiveFormFieldsSectionEdit';
import geAssistiveModalCancelAndDiscard from '@salesforce/label/c.geAssistiveModalCancelAndDiscard';
import geAssistiveRemoveSelectedOption from '@salesforce/label/c.geAssistiveRemoveSelectedOption';
import geAssistiveRequireField from '@salesforce/label/c.geAssistiveRequireField';
import geAssistiveSectionDown from '@salesforce/label/c.geAssistiveSectionDown';
import geAssistiveSectionUp from '@salesforce/label/c.geAssistiveSectionUp';
import geAssistiveShowMenu from '@salesforce/label/c.geAssistiveShowMenu';
import geAssistiveSpinner from '@salesforce/label/c.geAssistiveSpinner';
import geAuthorizedCreditCardSuccess from '@salesforce/label/c.geAuthorizedCreditCardSuccess';
import geAuthorizingCreditCard from '@salesforce/label/c.geAuthorizingCreditCard';
import geBatchProcessingSuccess from'@salesforce/label/c.geBatchProcessingSuccess';
import geBodyAdvancedFieldMapping from '@salesforce/label/c.geBodyAdvancedFieldMapping';
import geBodyBatchDefaultValues from '@salesforce/label/c.geBodyBatchDefaultValues';
import geBodyBatchFieldBundleInfo from '@salesforce/label/c.geBodyBatchFieldBundleInfo';
import geBodyBatchHeaderLeftCol from '@salesforce/label/c.geBodyBatchHeaderLeftCol';
import geBodyBatchHeaderRightCol from '@salesforce/label/c.geBodyBatchHeaderRightCol';
import geBodyBatchHeaderWarning from '@salesforce/label/c.geBodyBatchHeaderWarning';
import geBodyBatchTableColumnsPart1 from '@salesforce/label/c.geBodyBatchTableColumnsPart1';
import geBodyBatchTableColumnsPart2 from '@salesforce/label/c.geBodyBatchTableColumnsPart2';
import geBodyEmptyFormSection from '@salesforce/label/c.geBodyEmptyFormSection';
import geBodyFieldBundlesLeftCol from '@salesforce/label/c.geBodyFieldBundlesLeftCol';
import geBodyFormFieldsDescLeftCol from '@salesforce/label/c.geBodyFormFieldsDescLeftCol';
import geBodyFormFieldsLeftCol from '@salesforce/label/c.geBodyFormFieldsLeftCol';
import geBodyFormFieldsLeftColAdditional from '@salesforce/label/c.geBodyFormFieldsLeftColAdditional';
import geBodyFormFieldsModalDeleteSection from '@salesforce/label/c.geBodyFormFieldsModalDeleteSection';
import geBodyFormFieldsRightCol from '@salesforce/label/c.geBodyFormFieldsRightCol';
import geBodyMatchingApplyNewPayment from '@salesforce/label/c.geBodyMatchingApplyNewPayment';
import geBodyMatchingNewOpportunity from '@salesforce/label/c.geBodyMatchingNewOpportunity';
import geBodyMatchingNoPayments from '@salesforce/label/c.geBodyMatchingNoPayments';
import geBodyMatchingPendingDonation from '@salesforce/label/c.geBodyMatchingPendingDonation';
import geBodyMatchingSelectRecord from '@salesforce/label/c.geBodyMatchingSelectRecord';
import geBodyMatchingUpdatingDonation from '@salesforce/label/c.geBodyMatchingUpdatingDonation';
import geBodyPaymentNotProcessingTransaction from '@salesforce/label/c.geBodyPaymentNotProcessingTransaction';
import geBodyPaymentProcessedDuringBatchProcessing from '@salesforce/label/c.geBodyPaymentProcessedDuringBatchProcessing';
import geBodyTemplateInfoLeftCol from '@salesforce/label/c.geBodyTemplateInfoLeftCol';
import geBodyTemplatesTabDescription from '@salesforce/label/c.geBodyTemplatesTabDescription';
import geBodyWidgetFields from '@salesforce/label/c.geBodyWidgetFields';
import geButtonBuilderNavBackFormFields from '@salesforce/label/c.geButtonBuilderNavBackFormFields';
import geButtonBuilderNavBackTemplateInfo from '@salesforce/label/c.geButtonBuilderNavBackTemplateInfo';
import geButtonBuilderNavBatchHeader from '@salesforce/label/c.geButtonBuilderNavBatchHeader';
import geButtonBuilderNavFormFields from '@salesforce/label/c.geButtonBuilderNavFormFields';
import geButtonCancelAndClear from '@salesforce/label/c.geButtonCancelAndClear';
import geButtonFormFieldsAddSection from '@salesforce/label/c.geButtonFormFieldsAddSection';
import geButtonFormFieldsCollapseAll from '@salesforce/label/c.geButtonFormFieldsCollapseAll';
import geButtonFormFieldsDisplayOptionCollapsed from '@salesforce/label/c.geButtonFormFieldsDisplayOptionCollapsed';
import geButtonFormFieldsDisplayOptionExpanded from '@salesforce/label/c.geButtonFormFieldsDisplayOptionExpanded';
import geButtonFormFieldsExpandAll from '@salesforce/label/c.geButtonFormFieldsExpandAll';
import geButtonFormFieldsModalDeleteSectionAndFields from '@salesforce/label/c.geButtonFormFieldsModalDeleteSectionAndFields';
import geButtonMatchingNewOpportunity from '@salesforce/label/c.geButtonMatchingNewOpportunity';
import geButtonMatchingNewPayment from '@salesforce/label/c.geButtonMatchingNewPayment';
import geButtonMatchingReviewDonations from '@salesforce/label/c.geButtonMatchingReviewDonations';
import geButtonMatchingUpdateDonationSelection from '@salesforce/label/c.geButtonMatchingUpdateDonationSelection';
import geButtonMatchingUpdateOpportunity from '@salesforce/label/c.geButtonMatchingUpdateOpportunity';
import geButtonMatchingUpdatePayment from '@salesforce/label/c.geButtonMatchingUpdatePayment';
import geButtonNewBatch from '@salesforce/label/c.geButtonNewBatch';
import geButtonNewSingleGift from '@salesforce/label/c.geButtonNewSingleGift';
import geButtonPaymentAlternate from '@salesforce/label/c.geButtonPaymentAlternate';
import geButtonPaymentDoNotCharge from '@salesforce/label/c.geButtonPaymentDoNotCharge';
import geButtonSaveNewGift from '@salesforce/label/c.geButtonSaveNewGift';
import geButtonTemplatesTabCreateTemplate from '@salesforce/label/c.geButtonTemplatesTabCreateTemplate';
import geDonationColumnLabel from '@salesforce/label/c.geDonationColumnLabel';
import geDonorColumnLabel from '@salesforce/label/c.geDonorColumnLabel';
import geErrorAmountDoesNotMatch from '@salesforce/label/c.geErrorAmountDoesNotMatch';
import geErrorBatchGiftEntryCurrencyMismatch from '@salesforce/label/c.geErrorBatchGiftEntryCurrencyMismatch';
import geErrorCardChargedBDIFailed from '@salesforce/label/c.geErrorCardChargedBDIFailed';
import geErrorCompleteThisField from '@salesforce/label/c.geErrorCompleteThisField';
import geErrorDonorTypeInvalid from '@salesforce/label/c.geErrorDonorTypeInvalid';
import geErrorDonorTypeValidation from '@salesforce/label/c.geErrorDonorTypeValidation';
import geErrorDonorTypeValidationSingle from '@salesforce/label/c.geErrorDonorTypeValidationSingle';
import geErrorExistingTemplateName from '@salesforce/label/c.geErrorExistingTemplateName';
import geErrorFLSBatchTableColumns from '@salesforce/label/c.geErrorFLSBatchTableColumns';
import geErrorFLSBody from '@salesforce/label/c.geErrorFLSBody';
import geErrorFLSHeader from '@salesforce/label/c.geErrorFLSHeader';
import geErrorFieldPermission from '@salesforce/label/c.geErrorFieldPermission';
import geErrorObjectCRUDBody from '@salesforce/label/c.geErrorObjectCRUDBody';
import geErrorObjectCRUDHeader from '@salesforce/label/c.geErrorObjectCRUDHeader';
import geErrorPageLevelAdvancedMappingBody from '@salesforce/label/c.geErrorPageLevelAdvancedMappingBody';
import geErrorPageLevelAdvancedMappingHeader from '@salesforce/label/c.geErrorPageLevelAdvancedMappingHeader';
import geErrorPageLevelFieldPermission1 from '@salesforce/label/c.geErrorPageLevelFieldPermission1';
import geErrorPageLevelFieldPermission2 from '@salesforce/label/c.geErrorPageLevelFieldPermission2';
import geErrorPageLevelMissingRequiredFields from '@salesforce/label/c.geErrorPageLevelMissingRequiredFields';
import geErrorPageLevelMissingRequiredGroupFields from '@salesforce/label/c.geErrorPageLevelMissingRequiredGroupFields';
import geErrorRequiredField from '@salesforce/label/c.geErrorRequiredField';
import geErrorUncertainCardChargePart1 from '@salesforce/label/c.geErrorUncertainCardChargePart1';
import geErrorUncertainCardChargePart2 from '@salesforce/label/c.geErrorUncertainCardChargePart2';
import geErrorUncertainCardChargePart3 from '@salesforce/label/c.geErrorUncertainCardChargePart3';
import geErrorUncertainCardChargePart4 from '@salesforce/label/c.geErrorUncertainCardChargePart4';
import geFieldsNotFoundMessage from '@salesforce/label/c.geFieldsNotFoundMessage';
import geHeaderAdvancedFormFields from '@salesforce/label/c.geHeaderAdvancedFormFields';
import geHeaderBatchEnterInfo from '@salesforce/label/c.geHeaderBatchEnterInfo';
import geHeaderBatchGiftEntry from '@salesforce/label/c.geHeaderBatchGiftEntry';
import geHeaderBatchHeaderLeftCol from '@salesforce/label/c.geHeaderBatchHeaderLeftCol';
import geHeaderBatchHeaderRightCol from '@salesforce/label/c.geHeaderBatchHeaderRightCol';
import geHeaderBatchSelectTemplate from '@salesforce/label/c.geHeaderBatchSelectTemplate';
import geHeaderBatchSetDefaultValues from '@salesforce/label/c.geHeaderBatchSetDefaultValues';
import geHeaderCustomTableHeaders from '@salesforce/label/c.geHeaderCustomTableHeaders';
import geHeaderEmptyFormSection from '@salesforce/label/c.geHeaderEmptyFormSection';
import geHeaderFieldBundles from '@salesforce/label/c.geHeaderFieldBundles';
import geHeaderFormFieldsDefaultSectionName from '@salesforce/label/c.geHeaderFormFieldsDefaultSectionName';
import geHeaderFormFieldsLeftCol from '@salesforce/label/c.geHeaderFormFieldsLeftCol';
import geHeaderFormFieldsModalDeleteSection from '@salesforce/label/c.geHeaderFormFieldsModalDeleteSection';
import geHeaderFormFieldsModalDisplayOptionsSection from '@salesforce/label/c.geHeaderFormFieldsModalDisplayOptionsSection';
import geHeaderFormFieldsModalRenameSection from '@salesforce/label/c.geHeaderFormFieldsModalRenameSection';
import geHeaderFormFieldsModalSectionSettings from '@salesforce/label/c.geHeaderFormFieldsModalSectionSettings';
import geHeaderFormFieldsRightCol from '@salesforce/label/c.geHeaderFormFieldsRightCol';
import geHeaderGiftEntry from '@salesforce/label/c.geHeaderGiftEntry';
import geHeaderMatchingGiftBy from '@salesforce/label/c.geHeaderMatchingGiftBy';
import geHeaderMatchingOpportunity from '@salesforce/label/c.geHeaderMatchingOpportunity';
import geHeaderMatchingPayment from '@salesforce/label/c.geHeaderMatchingPayment';
import geHeaderMatchingReviewDonations from '@salesforce/label/c.geHeaderMatchingReviewDonations';
import geHeaderNewSection from '@salesforce/label/c.geHeaderNewSection';
import geHeaderNewTemplate from '@salesforce/label/c.geHeaderNewTemplate';
import geHeaderPageLevelError from '@salesforce/label/c.geHeaderPageLevelError';
import geHeaderPaymentServices from '@salesforce/label/c.geHeaderPaymentServices';
import geHeaderSingleGiftEntry from '@salesforce/label/c.geHeaderSingleGiftEntry';
import geHeaderTemplateInfoLeftCol from '@salesforce/label/c.geHeaderTemplateInfoLeftCol';
import geHelpTextAccount1Mapping from '@salesforce/label/c.geHelpTextAccount1Mapping';
import geHelpTextAccount2Mapping from '@salesforce/label/c.geHelpTextAccount2Mapping';
import geHelpTextAddressMapping from '@salesforce/label/c.geHelpTextAddressMapping';
import geHelpTextAllocation1Mapping from '@salesforce/label/c.geHelpTextAllocation1Mapping';
import geHelpTextAllocation2Mapping from '@salesforce/label/c.geHelpTextAllocation2Mapping';
import geHelpTextAllocationBundle from '@salesforce/label/c.geHelpTextAllocationBundle';
import geHelpTextBatchHeaderFieldLabelLabel from '@salesforce/label/c.geHelpTextBatchHeaderFieldLabelLabel';
import geHelpTextContact1Mapping from '@salesforce/label/c.geHelpTextContact1Mapping';
import geHelpTextContact2Mapping from '@salesforce/label/c.geHelpTextContact2Mapping';
import geHelpTextFormFieldsFieldCustomLabel from '@salesforce/label/c.geHelpTextFormFieldsFieldCustomLabel';
import geHelpTextFormFieldsFieldLabelLabel from '@salesforce/label/c.geHelpTextFormFieldsFieldLabelLabel';
import geHelpTextHouseholdMapping from '@salesforce/label/c.geHelpTextHouseholdMapping';
import geHelpTextPaymentServices from '@salesforce/label/c.geHelpTextPaymentServices';
import geLabelCustomTableSelectedFields from '@salesforce/label/c.geLabelCustomTableSelectedFields';
import geLabelCustomTableSourceFields from '@salesforce/label/c.geLabelCustomTableSourceFields';
import geLabelDisplaySections from '@salesforce/label/c.geLabelDisplaySections';
import geLabelSectionName from '@salesforce/label/c.geLabelSectionName';
import geLabelTemplateInfoDescriptionField from '@salesforce/label/c.geLabelTemplateInfoDescriptionField';
import geLabelTemplateInfoNameField from '@salesforce/label/c.geLabelTemplateInfoNameField';
import gePaymentAuthExpiredHeader from '@salesforce/label/c.gePaymentAuthExpiredHeader';
import gePaymentAuthExpiredWarningText from '@salesforce/label/c.gePaymentAuthExpiredWarningText';
import gePaymentProcessedWarning from '@salesforce/label/c.gePaymentProcessedWarning';
import gePaymentProcessError from '@salesforce/label/c.gePaymentProcessError';
import gePaymentProcessingErrorBanner from '@salesforce/label/c.gePaymentProcessingErrorBanner';
import gePaymentRequestTimedOut from '@salesforce/label/c.gePaymentRequestTimedOut';
import geProcessAnyway from '@salesforce/label/c.geProcessAnyway';
import geProcessingBatch from '@salesforce/label/c.geProcessingBatch';
import geProcessingErrors from '@salesforce/label/c.geProcessingErrors';
import geSearchPlaceholder from '@salesforce/label/c.geSearchPlaceholder';
import geSelectBatchTableColumns from '@salesforce/label/c.geSelectBatchTableColumns';
import geSelectPlaceholder from '@salesforce/label/c.geSelectPlaceholder';
import geTabBatchHeader from '@salesforce/label/c.geTabBatchHeader';
import geTabBatchSettings from '@salesforce/label/c.geTabBatchSettings';
import geTabBatchTableColumns from '@salesforce/label/c.geTabBatchTableColumns';
import geTabFormFields from '@salesforce/label/c.geTabFormFields';
import geTabTemplateInfo from '@salesforce/label/c.geTabTemplateInfo';
import geTextChargingCard from '@salesforce/label/c.geTextChargingCard';
import geTextFieldBundlePaymentMethod from '@salesforce/label/c.geTextFieldBundlePaymentMethod';
import geTextListViewItemCount from '@salesforce/label/c.geTextListViewItemCount';
import geTextListViewItemsCount from '@salesforce/label/c.geTextListViewItemsCount';
import geTextListViewSortedBy from '@salesforce/label/c.geTextListViewSortedBy';
import geTextListViewUpdatedAgo from '@salesforce/label/c.geTextListViewUpdatedAgo';
import geTextNavigateToOpportunity from '@salesforce/label/c.geTextNavigateToOpportunity';
import geTextPaymentsSaveNotice from '@salesforce/label/c.geTextPaymentsSaveNotice';
import geTextProcessing from '@salesforce/label/c.geTextProcessing';
import geTextSaving from '@salesforce/label/c.geTextSaving';
import geTextUpdating from '@salesforce/label/c.geTextUpdating';
import geToastListViewUpdated from '@salesforce/label/c.geToastListViewUpdated';
import geToastSaveFailed from '@salesforce/label/c.geToastSaveFailed';
import geToastSelectActiveSection from '@salesforce/label/c.geToastSelectActiveSection';
import geToastTemplateCreateSuccess from '@salesforce/label/c.geToastTemplateCreateSuccess';
import geToastTemplateDeleteSuccess from '@salesforce/label/c.geToastTemplateDeleteSuccess';
import geToastTemplateTabsError from '@salesforce/label/c.geToastTemplateTabsError';
import geToastTemplateUpdateSuccess from '@salesforce/label/c.geToastTemplateUpdateSuccess';
import geWarningBatchGiftEntryCurrencyMismatch from '@salesforce/label/c.geWarningBatchGiftEntryCurrencyMismatch';
import geWarningFormFieldsModalDeleteSection from '@salesforce/label/c.geWarningFormFieldsModalDeleteSection';
import labelBooleanFalse from '@salesforce/label/c.labelBooleanFalse';
import labelBooleanTrue from '@salesforce/label/c.labelBooleanTrue';
import psSelectValidPaymentMethod from '@salesforce/label/c.psSelectValidPaymentMethod';

class GeLabelService {

    /*******************************************************************************
    * @description Expose imported custom labels. We freeze this object because any
    * import of this service component within the same session is shared across
    * components. We disallow mutations of labels at this level. Components importing
    * the provided labels must clone in order to mutate/format the labels. A 'format'
    * utility method is provided.
    */
    CUSTOM_LABELS = Object.freeze({
        bgeGridNoGiftsBody,
        bgeGridNoGiftsHeader,
        commonAmount,
        commonAssistiveError,
        commonAssistiveInfo,
        commonAssistiveSuccess,
        commonAssistiveWarning,
        commonBack,
        commonBatches,
        commonCVV,
        commonCancel,
        commonCardLast4,
        commonCardType,
        commonClone,
        commonCreditNumber,
        commonCriticalError,
        commonDefaultValue,
        commonDelete,
        commonEdit,
        commonEditPaymentInformation,
        commonError,
        commonFieldLabel,
        commonFieldNotFound,
        commonFieldsNotFound,
        commonGauAllocations,
        commonGeneralAccountUnit,
        commonLabelNone,
        commonMMYY,
        commonMissingRequiredFields,
        commonNewGift,
        commonNext,
        commonNo,
        commonNoItems,
        commonOkay,
        commonPaymentServices,
        commonPercent,
        commonPermissionErrorMessage,
        commonReadMore,
        commonRequired,
        commonReviewForm,
        commonSave,
        commonSaveAndClose,
        commonSoftCredits,
        commonTemplate,
        commonTemplates,
        commonUnknownError,
        commonUpdate,
        commonViewAll,
        commonViewMore,
        commonWarning,
        commonYes,
        geAddNewAllocation,
        geAddSoftCredit,
        geAssistiveActiveSection,
        geAssistiveBatchHeaderRemoveField,
        geAssistiveDescriptionFieldOptional,
        geAssistiveDescriptionFieldRequired,
        geAssistiveFieldDown,
        geAssistiveFieldUp,
        geAssistiveFormFieldsCollapseAll,
        geAssistiveFormFieldsExpandAll,
        geAssistiveFormFieldsRemoveField,
        geAssistiveFormFieldsSectionEdit,
        geAssistiveModalCancelAndDiscard,
        geAssistiveRemoveSelectedOption,
        geAssistiveRequireField,
        geAssistiveSectionDown,
        geAssistiveSectionUp,
        geAssistiveShowMenu,
        geAssistiveSpinner,
        geAuthorizedCreditCardSuccess,
        geAuthorizingCreditCard,
        geBatchProcessingSuccess,
        geBodyAdvancedFieldMapping,
        geBodyBatchDefaultValues,
        geBodyBatchFieldBundleInfo,
        geBodyBatchHeaderLeftCol,
        geBodyBatchHeaderRightCol,
        geBodyBatchHeaderWarning,
        geBodyBatchTableColumnsPart1,
        geBodyBatchTableColumnsPart2,
        geBodyEmptyFormSection,
        geBodyFieldBundlesLeftCol,
        geBodyFormFieldsDescLeftCol,
        geBodyFormFieldsLeftCol,
        geBodyFormFieldsLeftColAdditional,
        geBodyFormFieldsModalDeleteSection,
        geBodyFormFieldsRightCol,
        geBodyMatchingApplyNewPayment,
        geBodyMatchingNewOpportunity,
        geBodyMatchingNoPayments,
        geBodyMatchingPendingDonation,
        geBodyMatchingSelectRecord,
        geBodyMatchingUpdatingDonation,
        geBodyPaymentNotProcessingTransaction,
        geBodyPaymentProcessedDuringBatchProcessing,
        geBodyTemplateInfoLeftCol,
        geBodyTemplatesTabDescription,
        geBodyWidgetFields,
        geButtonBuilderNavBackFormFields,
        geButtonBuilderNavBackTemplateInfo,
        geButtonBuilderNavBatchHeader,
        geButtonBuilderNavFormFields,
        geButtonCancelAndClear,
        geButtonFormFieldsAddSection,
        geButtonFormFieldsCollapseAll,
        geButtonFormFieldsDisplayOptionCollapsed,
        geButtonFormFieldsDisplayOptionExpanded,
        geButtonFormFieldsExpandAll,
        geButtonFormFieldsModalDeleteSectionAndFields,
        geButtonMatchingNewOpportunity,
        geButtonMatchingNewPayment,
        geButtonMatchingReviewDonations,
        geButtonMatchingUpdateDonationSelection,
        geButtonMatchingUpdateOpportunity,
        geButtonMatchingUpdatePayment,
        geButtonNewBatch,
        geButtonNewSingleGift,
        geButtonPaymentAlternate,
        geButtonPaymentDoNotCharge,
        geButtonSaveNewGift,
        geButtonTemplatesTabCreateTemplate,
        geDonationColumnLabel,
        geDonorColumnLabel,
        geErrorAmountDoesNotMatch,
        geErrorBatchGiftEntryCurrencyMismatch,
        geErrorCardChargedBDIFailed,
        geErrorCompleteThisField,
        geErrorDonorTypeInvalid,
        geErrorDonorTypeValidation,
        geErrorDonorTypeValidationSingle,
        geErrorExistingTemplateName,
        geErrorFLSBatchTableColumns,
        geErrorFLSBody,
        geErrorFLSHeader,
        geErrorFieldPermission,
        geErrorObjectCRUDBody,
        geErrorObjectCRUDHeader,
        geErrorPageLevelAdvancedMappingBody,
        geErrorPageLevelAdvancedMappingHeader,
        geErrorPageLevelFieldPermission1,
        geErrorPageLevelFieldPermission2,
        geErrorPageLevelMissingRequiredFields,
        geErrorPageLevelMissingRequiredGroupFields,
        geErrorRequiredField,
        geErrorUncertainCardChargePart1,
        geErrorUncertainCardChargePart2,
        geErrorUncertainCardChargePart3,
        geErrorUncertainCardChargePart4,
        geFieldsNotFoundMessage,
        geHeaderAdvancedFormFields,
        geHeaderBatchEnterInfo,
        geHeaderBatchGiftEntry,
        geHeaderBatchHeaderLeftCol,
        geHeaderBatchHeaderRightCol,
        geHeaderBatchSelectTemplate,
        geHeaderBatchSetDefaultValues,
        geHeaderCustomTableHeaders,
        geHeaderEmptyFormSection,
        geHeaderFieldBundles,
        geHeaderFormFieldsDefaultSectionName,
        geHeaderFormFieldsLeftCol,
        geHeaderFormFieldsModalDeleteSection,
        geHeaderFormFieldsModalDisplayOptionsSection,
        geHeaderFormFieldsModalRenameSection,
        geHeaderFormFieldsModalSectionSettings,
        geHeaderFormFieldsRightCol,
        geHeaderGiftEntry,
        geHeaderMatchingGiftBy,
        geHeaderMatchingOpportunity,
        geHeaderMatchingPayment,
        geHeaderMatchingReviewDonations,
        geHeaderNewSection,
        geHeaderNewTemplate,
        geHeaderPageLevelError,
        geHeaderPaymentServices,
        geHeaderSingleGiftEntry,
        geHeaderTemplateInfoLeftCol,
        geHelpTextAccount1Mapping,
        geHelpTextAccount2Mapping,
        geHelpTextAddressMapping,
        geHelpTextAllocation1Mapping,
        geHelpTextAllocation2Mapping,
        geHelpTextAllocationBundle,
        geHelpTextBatchHeaderFieldLabelLabel,
        geHelpTextContact1Mapping,
        geHelpTextContact2Mapping,
        geHelpTextFormFieldsFieldCustomLabel,
        geHelpTextFormFieldsFieldLabelLabel,
        geHelpTextHouseholdMapping,
        geHelpTextPaymentServices,
        geLabelCustomTableSelectedFields,
        geLabelCustomTableSourceFields,
        geLabelDisplaySections,
        geLabelSectionName,
        geLabelTemplateInfoDescriptionField,
        geLabelTemplateInfoNameField,
        gePaymentAuthExpiredHeader,
        gePaymentAuthExpiredWarningText,
        gePaymentProcessedWarning,
        gePaymentProcessError,
        gePaymentProcessingErrorBanner,
        gePaymentRequestTimedOut,
        geProcessAnyway,
        geProcessingBatch,
        geProcessingErrors,
        geSearchPlaceholder,
        geSelectBatchTableColumns,
        geSelectPlaceholder,
        geTabBatchHeader,
        geTabBatchSettings,
        geTabBatchTableColumns,
        geTabFormFields,
        geTabTemplateInfo,
        geTextChargingCard,
        geTextFieldBundlePaymentMethod,
        geTextListViewItemCount,
        geTextListViewItemsCount,
        geTextListViewSortedBy,
        geTextListViewUpdatedAgo,
        geTextNavigateToOpportunity,
        geTextPaymentsSaveNotice,
        geTextProcessing,
        geTextSaving,
        geTextUpdating,
        geToastListViewUpdated,
        geToastSaveFailed,
        geToastSelectActiveSection,
        geToastTemplateCreateSuccess,
        geToastTemplateDeleteSuccess,
        geToastTemplateTabsError,
        geToastTemplateUpdateSuccess,
        geWarningBatchGiftEntryCurrencyMismatch,
        geWarningFormFieldsModalDeleteSection,
        labelBooleanFalse,
        labelBooleanTrue,
        psSelectValidPaymentMethod,
    });

    /*******************************************************************************
    * @description Pass through method for imported 'format' utility method.
    * Javascript method comparable to Apex's String.format(...).
    * Replaces placeholders in Custom Labels ({0}, {1}, etc) with provided values.
    *
    * @param {string} string: Custom Label to be formatted.
    * @param {list} replacements: List of string to use as replacements.
    * @return {string} formattedString: Formatted custom label
    */
    format = (string, replacements) => format(string, replacements);
}

export default new GeLabelService();
