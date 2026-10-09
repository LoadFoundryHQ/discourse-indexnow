import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class IndexNowDashboardRoute extends Route {
  async model() {
    const [status, logs] = await Promise.all([
      ajax("/admin/plugins/indexnow/status.json"),
      ajax("/admin/plugins/indexnow/logs.json"),
    ]);

    return { status, logs: logs.logs || [] };
  }

  setupController(controller, model) {
    controller.setProperties({
      status: model.status || {},
      logs: model.logs || [],
    });
  }
}
