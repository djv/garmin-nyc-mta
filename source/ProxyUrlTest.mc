using Toybox.Application;
using Toybox.Test;

(:test)
function proxyUrlMigration(logger) {
    var saved = Application.Properties.getValue("proxyUrl");
    try {
        Application.Properties.setValue("proxyUrl", MtaClient.LEGACY_BASE_URL);
        Test.assert(MtaClient.baseUrl().equals(MtaClient.FALLBACK_BASE_URL));
        Test.assert(Application.Properties.getValue("proxyUrl").equals(MtaClient.FALLBACK_BASE_URL));
        var custom = "https://custom.example.net";
        Application.Properties.setValue("proxyUrl", custom);
        Test.assert(MtaClient.baseUrl().equals(custom));
        Test.assert(Application.Properties.getValue("proxyUrl").equals(custom));
        Application.Properties.setValue("proxyUrl", "");
        Test.assert(MtaClient.baseUrl().equals(MtaClient.FALLBACK_BASE_URL));
    } finally {
        Application.Properties.setValue("proxyUrl", saved);
    }
    return true;
}
