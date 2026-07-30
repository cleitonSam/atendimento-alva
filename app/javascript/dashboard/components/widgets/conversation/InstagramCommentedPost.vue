<script setup>
import { ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import ConversationAPI from 'dashboard/api/inbox/conversation';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const post = ref(null);

async function load() {
  post.value = null;
  try {
    const { data } =
      await ConversationAPI.getInstagramCommentedPost(props.conversationId);
    post.value = data && (data.image_url || data.permalink) ? data : null;
  } catch (error) {
    post.value = null;
  }
}

onMounted(load);
watch(() => props.conversationId, load);
</script>

<template>
  <div
    v-if="post"
    class="flex items-center gap-3 mx-2 mt-2 p-2 overflow-hidden border rounded-lg border-n-weak bg-n-solid-2"
  >
    <img
      v-if="post.image_url"
      :src="post.image_url"
      :alt="t('CONVERSATION.INSTAGRAM_COMMENTED_POST.HEADING')"
      class="flex-shrink-0 object-cover rounded-md size-14"
    />
    <div class="flex flex-col min-w-0 gap-0.5">
      <span class="text-xs font-medium text-n-slate-11">
        {{ t('CONVERSATION.INSTAGRAM_COMMENTED_POST.HEADING') }}
      </span>
      <span v-if="post.caption" class="text-sm truncate text-n-slate-12">
        {{ post.caption }}
      </span>
      <a
        :href="post.permalink"
        target="_blank"
        rel="noopener noreferrer"
        class="text-xs font-medium text-n-brand hover:underline"
      >
        {{ t('CONVERSATION.INSTAGRAM_COMMENTED_POST.VIEW') }}
      </a>
    </div>
  </div>
</template>
