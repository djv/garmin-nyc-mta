using Toybox.Application;
using Toybox.Lang;

// Shared by board, glance and background pack requests.
(:background)
module ProxyConfig {
    function valid(value) {
        return value instanceof Lang.String && value.length() > 8 &&
            value.find("https://") == 0 && value.find("trycloudflare.com") == null;
    }

    function baseUrl() {
        try {
            var value = Application.Properties.getValue("proxyUrl");
            if (valid(value)) { return value; }
        } catch (ex) {}
        return "";
    }
}
