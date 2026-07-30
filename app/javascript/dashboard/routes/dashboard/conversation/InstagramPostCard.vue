<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { shortTimestamp } from 'shared/helpers/timeHelper';

defineProps({
  post: { type: Object, required: true },
});

defineEmits(['select']);

const { t } = useI18n();
const imageFailed = ref(false);
</script>

<template>
  <button
    type="button"
    class="flex flex-col overflow-hidden text-left transition-all border rounded-xl group border-n-weak bg-n-solid-1 hover:border-n-brand/40 hover:shadow-md focus:outline-none focus-visible:ring-2 focus-visible:ring-n-brand"
    @click="$emit('select', post)"
  >
    <div class="relative w-full overflow-hidden aspect-square bg-n-alpha-2">
      <img
        v-if="post.image_url && !imageFailed"
        :src="post.image_url"
        :alt="post.caption || t('INSTAGRAM_COMMENTS.POST')"
        loading="lazy"
        class="object-cover w-full h-full transition-transform duration-300 group-hover:scale-[1.03]"
        @error="imageFailed = true"
      />
      <div
        v-else
        class="flex items-center justify-center w-full h-full text-n-slate-8"
      >
        <span class="i-lucide-image size-10" />
      </div>
      <span
        class="absolute inline-flex items-center gap-1 px-2 py-1 text-xs font-semibold rounded-full shadow top-2 right-2 bg-n-solid-1/90 text-n-slate-12 backdrop-blur"
      >
        <span class="i-lucide-message-circle size-3.5 text-n-brand" />
        {{ post.comment_count }}
      </span>
    </div>
    <div class="flex flex-col gap-1 p-3">
      <p class="text-sm truncate min-h-5 text-n-slate-12">
        {{ post.caption || t('INSTAGRAM_COMMENTS.NO_CAPTION') }}
      </p>
      <div class="flex items-center justify-between text-xs text-n-slate-11">
        <span>
          {{
            t('INSTAGRAM_COMMENTS.COMMENT_COUNT', { count: post.comment_count })
          }}
        </span>
        <span v-if="post.last_comment_at">
          {{ shortTimestamp(post.last_comment_at, true) }}
        </span>
      </div>
    </div>
  </button>
</template>
