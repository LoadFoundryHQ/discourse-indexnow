import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class IndexNowDashboardRoute extends Route {
  async model() {
    const [status, logs, stats] = await Promise.all([
      ajax("/admin/plugins/indexnow/status.json"),
      ajax("/admin/plugins/indexnow/logs.json"),
      ajax("/admin/plugins/indexnow/stats.json"),
    ]);

    return {
      status,
      logs: logs.logs || [],
      trend: stats.trend || [],
      failures: stats.failures || [],
    };
  }

  setupController(controller, model) {
    controller.setProperties({
      status: model.status || {},
      logs: model.logs || [],
      trend: model.trend || [],
      failures: model.failures || [],
    });
  }
}
