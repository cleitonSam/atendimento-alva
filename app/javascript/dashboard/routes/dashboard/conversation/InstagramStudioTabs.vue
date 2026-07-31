<script setup>
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';

// Abas do "estudio" Instagram: Publicacoes e Automacoes num menu so.
const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const accountId = useMapGetter('getCurrentAccountId');

const TABS = [
  {
    key: 'posts',
    route: 'instagram_publish',
    label: 'INSTAGRAM_PUBLISH.TITLE',
    icon: 'i-lucide-image-plus',
  },
  {
    key: 'automations',
    route: 'instagram_automations',
    label: 'INSTAGRAM_AUTOMATIONS.TITLE',
    icon: 'i-lucide-bot-message-square',
  },
];

const isActive = tab => route.name === tab.route;
const go = tab => {
  if (!isActive(tab)) {
    router.push({ name: tab.route, params: { accountId: accountId.value } });
  }
};
</script>

<template>
  <div class="flex items-center gap-1 p-1 rounded-lg bg-n-alpha-1">
    <button
      v-for="tab in TABS"
      :key="tab.key"
      type="button"
      class="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium transition rounded-md"
      :class="
        isActive(tab)
          ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
          : 'text-n-slate-11 hover:text-n-slate-12'
      "
      @click="go(tab)"
    >
      <span :class="tab.icon" class="size-4" />
      {{ t(tab.label) }}
    </button>
  </div>
</template>
