import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-indexnow";

export default {
  name: "indexnow-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "shield-halved");
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "indexnow.title",
          route: "adminPlugins.show.indexnow-dashboard",
          icon: "gear",
        },
      ]);
    });
  },
};
