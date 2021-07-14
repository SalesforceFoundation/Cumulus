public with sharing class GiftTemplate {

    private GE_Template.Template template;
    private static final String ELEVATE_WIDGET_COMPONENT_NAME = 'geFormWidgetTokenizeCard';

    public GiftTemplate() {
        this.template = defaultFormTemplate();
    }

    public GiftTemplate(String templateJSON) {
        this.template = (GE_Template.Template) JSON.deserialize(
            templateJSON,
            GE_Template.Template.class);
    }

    public GE_Template.Template template() {
        return this.template;
    }

    public List<String> giftFieldApiNames() {
        return this.template.giftFieldApiNames();
    }

    public Boolean hasElevateWidget() {
        Boolean hasWidget = false;
        for (GE_Template.Section section : template.layout.sections) {
            for (GE_Template.Element element : section.elements) {
                if (isElevateWidget(element)) {
                    hasWidget = true;
                }
            }
        }
        return hasWidget;
    }

    private GE_Template.Template defaultFormTemplate() {
        Form_Template__c defaultFormTemplate = queryDefaultFormTemplate();
        return (GE_Template.Template)
            JSON.deserialize(defaultFormTemplate.Template_JSON__c, GE_Template.Template.class);
    }

    private Form_Template__c queryDefaultFormTemplate() {
        Gift_Entry_Settings__c giftEntrySettings = getGiftEntrySettings();
        List<Form_Template__c> formTemplates = [
            SELECT Id, Name, Format_Version__c, Template_JSON__c
            FROM Form_Template__c
            WHERE Id =: giftEntrySettings.Default_Gift_Entry_Template__c
            WITH SECURITY_ENFORCED
        ];

        if (formTemplates.size() == 1) {
            return formTemplates[0];
        }
        return null;
    }

    private Gift_Entry_Settings__c getGiftEntrySettings() {
        GE_Template.createDefaultTemplateIfNecessary();
        Gift_Entry_Settings__c giftEntryCustomSetting = UTIL_CustomSettingsFacade.getGiftEntrySettings();
        return giftEntryCustomSetting;
    }

    private Boolean isElevateWidget(GE_Template.Element element) {
        return element.componentName != null
            && element.componentName == ELEVATE_WIDGET_COMPONENT_NAME;
    }
}