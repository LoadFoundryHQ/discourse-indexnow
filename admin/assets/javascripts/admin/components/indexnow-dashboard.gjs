import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="indexnow-dashboard">
    <div class="indexnow-dashboard__cards">
      <div class="indexnow-card">
        <div class="indexnow-card__label">{{i18n "indexnow.status"}}</div>
        <div class="indexnow-card__value">
          {{#if @controller.status.enabled}}
            {{i18n "indexnow.enabled"}}
          {{else}}
            {{i18n "indexnow.disabled"}}
          {{/if}}
        </div>
      </div>
      <div class="indexnow-card">
        <div class="indexnow-card__label">{{i18n "indexnow.today_success"}}</div>
        <div class="indexnow-card__value">{{@controller.status.today_success}}</div>
      </div>
      <div class="indexnow-card">
        <div class="indexnow-card__label">{{i18n "indexnow.today_failed"}}</div>
        <div class="indexnow-card__value">{{@controller.status.today_failed}}</div>
      </div>
      <div class="indexnow-card">
        <div class="indexnow-card__label">{{i18n "indexnow.total"}}</div>
        <div class="indexnow-card__value">{{@controller.status.total}}</div>
      </div>
    </div>

    <section class="indexnow-panel">
      <h3>{{i18n "indexnow.key"}}</h3>
      <p class="indexnow-panel__code">{{@controller.status.key}}</p>
      <p class="indexnow-panel__hint">{{@controller.status.key_url}}</p>
      <div class="indexnow-panel__actions">
        <button
          type="button"
          class="btn btn-default"
          {{on "click" @controller.generateKey}}
        >{{i18n "indexnow.generate"}}</button>
        <button
          type="button"
          class="btn btn-primary"
          disabled={{@controller.verifying}}
          {{on "click" @controller.verifyKey}}
        >
          {{#if @controller.verifying}}
            {{i18n "indexnow.verifying"}}
          {{else}}
            {{i18n "indexnow.verify"}}
          {{/if}}
        </button>
        {{#if @controller.verifyResult}}
          {{#if @controller.verifyResult.accessible}}
            <span class="indexnow-ok">{{i18n "indexnow.accessible"}}</span>
          {{else}}
            <span class="indexnow-err">{{i18n "indexnow.not_accessible"}}</span>
          {{/if}}
        {{/if}}
      </div>
    </section>

    <section class="indexnow-panel">
      <h3>{{i18n "indexnow.backfill_title"}}</h3>
      <p class="indexnow-panel__hint">{{i18n "indexnow.backfill_help"}}</p>
      <div class="indexnow-panel__actions">
        <input
          type="text"
          class="indexnow-input"
          placeholder={{i18n "indexnow.category"}}
          value={{@controller.backfillCategory}}
          {{on "input" @controller.updateCategory}}
        />
        <input
          type="date"
          class="indexnow-input"
          value={{@controller.backfillSince}}
          {{on "input" @controller.updateSince}}
        />
        <button
          type="button"
          class="btn btn-primary"
          disabled={{@controller.backfilling}}
          {{on "click" @controller.runBackfill}}
        >
          {{#if @controller.backfilling}}
            {{i18n "indexnow.running"}}
          {{else}}
            {{i18n "indexnow.run_backfill"}}
          {{/if}}
        </button>
        {{#if @controller.backfillQueued}}
          <span class="indexnow-ok">{{i18n "indexnow.running"}}</span>
        {{/if}}
      </div>
    </section>

    <section class="indexnow-panel">
      <div class="indexnow-panel__head">
        <h3>{{i18n "indexnow.recent"}}</h3>
        <button
          type="button"
          class="btn btn-small"
          {{on "click" @controller.reload}}
        >{{i18n "indexnow.reload"}}</button>
      </div>
      {{#if @controller.logs.length}}
        <table class="indexnow-table">
          <thead>
            <tr>
              <th>{{i18n "indexnow.url"}}</th>
              <th>{{i18n "indexnow.status_col"}}</th>
              <th>{{i18n "indexnow.code"}}</th>
              <th>{{i18n "indexnow.trigger"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.logs as |log|}}
              <tr>
                <td class="indexnow-table__url">{{log.url}}</td>
                <td>{{log.status}}</td>
                <td>{{log.response_code}}</td>
                <td>{{log.trigger}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <p class="indexnow-panel__hint">{{i18n "indexnow.none"}}</p>
      {{/if}}
    </section>
  </div>
</template>;
