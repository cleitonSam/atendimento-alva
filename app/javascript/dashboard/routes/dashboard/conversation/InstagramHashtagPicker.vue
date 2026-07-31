<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import HashtagSetsAPI from 'dashboard/api/instagramHashtagSets';

// Conjuntos de hashtags reutilizaveis: clica no chip pra inserir; salva o texto atual
// como um novo conjunto; mostra a contagem (Instagram permite ate 30 no total).
const props = defineProps({
  currentText: { type: String, default: '' }, // onde as hashtags entram (1o comentario)
  captionText: { type: String, default: '' }, // legenda (conta pro total, nao pro salvar)
});
const emit = defineEmits(['insert']);

const { t } = useI18n();

const sets = ref([]);
const loading = ref(false);
const saving = ref(false);
const newName = ref('');
const showSave = ref(false);

const HASHTAG_RE = /#[\p{L}\p{N}_]+/gu;
// Instagram conta ate 30 no TOTAL entre legenda + comentario.
const tagCount = computed(
  () =>
    (`${props.captionText} ${props.currentText}`.match(HASHTAG_RE) || []).length
);
const overLimit = computed(() => tagCount.value > 30);

async function load() {
  loading.value = true;
  try {
    const { data } = await HashtagSetsAPI.get();
    sets.value = data ?? [];
  } catch (error) {
    sets.value = [];
  } finally {
    loading.value = false;
  }
}

const insert = set => emit('insert', set.hashtags);

async function saveCurrent() {
  const hashtags = (props.currentText.match(HASHTAG_RE) || []).join(' ');
  if (!newName.value.trim() || !hashtags) return;
  saving.value = true;
  try {
    await HashtagSetsAPI.create({
      instagram_hashtag_set: { name: newName.value.trim(), hashtags },
    });
    newName.value = '';
    showSave.value = false;
    useAlert(t('INSTAGRAM_HASHTAGS.SAVED'));
    await load();
  } catch (error) {
    useAlert(t('INSTAGRAM_HASHTAGS.SAVE_ERROR'));
  } finally {
    saving.value = false;
  }
}

async function remove(set) {
  try {
    await HashtagSetsAPI.delete(set.id);
    sets.value = sets.value.filter(s => s.id !== set.id);
  } catch (error) {
    useAlert(t('INSTAGRAM_HASHTAGS.SAVE_ERROR'));
  }
}

onMounted(load);
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex items-center justify-between">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('INSTAGRAM_HASHTAGS.TITLE') }}
      </label>
      <span
        class="text-[10px] font-medium tabular-nums"
        :class="overLimit ? 'text-n-ruby-10' : 'text-n-slate-10'"
      >
        {{ t('INSTAGRAM_HASHTAGS.COUNT', { count: tagCount }) }}
      </span>
    </div>

    <div class="flex flex-wrap items-center gap-1.5">
      <span
        v-for="set in sets"
        :key="set.id"
        class="group inline-flex items-center gap-1 pl-2.5 pr-1 py-1 text-xs font-medium transition border rounded-full cursor-pointer border-n-weak text-n-slate-11 hover:border-n-brand hover:text-n-brand"
        @click="insert(set)"
      >
        {{ set.name }}
        <button
          type="button"
          :aria-label="t('INSTAGRAM_HASHTAGS.DELETE')"
          class="flex items-center justify-center transition rounded-full size-4 text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-ruby-10"
          @click.stop="remove(set)"
        >
          <span class="i-lucide-x size-3" />
        </button>
      </span>

      <button
        v-if="!showSave"
        type="button"
        class="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-medium transition border border-dashed rounded-full border-n-weak text-n-slate-10 hover:border-n-brand hover:text-n-brand"
        @click="showSave = true"
      >
        <span class="i-lucide-plus size-3" />
        {{ t('INSTAGRAM_HASHTAGS.SAVE_CURRENT') }}
      </button>
    </div>

    <div v-if="showSave" class="flex gap-2">
      <input
        v-model="newName"
        type="text"
        :placeholder="t('INSTAGRAM_HASHTAGS.NAME_PH')"
        class="flex-1 px-3 py-1.5 text-xs border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
        @keydown.enter.prevent="saveCurrent"
      />
      <button
        type="button"
        :disabled="!newName.trim() || saving"
        class="px-3 py-1.5 text-xs font-semibold rounded-lg bg-n-brand text-n-brand-text disabled:opacity-50"
        @click="saveCurrent"
      >
        {{ t('INSTAGRAM_HASHTAGS.SAVE') }}
      </button>
      <button
        type="button"
        class="px-2 py-1.5 text-xs font-medium rounded-lg text-n-slate-11 hover:text-n-slate-12"
        @click="showSave = false"
      >
        {{ t('INSTAGRAM_HASHTAGS.CANCEL') }}
      </button>
    </div>
  </div>
</template>
