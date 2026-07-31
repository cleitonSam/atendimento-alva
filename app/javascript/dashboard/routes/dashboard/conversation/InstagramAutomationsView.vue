<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import AutomationsAPI from 'dashboard/api/instagramCommentAutomations';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const { t } = useI18n();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');

const igInboxes = computed(() =>
  inboxes.value.filter(inbox => inbox.channel_type === INBOX_TYPES.INSTAGRAM)
);

const automations = ref([]);
const loading = ref(false);
const saving = ref(false);
const mode = ref('list'); // list | form
const MATCH_TYPES = ['contains', 'exact', 'any'];

const blankForm = () => ({
  id: null,
  inbox_id: igInboxes.value[0]?.id ?? null,
  name: '',
  target: 'any', // any | specific
  media_id: '',
  keywords: '',
  match_type: 'contains',
  dm_message: '',
  dm_link: '',
  dm_button_label: '',
  public_reply: '',
  once_per_user: true,
  enabled: true,
  starts_at: '',
  ends_at: '',
});
const form = ref(blankForm());

async function load() {
  loading.value = true;
  try {
    const { data } = await AutomationsAPI.get();
    automations.value = data ?? [];
  } catch (error) {
    useAlert(t('INSTAGRAM_AUTOMATIONS.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
}

// ISO -> valor do input datetime-local (sem timezone), e vazio se nulo.
function toLocalInput(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

const openCreate = () => {
  form.value = blankForm();
  mode.value = 'form';
};

const openEdit = automation => {
  form.value = {
    ...blankForm(),
    ...automation,
    target: automation.media_id ? 'specific' : 'any',
    media_id: automation.media_id ?? '',
    keywords: automation.keywords ?? '',
    dm_link: automation.dm_link ?? '',
    dm_button_label: automation.dm_button_label ?? '',
    public_reply: automation.public_reply ?? '',
    starts_at: toLocalInput(automation.starts_at),
    ends_at: toLocalInput(automation.ends_at),
  };
  mode.value = 'form';
};

const cancelForm = () => {
  mode.value = 'list';
  form.value = blankForm();
};

const canSave = computed(
  () =>
    form.value.inbox_id &&
    form.value.name.trim() &&
    form.value.dm_message.trim() &&
    (form.value.match_type === 'any' || form.value.keywords.trim())
);

function payload() {
  const f = form.value;
  return {
    inbox_id: f.inbox_id,
    name: f.name.trim(),
    media_id: f.target === 'specific' ? f.media_id.trim() : '',
    keywords: f.match_type === 'any' ? '' : f.keywords.trim(),
    match_type: f.match_type,
    dm_message: f.dm_message.trim(),
    dm_link: f.dm_link.trim(),
    dm_button_label: f.dm_button_label.trim(),
    public_reply: f.public_reply.trim(),
    once_per_user: f.once_per_user,
    enabled: f.enabled,
    starts_at: f.starts_at || null,
    ends_at: f.ends_at || null,
  };
}

async function save() {
  if (!canSave.value || saving.value) return;
  saving.value = true;
  try {
    if (form.value.id) {
      await AutomationsAPI.update(form.value.id, {
        instagram_comment_automation: payload(),
      });
    } else {
      await AutomationsAPI.create({ instagram_comment_automation: payload() });
    }
    useAlert(t('INSTAGRAM_AUTOMATIONS.SAVED'));
    cancelForm();
    await load();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('INSTAGRAM_AUTOMATIONS.SAVE_ERROR')
    );
  } finally {
    saving.value = false;
  }
}

async function toggle(automation) {
  try {
    await AutomationsAPI.update(automation.id, {
      instagram_comment_automation: { enabled: !automation.enabled },
    });
    automation.enabled = !automation.enabled;
  } catch (error) {
    useAlert(t('INSTAGRAM_AUTOMATIONS.SAVE_ERROR'));
  }
}

async function remove(automation) {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('INSTAGRAM_AUTOMATIONS.DELETE_CONFIRM'))) return;
  try {
    await AutomationsAPI.delete(automation.id);
    automations.value = automations.value.filter(a => a.id !== automation.id);
  } catch (error) {
    useAlert(t('INSTAGRAM_AUTOMATIONS.SAVE_ERROR'));
  }
}

const summary = automation => {
  const target = automation.media_id
    ? t('INSTAGRAM_AUTOMATIONS.ONE_POST')
    : t('INSTAGRAM_AUTOMATIONS.ANY_POST');
  const trigger =
    automation.match_type === 'any'
      ? t('INSTAGRAM_AUTOMATIONS.ANY_COMMENT')
      : automation.keywords;
  return `${target} · ${trigger}`;
};

onMounted(() => {
  if (!inboxes.value.length) store.dispatch('inboxes/get');
  load();
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <header
      class="flex items-center justify-between flex-shrink-0 gap-2 px-6 py-4 border-b border-n-weak"
    >
      <div class="flex items-center gap-2 min-w-0">
        <span class="i-lucide-bot-message-square size-5 text-n-brand" />
        <h1 class="text-lg font-semibold truncate text-n-slate-12">
          {{ t('INSTAGRAM_AUTOMATIONS.TITLE') }}
        </h1>
      </div>
      <button
        v-if="mode === 'list'"
        type="button"
        class="flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-lg bg-n-brand text-n-brand-text hover:brightness-110"
        @click="openCreate"
      >
        <span class="i-lucide-plus size-4" />
        {{ t('INSTAGRAM_AUTOMATIONS.NEW') }}
      </button>
    </header>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <!-- =================== LISTA =================== -->
      <template v-if="mode === 'list'">
        <div
          v-if="loading"
          class="flex items-center justify-center py-24 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div
          v-else-if="!automations.length"
          class="flex flex-col items-center justify-center gap-3 py-24 text-center"
        >
          <span class="i-lucide-bot-message-square size-10 text-n-slate-8" />
          <p class="max-w-sm text-sm text-n-slate-11">
            {{ t('INSTAGRAM_AUTOMATIONS.EMPTY') }}
          </p>
          <button
            type="button"
            class="px-3 py-2 text-sm font-medium rounded-lg bg-n-brand text-n-brand-text hover:brightness-110"
            @click="openCreate"
          >
            {{ t('INSTAGRAM_AUTOMATIONS.NEW') }}
          </button>
        </div>
        <ul v-else class="flex flex-col gap-3 p-6 mx-auto max-w-3xl">
          <li
            v-for="automation in automations"
            :key="automation.id"
            class="flex items-center gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <div class="flex flex-col min-w-0 gap-1 flex-1">
              <div class="flex items-center gap-2">
                <span class="text-sm font-medium truncate text-n-slate-12">
                  {{ automation.name }}
                </span>
                <span
                  class="px-1.5 py-0.5 text-[10px] font-semibold rounded-full"
                  :class="
                    automation.enabled
                      ? 'bg-n-teal-3 text-n-teal-11'
                      : 'bg-n-alpha-2 text-n-slate-10'
                  "
                >
                  {{
                    automation.enabled
                      ? t('INSTAGRAM_AUTOMATIONS.ON')
                      : t('INSTAGRAM_AUTOMATIONS.OFF')
                  }}
                </span>
              </div>
              <span class="text-xs truncate text-n-slate-11">
                {{ summary(automation) }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{
                  t('INSTAGRAM_AUTOMATIONS.SENT_COUNT', {
                    count: automation.sent_count,
                  })
                }}
              </span>
            </div>
            <button
              type="button"
              class="text-xs font-medium text-n-slate-11 hover:text-n-slate-12"
              @click="toggle(automation)"
            >
              {{
                automation.enabled
                  ? t('INSTAGRAM_AUTOMATIONS.PAUSE')
                  : t('INSTAGRAM_AUTOMATIONS.RESUME')
              }}
            </button>
            <button
              type="button"
              class="text-xs font-medium text-n-brand hover:underline"
              @click="openEdit(automation)"
            >
              {{ t('INSTAGRAM_AUTOMATIONS.EDIT') }}
            </button>
            <button
              type="button"
              class="text-xs font-medium text-n-ruby-9 hover:text-n-ruby-10"
              @click="remove(automation)"
            >
              {{ t('INSTAGRAM_AUTOMATIONS.DELETE') }}
            </button>
          </li>
        </ul>
      </template>

      <!-- =================== FORMULARIO =================== -->
      <form
        v-else
        class="flex flex-col max-w-2xl gap-5 p-6 mx-auto"
        @submit.prevent="save"
      >
        <!-- Inbox (se houver mais de um) -->
        <div v-if="igInboxes.length > 1" class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_AUTOMATIONS.INBOX') }}
          </label>
          <select
            v-model="form.inbox_id"
            class="px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          >
            <option
              v-for="inbox in igInboxes"
              :key="inbox.id"
              :value="inbox.id"
            >
              {{ inbox.name }}
            </option>
          </select>
        </div>

        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_AUTOMATIONS.NAME') }}
          </label>
          <input
            v-model="form.name"
            type="text"
            :placeholder="t('INSTAGRAM_AUTOMATIONS.NAME_PH')"
            class="px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- Onde aplica -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_AUTOMATIONS.TARGET') }}
          </label>
          <div class="flex gap-2">
            <button
              type="button"
              class="px-3 py-1.5 text-xs font-medium rounded-md"
              :class="
                form.target === 'any'
                  ? 'bg-n-brand text-n-brand-text'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
              @click="form.target = 'any'"
            >
              {{ t('INSTAGRAM_AUTOMATIONS.ANY_POST') }}
            </button>
            <button
              type="button"
              class="px-3 py-1.5 text-xs font-medium rounded-md"
              :class="
                form.target === 'specific'
                  ? 'bg-n-brand text-n-brand-text'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
              @click="form.target = 'specific'"
            >
              {{ t('INSTAGRAM_AUTOMATIONS.ONE_POST') }}
            </button>
          </div>
          <input
            v-if="form.target === 'specific'"
            v-model="form.media_id"
            type="text"
            :placeholder="t('INSTAGRAM_AUTOMATIONS.MEDIA_ID_PH')"
            class="mt-1 px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- Gatilho -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_AUTOMATIONS.TRIGGER') }}
          </label>
          <div class="flex gap-2">
            <button
              v-for="type in MATCH_TYPES"
              :key="type"
              type="button"
              class="px-2.5 py-1 text-xs font-medium rounded-md"
              :class="
                form.match_type === type
                  ? 'bg-n-brand text-n-brand-text'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
              @click="form.match_type = type"
            >
              {{ t(`INSTAGRAM_AUTOMATIONS.MATCH.${type.toUpperCase()}`) }}
            </button>
          </div>
          <input
            v-if="form.match_type !== 'any'"
            v-model="form.keywords"
            type="text"
            :placeholder="t('INSTAGRAM_AUTOMATIONS.KEYWORDS_PH')"
            class="mt-1 px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- DM -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_AUTOMATIONS.DM_MESSAGE') }}
          </label>
          <textarea
            v-model="form.dm_message"
            rows="3"
            :placeholder="t('INSTAGRAM_AUTOMATIONS.DM_MESSAGE_PH')"
            class="px-3 py-2 text-sm border rounded-lg resize-none bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
          <div class="flex gap-2">
            <input
              v-model="form.dm_link"
              type="url"
              :placeholder="t('INSTAGRAM_AUTOMATIONS.DM_LINK_PH')"
              class="flex-1 px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            />
            <input
              v-model="form.dm_button_label"
              type="text"
              :placeholder="t('INSTAGRAM_AUTOMATIONS.DM_BUTTON_PH')"
              class="w-40 px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            />
          </div>
        </div>

        <!-- Resposta publica -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_AUTOMATIONS.PUBLIC_REPLY') }}
          </label>
          <input
            v-model="form.public_reply"
            type="text"
            :placeholder="t('INSTAGRAM_AUTOMATIONS.PUBLIC_REPLY_PH')"
            class="px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- Agendamento -->
        <div class="flex flex-wrap gap-4">
          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('INSTAGRAM_AUTOMATIONS.STARTS_AT') }}
            </label>
            <input
              v-model="form.starts_at"
              type="datetime-local"
              class="px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('INSTAGRAM_AUTOMATIONS.ENDS_AT') }}
            </label>
            <input
              v-model="form.ends_at"
              type="datetime-local"
              class="px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
            />
          </div>
        </div>

        <!-- Toggles -->
        <label
          class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
        >
          <input
            v-model="form.once_per_user"
            type="checkbox"
            class="accent-n-brand"
          />
          {{ t('INSTAGRAM_AUTOMATIONS.ONCE_PER_USER') }}
        </label>
        <label
          class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
        >
          <input
            v-model="form.enabled"
            type="checkbox"
            class="accent-n-brand"
          />
          {{ t('INSTAGRAM_AUTOMATIONS.ENABLED') }}
        </label>

        <div class="flex items-center justify-end gap-2 pt-2">
          <button
            type="button"
            class="px-4 py-2 text-sm font-medium rounded-lg text-n-slate-11 hover:text-n-slate-12"
            @click="cancelForm"
          >
            {{ t('INSTAGRAM_AUTOMATIONS.CANCEL') }}
          </button>
          <button
            type="submit"
            :disabled="!canSave || saving"
            class="px-4 py-2 text-sm font-semibold rounded-lg bg-n-brand text-n-brand-text disabled:opacity-50 hover:brightness-110"
          >
            {{ t('INSTAGRAM_AUTOMATIONS.SAVE') }}
          </button>
        </div>
      </form>
    </div>
  </section>
</template>
