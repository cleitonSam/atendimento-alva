<script setup>
import { ref, reactive, computed, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { shortTimestamp, dynamicTime } from 'shared/helpers/timeHelper';
import InstagramCommentedPostsAPI from 'dashboard/api/instagramCommentedPosts';
import ConversationAPI from 'dashboard/api/inbox/conversation';
import InstagramPostCard from './InstagramPostCard.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// mediaId presente => painel de DETALHE do post; ausente => GALERIA de posts.
const props = defineProps({
  mediaId: { type: String, default: '' },
});

const { t } = useI18n();
const router = useRouter();
const accountId = useMapGetter('getCurrentAccountId');

const accountRoute = name => ({ name, params: { accountId: accountId.value } });

// ---- Resposta (reusa o contrato da Alva: publico / dm / ambos) ----
const replyingTo = ref(null); // comment_id
const replyText = ref('');
const replyMode = ref('publico');
const sendingReply = ref(false);
const REPLY_MODES = ['publico', 'dm', 'ambos'];

function resetReply() {
  replyingTo.value = null;
  replyText.value = '';
  replyMode.value = 'publico';
}

// ---- Galeria ----
const posts = ref([]);
const loadingPosts = ref(false);

async function loadPosts() {
  loadingPosts.value = true;
  try {
    const { data } = await InstagramCommentedPostsAPI.get();
    posts.value = data?.payload ?? [];
  } catch (error) {
    posts.value = [];
    useAlert(t('INSTAGRAM_COMMENTS.LOAD_ERROR'));
  } finally {
    loadingPosts.value = false;
  }
}

const openPost = post => {
  router.push({
    name: 'instagram_comments_post',
    params: { accountId: accountId.value, mediaId: String(post.media_id) },
  });
};

// ---- Detalhe ----
const post = ref(null);
const comments = ref([]);
const loadingDetail = ref(false);
const postImageFailed = ref(false);

async function loadDetail(mediaId) {
  if (!mediaId) return;
  loadingDetail.value = true;
  postImageFailed.value = false;
  resetReply();
  try {
    const { data } = await InstagramCommentedPostsAPI.show(mediaId);
    post.value = data?.post ?? { media_id: mediaId };
    comments.value = data?.comments ?? [];
  } catch (error) {
    post.value = { media_id: mediaId };
    comments.value = [];
    useAlert(t('INSTAGRAM_COMMENTS.LOAD_ERROR'));
  } finally {
    loadingDetail.value = false;
  }
}

// Aninha respostas (parent_id) sob os comentarios de topo.
const threadedComments = computed(() => {
  const byParent = new Map();
  comments.value.forEach(comment => {
    const key = comment.parent_id || 'root';
    if (!byParent.has(key)) byParent.set(key, []);
    byParent.get(key).push(comment);
  });
  return (byParent.get('root') || []).map(comment => ({
    ...comment,
    replies: byParent.get(comment.comment_id) || [],
  }));
});

const goToGallery = () =>
  router.push(accountRoute('instagram_comments_dashboard'));

const startReply = comment => {
  if (replyingTo.value === comment.comment_id) {
    resetReply();
    return;
  }
  replyingTo.value = comment.comment_id;
  replyText.value = '';
  replyMode.value = 'publico';
};

async function sendReply(comment) {
  const text = replyText.value.trim();
  if (!text) return;
  sendingReply.value = true;
  try {
    await ConversationAPI.replyToInstagramComment(comment.conversation_id, {
      commentId: comment.comment_id,
      publicReply: replyMode.value !== 'dm' ? text : undefined,
      dmReply: replyMode.value !== 'publico' ? text : undefined,
    });
    useAlert(t('INSTAGRAM_COMMENTS.REPLY_SENT'));
    resetReply();
  } catch (error) {
    useAlert(t('INSTAGRAM_COMMENTS.REPLY_ERROR'));
  } finally {
    sendingReply.value = false;
  }
}

// ---- Moderacao (excluir / ocultar / exibir) ----
const hiddenIds = reactive(new Set());
const busyIds = reactive(new Set());

// Mostra o motivo real do Meta (ex.: "10 - requires instagram_manage_comments")
// quando o backend devolve, senao a mensagem generica.
const moderationError = error =>
  error?.response?.data?.error || t('INSTAGRAM_COMMENTS.MODERATION_ERROR');

async function toggleHide(comment) {
  const isHidden = hiddenIds.has(comment.comment_id);
  busyIds.add(comment.comment_id);
  try {
    await ConversationAPI.moderateInstagramComment(comment.conversation_id, {
      commentId: comment.comment_id,
      moderation: isHidden ? 'unhide' : 'hide',
    });
    if (isHidden) hiddenIds.delete(comment.comment_id);
    else hiddenIds.add(comment.comment_id);
    useAlert(
      t(
        isHidden
          ? 'INSTAGRAM_COMMENTS.UNHIDDEN_OK'
          : 'INSTAGRAM_COMMENTS.HIDDEN_OK'
      )
    );
  } catch (error) {
    useAlert(moderationError(error));
  } finally {
    busyIds.delete(comment.comment_id);
  }
}

async function removeComment(comment) {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('INSTAGRAM_COMMENTS.DELETE_CONFIRM'))) return;
  busyIds.add(comment.comment_id);
  try {
    await ConversationAPI.moderateInstagramComment(comment.conversation_id, {
      commentId: comment.comment_id,
      moderation: 'delete',
    });
    comments.value = comments.value.filter(
      item =>
        item.comment_id !== comment.comment_id &&
        item.parent_id !== comment.comment_id
    );
    useAlert(t('INSTAGRAM_COMMENTS.DELETED_OK'));
  } catch (error) {
    useAlert(moderationError(error));
  } finally {
    busyIds.delete(comment.comment_id);
  }
}

const initials = name =>
  (name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(word => word[0])
    .join('')
    .toUpperCase();

onMounted(() => (props.mediaId ? loadDetail(props.mediaId) : loadPosts()));
watch(
  () => props.mediaId,
  mediaId => (mediaId ? loadDetail(mediaId) : loadPosts())
);
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-background">
    <!-- Cabecalho -->
    <header
      class="flex items-center flex-shrink-0 gap-2 px-6 py-4 border-b border-n-weak"
    >
      <button
        v-if="mediaId"
        type="button"
        class="flex items-center justify-center transition rounded-lg size-8 text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
        :aria-label="t('INSTAGRAM_COMMENTS.BACK')"
        @click="goToGallery"
      >
        <span class="i-lucide-arrow-left size-5" />
      </button>
      <span class="i-lucide-message-square-text size-5 text-n-brand" />
      <h1 class="text-lg font-semibold text-n-slate-12">
        {{ t('INSTAGRAM_COMMENTS.TITLE') }}
      </h1>
    </header>

    <div class="flex-1 min-h-0 overflow-y-auto">
      <!-- ======================= GALERIA ======================= -->
      <template v-if="!mediaId">
        <div
          v-if="loadingPosts"
          class="flex items-center justify-center py-24 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div
          v-else-if="!posts.length"
          class="flex flex-col items-center justify-center gap-3 py-24 text-center"
        >
          <span class="i-lucide-message-square-dashed size-10 text-n-slate-8" />
          <p class="max-w-sm text-sm text-n-slate-11">
            {{ t('INSTAGRAM_COMMENTS.EMPTY') }}
          </p>
        </div>
        <div
          v-else
          class="grid grid-cols-2 gap-4 p-6 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5"
        >
          <InstagramPostCard
            v-for="item in posts"
            :key="item.media_id"
            :post="item"
            @select="openPost"
          />
        </div>
      </template>

      <!-- ======================= DETALHE ======================= -->
      <template v-else>
        <div
          v-if="loadingDetail"
          class="flex items-center justify-center py-24 text-n-slate-11"
        >
          <Spinner />
        </div>
        <div v-else class="max-w-3xl p-6 mx-auto">
          <!-- Cabecalho do post -->
          <div
            class="flex gap-4 p-4 mb-6 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <div
              class="flex-shrink-0 overflow-hidden rounded-lg size-24 bg-n-alpha-2"
            >
              <img
                v-if="post?.image_url && !postImageFailed"
                :src="post.image_url"
                :alt="post?.caption || t('INSTAGRAM_COMMENTS.POST')"
                class="object-cover w-full h-full"
                @error="postImageFailed = true"
              />
              <div
                v-else
                class="flex items-center justify-center w-full h-full text-n-slate-8"
              >
                <span class="i-lucide-image size-8" />
              </div>
            </div>
            <div class="flex flex-col min-w-0 gap-1">
              <span
                class="text-xs font-medium tracking-wide uppercase text-n-slate-10"
              >
                {{ t('INSTAGRAM_COMMENTS.POST') }}
              </span>
              <p
                v-if="post?.caption"
                class="text-sm text-n-slate-12 line-clamp-3"
              >
                {{ post.caption }}
              </p>
              <a
                v-if="post?.permalink"
                :href="post.permalink"
                target="_blank"
                rel="noopener noreferrer"
                class="mt-1 text-xs font-medium text-n-brand hover:underline w-fit"
              >
                {{ t('INSTAGRAM_COMMENTS.VIEW_ON_INSTAGRAM') }}
              </a>
            </div>
          </div>

          <!-- Thread de comentarios -->
          <h2 class="mb-3 text-sm font-semibold text-n-slate-11">
            {{
              t('INSTAGRAM_COMMENTS.COMMENT_COUNT', { count: comments.length })
            }}
          </h2>
          <ul class="flex flex-col gap-3">
            <li
              v-for="comment in threadedComments"
              :key="comment.comment_id || comment.created_at"
              class="p-3 border rounded-xl border-n-weak bg-n-solid-1"
            >
              <div class="flex gap-3">
                <!-- Iniciais em vez de carregar o avatar (a representacao do ActiveStorage
                     da 500 quando o storage nao e compartilhado web/worker) -->
                <span
                  class="flex items-center justify-center flex-shrink-0 text-xs font-semibold rounded-full size-8 bg-n-alpha-2 text-n-slate-11"
                >
                  {{ initials(comment.author?.name) }}
                </span>
                <div class="flex flex-col min-w-0 gap-0.5 flex-1">
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-medium truncate text-n-slate-12">
                      {{
                        comment.author?.name || t('INSTAGRAM_COMMENTS.UNKNOWN')
                      }}
                    </span>
                    <span class="text-xs text-n-slate-10">
                      {{
                        shortTimestamp(dynamicTime(comment.created_at), true)
                      }}
                    </span>
                  </div>
                  <p class="text-sm break-words text-n-slate-12">
                    {{ comment.text }}
                  </p>
                  <div class="flex items-center gap-3 mt-1">
                    <button
                      type="button"
                      class="text-xs font-medium text-n-brand hover:underline"
                      @click="startReply(comment)"
                    >
                      {{ t('INSTAGRAM_COMMENTS.REPLY') }}
                    </button>
                    <button
                      type="button"
                      :disabled="busyIds.has(comment.comment_id)"
                      class="text-xs font-medium text-n-slate-11 hover:text-n-slate-12 disabled:opacity-50"
                      @click="toggleHide(comment)"
                    >
                      {{
                        hiddenIds.has(comment.comment_id)
                          ? t('INSTAGRAM_COMMENTS.UNHIDE')
                          : t('INSTAGRAM_COMMENTS.HIDE')
                      }}
                    </button>
                    <button
                      type="button"
                      :disabled="busyIds.has(comment.comment_id)"
                      class="text-xs font-medium text-n-ruby-9 hover:text-n-ruby-10 disabled:opacity-50"
                      @click="removeComment(comment)"
                    >
                      {{ t('INSTAGRAM_COMMENTS.DELETE') }}
                    </button>
                    <span
                      v-if="hiddenIds.has(comment.comment_id)"
                      class="px-1.5 py-0.5 text-[10px] font-medium rounded bg-n-alpha-2 text-n-slate-11"
                    >
                      {{ t('INSTAGRAM_COMMENTS.HIDDEN_BADGE') }}
                    </span>
                  </div>

                  <!-- Compositor de resposta -->
                  <div
                    v-if="replyingTo === comment.comment_id"
                    class="flex flex-col gap-2 p-3 mt-2 rounded-lg bg-n-alpha-1"
                  >
                    <div class="flex gap-1">
                      <button
                        v-for="mode in REPLY_MODES"
                        :key="mode"
                        type="button"
                        class="px-2.5 py-1 text-xs font-medium rounded-md transition"
                        :class="
                          replyMode === mode
                            ? 'bg-n-brand text-n-brand-text'
                            : 'bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12'
                        "
                        @click="replyMode = mode"
                      >
                        {{ t(`INSTAGRAM_COMMENTS.MODE.${mode.toUpperCase()}`) }}
                      </button>
                    </div>
                    <textarea
                      v-model="replyText"
                      rows="2"
                      :placeholder="t('INSTAGRAM_COMMENTS.REPLY_PLACEHOLDER')"
                      class="w-full px-3 py-2 text-sm border rounded-lg resize-none bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
                    />
                    <div class="flex items-center justify-end gap-2">
                      <button
                        type="button"
                        class="px-3 py-1.5 text-xs font-medium rounded-md text-n-slate-11 hover:text-n-slate-12"
                        @click="resetReply"
                      >
                        {{ t('INSTAGRAM_COMMENTS.CANCEL') }}
                      </button>
                      <button
                        type="button"
                        :disabled="!replyText.trim() || sendingReply"
                        class="px-3 py-1.5 text-xs font-semibold rounded-md bg-n-brand text-n-brand-text disabled:opacity-50"
                        @click="sendReply(comment)"
                      >
                        {{ t('INSTAGRAM_COMMENTS.SEND') }}
                      </button>
                    </div>
                  </div>

                  <!-- Respostas aninhadas -->
                  <ul
                    v-if="comment.replies.length"
                    class="flex flex-col gap-2 pl-3 mt-2 border-l border-n-weak"
                  >
                    <li
                      v-for="reply in comment.replies"
                      :key="reply.comment_id || reply.created_at"
                      class="flex flex-col gap-0.5"
                    >
                      <div class="flex items-center gap-2">
                        <span
                          class="text-xs font-medium truncate text-n-slate-12"
                        >
                          {{
                            reply.author?.name ||
                            t('INSTAGRAM_COMMENTS.UNKNOWN')
                          }}
                        </span>
                        <span class="text-xs text-n-slate-10">
                          {{
                            shortTimestamp(dynamicTime(reply.created_at), true)
                          }}
                        </span>
                      </div>
                      <p class="text-sm break-words text-n-slate-12">
                        {{ reply.text }}
                      </p>
                    </li>
                  </ul>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </template>
    </div>
  </section>
</template>
