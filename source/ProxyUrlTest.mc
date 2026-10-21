using Toybox.Application;
using Toybox.Test;

(:test)
function proxyUrlConfiguration(logger) {
    var savedUrl = Application.Properties.getValue("proxyUrl");
    var savedKey = Application.Properties.getValue("packKey");
    try {
        Application.Properties.setValue("packKey", "test-pack-key");
        var custom = "https://custom.example.net";
        Application.Properties.setValue("proxyUrl", custom);
        Test.assert(MtaClient.baseUrl().equals(custom));
        Test.assert(PackService.url().equals(custom + "/mta/pack?key=test-pack-key"));
        Test.assert(Application.Properties.getValue("proxyUrl").equals(custom));
        var invalid = ["", "http://custom.example.net", "https://", "https://example.trycloudflare.com"];
        for (var i = 0; i < invalid.size(); i += 1) {
            Application.Properties.setValue("proxyUrl", invalid[i]);
            Test.assert(MtaClient.baseUrl().equals(""));
            Test.assert(PackService.url() == null);
            Test.assert(Application.Properties.getValue("proxyUrl").equals(invalid[i]));
        }
        Test.assert(!ProxyConfig.valid(null) && !ProxyConfig.valid(123));
        Application.Properties.setValue("proxyUrl", custom);
        Application.Properties.setValue("packKey", "");
        Test.assert(PackService.url() == null);
    } finally {
        Application.Properties.setValue("proxyUrl", savedUrl);
        Application.Properties.setValue("packKey", savedKey);
    }
    return true;
}
