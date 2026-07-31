<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

// Preview estilo ManyChat: mostra como a resposta publica + a DM chegam pro usuario.
// DM pode ser: card (imagem + titulo + subtitulo + botoes) ou texto + botoes.
const props = defineProps({
  name: { type: String, default: 'Instagram' },
  publicReply: { type: String, default: '' },
  dmMessage: { type: String, default: '' },
  cardTitle: { type: String, default: '' },
  image: { type: String, default: '' },
  buttons: { type: Array, default: () => [] },
});

const { t } = useI18n();

const initial = computed(() =>
  (props.name || 'I').trim().charAt(0).toUpperCase()
);
const hasCard = computed(() => !!props.image);
const validButtons = computed(() =>
  props.buttons
    .filter(btn => btn.url?.trim())
    .slice(0, 3)
    .map(btn => btn.title?.trim() || t('INSTAGRAM_PUBLISH.PREVIEW.OPEN'))
);
const hasContent = computed(
  () => hasCard.value || props.dmMessage.trim() || validButtons.value.length
);
</script>

<template>
  <div
    class="flex flex-col overflow-hidden border shadow-sm select-none rounded-2xl border-n-weak bg-n-background"
  >
    <!-- Cabecalho estilo DM do Instagram -->
    <div class="flex items-center gap-2.5 px-3 py-2.5 border-b border-n-weak">
      <span class="i-lucide-chevron-left size-4 text-n-slate-10" />
      <span
        class="flex items-center justify-center text-xs font-semibold text-white rounded-full size-7 bg-gradient-to-tr from-n-ruby-9 via-n-amber-9 to-n-brand"
      >
        {{ initial }}
      </span>
      <div class="flex flex-col min-w-0 leading-tight">
        <span class="text-xs font-semibold truncate text-n-slate-12">
          {{ name }}
        </span>
        <span class="text-[10px] text-n-slate-10">
          {{ t('INSTAGRAM_PUBLISH.PREVIEW.ACTIVE') }}
        </span>
      </div>
      <span class="ml-auto i-lucide-instagram size-4 text-n-slate-10" />
    </div>

    <!-- Corpo da conversa -->
    <div class="flex flex-col gap-2 px-3 py-4 min-h-[168px] justify-end">
      <!-- Resposta publica (aparece no comentario) -->
      <div v-if="publicReply.trim()" class="flex flex-col items-start gap-1">
        <span class="text-[10px] font-medium text-n-slate-9 pl-1">
          {{ t('INSTAGRAM_PUBLISH.PREVIEW.PUBLIC') }}
        </span>
        <div
          class="max-w-[85%] px-3 py-2 text-xs rounded-2xl rounded-bl-sm bg-n-alpha-2 text-n-slate-12"
        >
          {{ publicReply }}
        </div>
      </div>

      <!-- DM automatica -->
      <div class="flex flex-col items-start gap-1 mt-1">
        <span class="text-[10px] font-medium text-n-slate-9 pl-1">
          {{ t('INSTAGRAM_PUBLISH.PREVIEW.DM') }}
        </span>

        <!-- Card (generic template): capa + titulo + subtitulo + botoes -->
        <div
          v-if="hasCard"
          class="max-w-[88%] overflow-hidden border rounded-2xl rounded-bl-sm border-n-weak bg-n-solid-1"
        >
          <img
            :src="image"
            alt=""
            class="object-cover w-full aspect-[1.91/1]"
          />
          <div class="px-3 py-2">
            <p class="text-xs font-semibold text-n-slate-12 line-clamp-1">
              {{ cardTitle || t('INSTAGRAM_PUBLISH.PREVIEW.CARD_TITLE_EMPTY') }}
            </p>
            <p
              v-if="dmMessage.trim()"
              class="text-[11px] text-n-slate-11 line-clamp-2"
            >
              {{ dmMessage }}
            </p>
          </div>
          <div
            v-for="(label, i) in validButtons"
            :key="i"
            class="px-2 pb-2 first:border-t first:border-n-weak first:pt-2"
          >
            <span
              class="block px-3 py-2 text-xs font-semibold text-center rounded-xl bg-n-alpha-2 text-n-brand"
            >
              {{ label }}
            </span>
          </div>
        </div>

        <!-- Texto + botoes -->
        <div
          v-else-if="hasContent"
          class="max-w-[85%] overflow-hidden rounded-2xl rounded-bl-sm bg-n-solid-3"
        >
          <p
            v-if="dmMessage.trim()"
            class="px-3 py-2 text-xs whitespace-pre-line text-n-slate-12"
          >
            {{ dmMessage }}
          </p>
          <div
            v-for="(label, i) in validButtons"
            :key="i"
            class="px-2 pb-2 -mt-0.5 first:mt-0 first:pt-2"
          >
            <span
              class="block px-3 py-2 text-xs font-semibold text-center border rounded-xl border-n-weak text-n-brand"
            >
              {{ label }}
            </span>
          </div>
        </div>

        <!-- Vazio -->
        <div
          v-else
          class="max-w-[85%] px-3 py-2 text-xs italic rounded-2xl rounded-bl-sm bg-n-alpha-1 text-n-slate-9"
        >
          {{ t('INSTAGRAM_PUBLISH.PREVIEW.EMPTY') }}
        </div>
      </div>
    </div>
  </div>
</template>
