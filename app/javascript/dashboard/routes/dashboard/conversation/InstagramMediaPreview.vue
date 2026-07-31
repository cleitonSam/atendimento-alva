<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

// Previa ao vivo de como a publicacao aparece no Instagram, por formato:
//   post  -> card de feed (quadrado, com pontos de carrossel)
//   reels -> tela 9:16 com trilha de acoes
//   story -> tela 9:16 full-bleed com barra de progresso
const props = defineProps({
  username: { type: String, default: 'seu_perfil' },
  postType: { type: String, default: 'post' }, // post | reels | story
  images: { type: Array, default: () => [] }, // urls (data: ou publicas)
  video: { type: Object, default: null }, // { preview }
  caption: { type: String, default: '' },
});

const { t } = useI18n();

const initial = computed(() =>
  (props.username || 'I').trim().charAt(0).toUpperCase()
);
const cover = computed(() => props.video?.preview || props.images[0] || '');
const hasMedia = computed(() => !!cover.value);
const isVideo = computed(() => !!props.video?.preview);
</script>

<template>
  <div class="flex flex-col items-center gap-3 select-none">
    <!-- ===================== POST (feed) ===================== -->
    <div
      v-if="postType === 'post'"
      class="w-full max-w-[300px] overflow-hidden border shadow-sm rounded-2xl border-n-weak bg-n-background"
    >
      <div class="flex items-center gap-2.5 px-3 py-2.5">
        <span
          class="flex items-center justify-center text-xs font-semibold text-white rounded-full size-8 bg-gradient-to-tr from-n-ruby-9 via-n-amber-9 to-n-brand"
        >
          {{ initial }}
        </span>
        <span class="text-xs font-semibold truncate text-n-slate-12">
          {{ username }}
        </span>
        <span class="ml-auto i-lucide-more-horizontal size-4 text-n-slate-11" />
      </div>

      <div class="relative aspect-square bg-n-alpha-2">
        <img
          v-if="hasMedia"
          :src="cover"
          alt=""
          class="object-cover w-full h-full"
        />
        <div
          v-else
          class="flex flex-col items-center justify-center w-full h-full gap-2 text-n-slate-8"
        >
          <span class="i-lucide-image size-8" />
          <span class="text-[11px] text-n-slate-9">
            {{ t('INSTAGRAM_PUBLISH.PREVIEW.MEDIA_EMPTY') }}
          </span>
        </div>
        <!-- pontos do carrossel -->
        <div
          v-if="images.length > 1"
          class="absolute left-0 right-0 flex items-center justify-center gap-1 bottom-2"
        >
          <span
            v-for="(img, i) in images"
            :key="i"
            class="rounded-full size-1.5"
            :class="i === 0 ? 'bg-white' : 'bg-white/50'"
          />
        </div>
        <span
          v-if="images.length > 1"
          class="absolute px-1.5 py-0.5 text-[10px] font-semibold text-white rounded-full top-2 right-2 bg-black/50"
        >
          {{ `1/${images.length}` }}
        </span>
      </div>

      <div class="flex items-center gap-3 px-3 pt-2.5">
        <span class="i-lucide-heart size-5 text-n-slate-12" />
        <span class="i-lucide-message-circle size-5 text-n-slate-12" />
        <span class="i-lucide-send size-5 text-n-slate-12" />
        <span class="ml-auto i-lucide-bookmark size-5 text-n-slate-12" />
      </div>
      <div class="px-3 pt-1.5 pb-3">
        <p class="text-xs text-n-slate-12">
          <span class="font-semibold">{{ username }}</span>
          <span v-if="caption.trim()" class="whitespace-pre-line">
            {{ ' ' + caption }}</span
          >
          <span v-else class="italic text-n-slate-9">
            {{ ' ' + t('INSTAGRAM_PUBLISH.PREVIEW.CAPTION_EMPTY') }}</span
          >
        </p>
      </div>
    </div>

    <!-- ===================== REELS / STORY (9:16) ===================== -->
    <div
      v-else
      class="relative w-full max-w-[240px] aspect-[9/16] overflow-hidden border shadow-sm rounded-[1.75rem] border-n-weak bg-n-solid-3"
    >
      <img
        v-if="hasMedia"
        :src="cover"
        alt=""
        class="absolute inset-0 object-cover w-full h-full"
      />
      <div
        v-else
        class="absolute inset-0 flex flex-col items-center justify-center gap-2 text-n-slate-8"
      >
        <span
          :class="
            postType === 'reels' ? 'i-lucide-clapperboard' : 'i-lucide-camera'
          "
          class="size-8"
        />
        <span class="text-[11px] text-n-slate-9">
          {{ t('INSTAGRAM_PUBLISH.PREVIEW.MEDIA_EMPTY') }}
        </span>
      </div>

      <!-- selo de video -->
      <span
        v-if="isVideo && hasMedia"
        class="absolute flex items-center justify-center rounded-full top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 size-11 bg-black/35 backdrop-blur-sm"
      >
        <span class="text-white i-lucide-play size-5" />
      </span>

      <!-- ---------- STORY ---------- -->
      <template v-if="postType === 'story'">
        <div
          class="absolute inset-x-0 top-0 p-2.5 bg-gradient-to-b from-black/45 to-transparent"
        >
          <div class="flex gap-1 mb-2">
            <span class="flex-1 h-0.5 rounded-full bg-white/80" />
          </div>
          <div class="flex items-center gap-2">
            <span
              class="flex items-center justify-center text-[10px] font-semibold text-white rounded-full size-6 bg-gradient-to-tr from-n-ruby-9 via-n-amber-9 to-n-brand ring-1 ring-white/60"
            >
              {{ initial }}
            </span>
            <span class="text-[11px] font-semibold text-white drop-shadow">
              {{ t('INSTAGRAM_PUBLISH.PREVIEW.YOUR_STORY') }}
            </span>
            <span class="ml-auto text-white i-lucide-x size-4 drop-shadow" />
          </div>
        </div>
        <div
          class="absolute inset-x-0 bottom-0 flex items-center gap-2 p-2.5 bg-gradient-to-t from-black/45 to-transparent"
        >
          <span
            class="flex-1 px-3 py-1.5 text-[11px] text-white/90 border rounded-full border-white/50"
          >
            {{ t('INSTAGRAM_PUBLISH.PREVIEW.STORY_REPLY') }}
          </span>
          <span class="text-white i-lucide-heart size-5 drop-shadow" />
          <span class="text-white i-lucide-send size-5 drop-shadow" />
        </div>
      </template>

      <!-- ---------- REELS ---------- -->
      <template v-else>
        <span
          class="absolute top-3 left-3 text-[11px] font-semibold text-white drop-shadow"
        >
          {{ t('INSTAGRAM_PUBLISH.PREVIEW.REELS') }}
        </span>
        <div
          class="absolute flex flex-col items-center gap-3.5 bottom-16 right-2"
        >
          <span class="text-white i-lucide-heart size-6 drop-shadow" />
          <span class="text-white i-lucide-message-circle size-6 drop-shadow" />
          <span class="text-white i-lucide-send size-6 drop-shadow" />
          <span
            class="text-white i-lucide-more-horizontal size-6 drop-shadow"
          />
        </div>
        <div
          class="absolute inset-x-0 bottom-0 p-3 pr-12 bg-gradient-to-t from-black/55 to-transparent"
        >
          <div class="flex items-center gap-2 mb-1.5">
            <span
              class="flex items-center justify-center text-[10px] font-semibold text-white rounded-full size-6 bg-gradient-to-tr from-n-ruby-9 via-n-amber-9 to-n-brand ring-1 ring-white/60"
            >
              {{ initial }}
            </span>
            <span class="text-[11px] font-semibold text-white drop-shadow">
              {{ username }}
            </span>
          </div>
          <p
            v-if="caption.trim()"
            class="text-[11px] text-white/90 line-clamp-2 drop-shadow whitespace-pre-line"
          >
            {{ caption }}
          </p>
        </div>
      </template>
    </div>
  </div>
</template>
