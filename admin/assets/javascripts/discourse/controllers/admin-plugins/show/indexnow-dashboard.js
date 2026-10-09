import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class IndexNowDashboardController extends Controller {
  @tracked status = {};
  @tracked logs = [];
  @tracked trend = [];
  @tracked failures = [];

  get trendMax() {
    return Math.max(
      1,
      ...this.trend.map((day) => day.success + day.failed)
    );
  }

  get trendBars() {
    const max = this.trendMax;
    return this.trend.map((day) => ({
      date: (day.date || "").slice(5),
      success: day.success,
      failed: day.failed,
      okPct: Math.round((day.success / max) * 100),
      failPct: Math.round((day.failed / max) * 100),
    }));
  }

  @tracked verifying = false;
  @tracked verifyResult = null;

  @tracked backfilling = false;
  @tracked backfillQueued = false;
  @tracked backfillCategory = "";
  @tracked backfillSince = "";
  @tracked previewing = false;
  @tracked previewCount = null;

  @tracked manualUrls = "";
  @tracked manualSubmitting = false;
  @tracked manualCount = null;

  @action
  async verifyKey() {
    this.verifying = true;
    try {
      this.verifyResult = await ajax("/admin/plugins/indexnow/verify.json", {
        type: "POST",
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.verifying = false;
    }
  }

  @action
  async generateKey() {
    try {
      const data = await ajax("/admin/plugins/indexnow/generate.json", {
        type: "POST",
      });
      this.status = {
        ...this.status,
        key: data.key,
        key_url: data.key_url,
        key_accessible: null,
      };
      this.verifyResult = null;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  updateCategory(event) {
    this.backfillCategory = event.target.value;
    this.backfillQueued = false;
  }

  @action
  updateSince(event) {
    this.backfillSince = event.target.value;
    this.backfillQueued = false;
  }

  @action
  async runBackfill() {
    this.backfilling = true;
    try {
      await ajax("/admin/plugins/indexnow/backfill.json", {
        type: "POST",
        data: {
          category_id: this.backfillCategory,
          since: this.backfillSince,
        },
      });
      this.backfillQueued = true;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.backfilling = false;
    }
  }

  @action
  async previewBackfill() {
    this.previewing = true;
    try {
      const data = await ajax(
        "/admin/plugins/indexnow/backfill_preview.json",
        {
          data: {
            category_id: this.backfillCategory,
            since: this.backfillSince,
          },
        }
      );
      this.previewCount = data.count;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.previewing = false;
    }
  }

  @action
  updateManualUrls(event) {
    this.manualUrls = event.target.value;
    this.manualCount = null;
  }

  @action
  async submitManual() {
    this.manualSubmitting = true;
    try {
      const data = await ajax("/admin/plugins/indexnow/submit.json", {
        type: "POST",
        data: { urls: this.manualUrls },
      });
      this.manualCount = data.count;
      this.manualUrls = "";
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.manualSubmitting = false;
    }
  }

  @action
  async reload() {
    try {
      const [status, logs, stats] = await Promise.all([
        ajax("/admin/plugins/indexnow/status.json"),
        ajax("/admin/plugins/indexnow/logs.json"),
        ajax("/admin/plugins/indexnow/stats.json"),
      ]);
      this.status = status || {};
      this.logs = logs.logs || [];
      this.trend = stats.trend || [];
      this.failures = stats.failures || [];
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
