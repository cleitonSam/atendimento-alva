<script setup>
import { ref, watch, reactive, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import PostsAPI from 'dashboard/api/instagramScheduledPosts';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InstagramStudioTabs from './InstagramStudioTabs.vue';
import InstagramDmPreview from './InstagramDmPreview.vue';
import InstagramDmComposer from './InstagramDmComposer.vue';
import InstagramMediaPreview from './InstagramMediaPreview.vue';
import InstagramHashtagPicker from './InstagramHashtagPicker.vue';

const authFn = () => PostsAPI.imagekitAuth();

// Horarios "quentes" (hora local) pra sugestao de melhor horario de postagem.
const BEST_HOURS = [12, 18, 20];
const pad2 = n => String(n).padStart(2, '0');
const toLocalInput = dt =>
  `${dt.getFullYear()}-${pad2(dt.getMonth() + 1)}-${pad2(dt.getDate())}T${pad2(dt.getHours())}:${pad2(dt.getMinutes())}`;

const MAX_IMAGES = 10;
const MATCH_TYPES = ['contains', 'exact', 'any'];
const POST_TYPES = [
  { key: 'post', icon: 'i-lucide-image', accept: 'image/*', multiple: true },
  {
    key: 'reels',
    icon: 'i-lucide-clapperboard',
    accept: 'video/*',
    multiple: false,
  },
  {
    key: 'story',
    icon: 'i-lucide-camera',
    accept: 'image/*,video/*',
    multiple: false,
  },
];
const INPUT_CLASS =
  'w-full px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 transition focus:outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand/40';

const { t } = useI18n();
const store = useStore();
const inboxes = useMapGetter('inboxes/getInboxes');
const igInboxes = computed(() =>
  inboxes.value.filter(inbox => inbox.channel_type === INBOX_TYPES.INSTAGRAM)
);

const posts = ref([]);
const loading = ref(false);
const saving = ref(false);
const mode = ref('list'); // list | form

const blankForm = () => ({
  inbox_id: igInboxes.value[0]?.id ?? null,
  post_type: 'post', // post | reels | story
  caption: '',
  images: [], // { preview, url, fileId, uploading }
  video: null, // { preview, url, fileId, uploading }
  share_to_feed: true,
  first_comment: '',
  auto_story: false,
  schedule: 'now', // now | later
  scheduled_at: '',
  automation: {
    enabled: false,
    match_type: 'contains',
    keywords: '',
    dm_message: '',
    dm_card_title: '',
    dm_image_url: '',
    dm_image_file_id: '',
    dm_buttons: [],
    public_reply: '',
    once_per_user: true,
  },
});
const form = ref(blankForm());

const selectedInbox = computed(() =>
  igInboxes.value.find(inbox => inbox.id === form.value.inbox_id)
);
const username = computed(() => selectedInbox.value?.name || 'seu_perfil');
const isStory = computed(() => form.value.post_type === 'story');
const isReels = computed(() => form.value.post_type === 'reels');
const supportsAutomation = computed(() => !isStory.value); // story nao tem comentario publico
const imageLimit = computed(() => (isStory.value ? 1 : MAX_IMAGES));

// Se os inboxes carregam DEPOIS do form montar, preenche o inbox unico automaticamente.
watch(igInboxes, list => {
  if (!form.value.inbox_id && list.length) form.value.inbox_id = list[0].id;
});

async function load() {
  loading.value = true;
  try {
    const { data } = await PostsAPI.get();
    posts.value = data ?? [];
  } catch (error) {
    useAlert(t('INSTAGRAM_PUBLISH.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
}

// ---- Midia ----
function revokeVideo() {
  if (form.value.video?.preview?.startsWith('blob:')) {
    URL.revokeObjectURL(form.value.video.preview);
  }
}
function clearMedia() {
  revokeVideo();
  form.value.images = [];
  form.value.video = null;
}

const setPostType = type => {
  if (form.value.post_type === type) return;
  form.value.post_type = type;
  clearMedia();
  if (type === 'story') form.value.automation.enabled = false;
};

const openCreate = () => {
  clearMedia();
  form.value = blankForm();
  mode.value = 'form';
};
const cancelForm = () => {
  clearMedia();
  mode.value = 'list';
  form.value = blankForm();
};

const readAsDataUrl = file =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

// Sobe o arquivo DIRETO pro ImageKit com a assinatura do backend (fetch cru, sem
// mandar os headers de auth do app pro ImageKit; a midia nao passa pelo nosso servidor).
async function uploadToImagekit(file) {
  const { data: auth } = await PostsAPI.imagekitAuth();
  if (!auth || auth.error) throw new Error(t('INSTAGRAM_PUBLISH.UPLOAD_ERROR'));

  const fd = new FormData();
  fd.append('file', file);
  fd.append('fileName', file.name || 'upload');
  fd.append('publicKey', auth.public_key);
  fd.append('signature', auth.signature);
  fd.append('expire', auth.expire);
  fd.append('token', auth.token);
  fd.append('useUniqueFileName', 'true');

  const res = await fetch(auth.upload_url, { method: 'POST', body: fd });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || !json.url)
    throw new Error(json?.message || 'ImageKit upload failed');
  return { url: json.url, fileId: json.fileId };
}

async function addImage(file) {
  // reactive() garante que as escritas (image.url/uploading) disparem o render e
  // que o filtro por identidade (img !== image) funcione (proxy === proxy).
  const preview = await readAsDataUrl(file);
  const image = reactive({ preview, url: '', uploading: true });
  form.value.images.push(image);
  try {
    const uploaded = await uploadToImagekit(file);
    image.url = uploaded.url;
    image.fileId = uploaded.fileId;
  } catch (error) {
    form.value.images = form.value.images.filter(img => img !== image);
    useAlert(error?.message || t('INSTAGRAM_PUBLISH.UPLOAD_ERROR'));
  } finally {
    image.uploading = false;
  }
}

async function setVideo(file) {
  revokeVideo();
  form.value.images = []; // video e imagem sao exclusivos
  const video = reactive({
    preview: URL.createObjectURL(file),
    url: '',
    uploading: true,
  });
  form.value.video = video;
  try {
    const uploaded = await uploadToImagekit(file);
    video.url = uploaded.url;
    video.fileId = uploaded.fileId;
  } catch (error) {
    clearMedia();
    useAlert(error?.message || t('INSTAGRAM_PUBLISH.UPLOAD_ERROR'));
  } finally {
    if (form.value.video) form.value.video.uploading = false;
  }
}

async function onFiles(event) {
  const files = Array.from(event.target.files || []);
  event.target.value = '';
  for (let i = 0; i < files.length; i += 1) {
    const file = files[i];
    if (file.type.startsWith('video/')) {
      // reels/story em video: 1 video substitui tudo
      // eslint-disable-next-line no-await-in-loop
      await setVideo(file);
      break;
    }
    if (form.value.video) clearMedia(); // trocou video por imagem
    if (form.value.images.length >= imageLimit.value) {
      if (imageLimit.value < MAX_IMAGES) break;
      useAlert(t('INSTAGRAM_PUBLISH.MAX_IMAGES', { count: MAX_IMAGES }));
      break;
    }
    // eslint-disable-next-line no-await-in-loop
    await addImage(file);
  }
}

const removeImage = image => {
  form.value.images = form.value.images.filter(img => img !== image);
};
const removeVideo = () => clearMedia();

const uploadedUrls = computed(() =>
  form.value.images.filter(img => img.url).map(img => img.url)
);
// Paralelo a uploadedUrls (mesmo filtro/ordem) — pro backend poder deletar no ImageKit.
const uploadedFileIds = computed(() =>
  form.value.images.filter(img => img.url).map(img => img.fileId || '')
);
const mediaUploading = computed(
  () =>
    form.value.images.some(img => img.uploading) ||
    !!form.value.video?.uploading
);
const mediaReady = computed(() => {
  if (isReels.value) return !!form.value.video?.url;
  if (isStory.value)
    return !!form.value.video?.url || uploadedUrls.value.length > 0;
  return uploadedUrls.value.length > 0;
});
const previewImages = computed(() => form.value.images.map(img => img.preview));

const dmCoverUploading = ref(false);
const automationValid = computed(() => {
  const a = form.value.automation;
  if (!supportsAutomation.value || !a.enabled) return true;
  return (
    !!a.dm_message.trim() &&
    (a.match_type === 'any' || !!a.keywords.trim()) &&
    (!a.dm_image_url || !!(a.dm_card_title || '').trim()) &&
    !dmCoverUploading.value
  );
});
const canSave = computed(
  () =>
    form.value.inbox_id &&
    mediaReady.value &&
    !mediaUploading.value &&
    (form.value.schedule === 'now' || form.value.scheduled_at) &&
    automationValid.value
);

function pendingAutomationPayload() {
  const a = form.value.automation;
  if (!supportsAutomation.value || !a.enabled) return null;
  return {
    name:
      form.value.caption.trim().slice(0, 40) || t('INSTAGRAM_AUTOMATIONS.NEW'),
    match_type: a.match_type,
    keywords: a.match_type === 'any' ? '' : a.keywords.trim(),
    dm_message: a.dm_message.trim(),
    dm_card_title: (a.dm_card_title || '').trim(),
    dm_image_url: a.dm_image_url || '',
    dm_image_file_id: a.dm_image_file_id || '',
    dm_buttons: (a.dm_buttons || [])
      .filter(btn => btn.url?.trim())
      .map(btn => ({ title: (btn.title || '').trim(), url: btn.url.trim() })),
    public_reply: a.public_reply.trim(),
    once_per_user: a.once_per_user,
  };
}

// Insere as hashtags de um conjunto no 1o comentario (nao na legenda, pra nao poluir).
function insertHashtags(text) {
  const cur = form.value.first_comment.trim();
  form.value.first_comment = cur ? `${cur} ${text}` : text;
}

// Sugestao de melhor horario: proximos slots quentes (hora local) a partir de agora.
const bestSlots = computed(() => {
  const now = new Date();
  const slots = [];
  for (let d = 0; d < 3 && slots.length < 3; d += 1) {
    for (let i = 0; i < BEST_HOURS.length && slots.length < 3; i += 1) {
      const dt = new Date(now);
      dt.setDate(now.getDate() + d);
      dt.setHours(BEST_HOURS[i], 0, 0, 0);
      if (dt > now) slots.push(dt);
    }
  }
  return slots;
});
const slotLabel = dt =>
  dt.toLocaleString(undefined, {
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
function pickSlot(dt) {
  form.value.schedule = 'later';
  form.value.scheduled_at = toLocalInput(dt);
}

function buildPayload() {
  const base = {
    inbox_id: form.value.inbox_id,
    post_type: form.value.post_type,
    caption: isStory.value ? '' : form.value.caption.trim(),
    image_urls: uploadedUrls.value,
    image_file_ids: uploadedFileIds.value,
    video_url: form.value.video?.url || null,
    video_file_id: form.value.video?.fileId || null,
    share_to_feed: isReels.value ? form.value.share_to_feed : true,
    first_comment: isStory.value ? '' : form.value.first_comment.trim(),
    auto_story: form.value.post_type === 'post' ? form.value.auto_story : false,
    // datetime-local e hora LOCAL; converte pro instante UTC certo.
    scheduled_at:
      form.value.schedule === 'later'
        ? new Date(form.value.scheduled_at).toISOString()
        : null,
    pending_automation: pendingAutomationPayload(),
  };
  return base;
}

async function save() {
  if (!canSave.value || saving.value) return;
  saving.value = true;
  try {
    await PostsAPI.create({ instagram_scheduled_post: buildPayload() });
    useAlert(
      form.value.schedule === 'later'
        ? t('INSTAGRAM_PUBLISH.SCHEDULED_OK')
        : t('INSTAGRAM_PUBLISH.PUBLISHING_OK')
    );
    cancelForm();
    await load();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('INSTAGRAM_PUBLISH.SAVE_ERROR'));
  } finally {
    saving.value = false;
  }
}

async function remove(post) {
  // eslint-disable-next-line no-alert
  if (!window.confirm(t('INSTAGRAM_PUBLISH.DELETE_CONFIRM'))) return;
  try {
    await PostsAPI.delete(post.id);
    posts.value = posts.value.filter(p => p.id !== post.id);
  } catch (error) {
    useAlert(t('INSTAGRAM_PUBLISH.SAVE_ERROR'));
  }
}

// ---- Lista ----
const STATUS_STYLE = {
  scheduled: 'bg-n-blue-3 text-n-blue-11',
  publishing: 'bg-n-amber-3 text-n-amber-11',
  published: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};
const TYPE_ICON = {
  post: 'i-lucide-image',
  reels: 'i-lucide-clapperboard',
  story: 'i-lucide-camera',
};
const statusStyle = status =>
  STATUS_STYLE[status] || 'bg-n-alpha-2 text-n-slate-11';
const statusLabel = status =>
  t(`INSTAGRAM_PUBLISH.STATUS.${status.toUpperCase()}`);
const typeLabel = type =>
  t(`INSTAGRAM_PUBLISH.TYPE.${(type || 'post').toUpperCase()}`);
const postThumb = post => post.image_urls?.[0] || '';

const whenLabel = post => {
  const iso = post.status === 'published' ? post.updated_at : post.scheduled_at;
  if (!iso) return '';
  return new Date(iso).toLocaleString();
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
      <InstagramStudioTabs />
      <button
        v-if="mode === 'list'"
        type="button"
        class="flex items-center gap-1.5 px-3 py-2 text-sm font-medium transition rounded-lg bg-n-brand text-n-brand-text hover:brightness-110"
        @click="openCreate"
      >
        <span class="i-lucide-plus size-4" />
        {{ t('INSTAGRAM_PUBLISH.NEW') }}
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
          v-else-if="!posts.length"
          class="flex flex-col items-center justify-center gap-3 py-24 text-center"
        >
          <span class="i-lucide-image-plus size-10 text-n-slate-8" />
          <p class="max-w-sm text-sm text-n-slate-11">
            {{ t('INSTAGRAM_PUBLISH.EMPTY') }}
          </p>
          <button
            type="button"
            class="px-3 py-2 text-sm font-medium transition rounded-lg bg-n-brand text-n-brand-text hover:brightness-110"
            @click="openCreate"
          >
            {{ t('INSTAGRAM_PUBLISH.NEW') }}
          </button>
        </div>
        <ul v-else class="flex flex-col gap-3 p-6 mx-auto max-w-3xl">
          <li
            v-for="post in posts"
            :key="post.id"
            class="flex gap-3 p-4 transition border rounded-xl border-n-weak bg-n-solid-1 hover:border-n-slate-5"
          >
            <div
              class="relative flex-shrink-0 overflow-hidden rounded-lg size-16 bg-n-alpha-2"
            >
              <img
                v-if="postThumb(post)"
                :src="postThumb(post)"
                alt=""
                class="object-cover w-full h-full"
              />
              <div
                v-else
                class="flex items-center justify-center w-full h-full text-n-slate-8"
              >
                <span
                  :class="TYPE_ICON[post.post_type] || TYPE_ICON.post"
                  class="size-6"
                />
              </div>
              <span
                class="absolute flex items-center justify-center rounded-md bottom-1 left-1 size-5 bg-black/55 text-white/95"
              >
                <span
                  :class="TYPE_ICON[post.post_type] || TYPE_ICON.post"
                  class="size-3"
                />
              </span>
            </div>
            <div class="flex flex-col min-w-0 gap-1 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <span
                  class="px-1.5 py-0.5 text-[10px] font-semibold rounded-full"
                  :class="statusStyle(post.status)"
                >
                  {{ statusLabel(post.status) }}
                </span>
                <span
                  class="text-[10px] font-medium text-n-slate-10 uppercase tracking-wide"
                >
                  {{ typeLabel(post.post_type) }}
                </span>
                <span
                  v-if="post.image_urls && post.image_urls.length > 1"
                  class="text-[10px] text-n-slate-10"
                >
                  {{
                    t('INSTAGRAM_PUBLISH.CAROUSEL', {
                      count: post.image_urls.length,
                    })
                  }}
                </span>
                <span class="text-xs text-n-slate-10">{{
                  whenLabel(post)
                }}</span>
              </div>
              <span class="text-sm truncate text-n-slate-12">
                {{ post.caption || t('INSTAGRAM_PUBLISH.NO_CAPTION') }}
              </span>
              <a
                v-if="post.permalink"
                :href="post.permalink"
                target="_blank"
                rel="noopener noreferrer"
                class="text-xs font-medium text-n-brand hover:underline w-fit"
              >
                {{ t('INSTAGRAM_PUBLISH.VIEW') }}
              </a>
              <span v-if="post.last_error" class="text-xs text-n-ruby-10">
                {{ post.last_error }}
              </span>
            </div>
            <button
              type="button"
              class="self-start text-xs font-medium transition text-n-ruby-9 hover:text-n-ruby-10"
              @click="remove(post)"
            >
              {{ t('INSTAGRAM_PUBLISH.DELETE') }}
            </button>
          </li>
        </ul>
      </template>

      <!-- =================== COMPOSITOR (2 painéis) =================== -->
      <div
        v-else
        class="grid gap-8 p-6 mx-auto max-w-5xl lg:grid-cols-[minmax(0,1fr)_18rem]"
      >
        <!-- ---- Coluna do formulario ---- -->
        <form class="flex flex-col gap-4" @submit.prevent="save">
          <!-- Seletor de formato -->
          <div class="grid grid-cols-3 gap-2">
            <button
              v-for="type in POST_TYPES"
              :key="type.key"
              type="button"
              class="flex flex-col items-center gap-1.5 px-3 py-3 text-xs font-semibold transition border rounded-xl"
              :class="
                form.post_type === type.key
                  ? 'border-n-brand bg-n-brand/10 text-n-slate-12'
                  : 'border-n-weak text-n-slate-11 hover:border-n-slate-6 hover:text-n-slate-12'
              "
              @click="setPostType(type.key)"
            >
              <span :class="type.icon" class="size-5" />
              {{ t(`INSTAGRAM_PUBLISH.TYPE.${type.key.toUpperCase()}`) }}
            </button>
          </div>

          <!-- SECAO: Midia -->
          <fieldset
            class="flex flex-col gap-4 p-5 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <legend class="flex items-center gap-2.5 px-1 -mb-1">
              <span
                class="flex items-center justify-center rounded-lg size-8 bg-n-alpha-2 text-n-brand"
              >
                <span class="i-lucide-image size-4" />
              </span>
              <span class="text-sm font-semibold text-n-slate-12">
                {{ t('INSTAGRAM_PUBLISH.SECTION_MEDIA') }}
              </span>
            </legend>

            <div v-if="igInboxes.length > 1" class="flex flex-col gap-1.5">
              <label class="text-xs font-medium text-n-slate-11">
                {{ t('INSTAGRAM_PUBLISH.INBOX') }}
              </label>
              <select v-model="form.inbox_id" :class="INPUT_CLASS">
                <option
                  v-for="inbox in igInboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </div>

            <!-- Video (reels / story-video) -->
            <div v-if="form.video" class="flex flex-col gap-2">
              <div
                class="relative w-40 overflow-hidden border rounded-lg aspect-[9/16] border-n-weak bg-n-alpha-2"
              >
                <video
                  :src="form.video.preview"
                  class="object-cover w-full h-full"
                  muted
                  playsinline
                />
                <div
                  v-if="form.video.uploading"
                  class="absolute inset-0 flex items-center justify-center bg-n-alpha-black2"
                >
                  <Spinner class="text-white" />
                </div>
                <button
                  type="button"
                  :disabled="form.video.uploading"
                  :aria-label="t('INSTAGRAM_PUBLISH.REMOVE_IMAGE')"
                  class="absolute flex items-center justify-center transition rounded-full top-1 right-1 size-5 bg-n-solid-1/90 text-n-slate-12 hover:bg-n-solid-1 disabled:opacity-50"
                  @click="removeVideo"
                >
                  <span class="i-lucide-x size-3" />
                </button>
              </div>
            </div>

            <!-- Imagens (post / story-imagem) -->
            <div v-if="!form.video" class="flex flex-col gap-2">
              <div class="flex flex-wrap gap-2">
                <div
                  v-for="(image, index) in form.images"
                  :key="index"
                  class="relative overflow-hidden border rounded-lg size-20 border-n-weak bg-n-alpha-2"
                >
                  <img
                    :src="image.preview"
                    alt=""
                    class="object-cover w-full h-full"
                  />
                  <div
                    v-if="image.uploading"
                    class="absolute inset-0 flex items-center justify-center bg-n-alpha-black2"
                  >
                    <Spinner class="text-white" />
                  </div>
                  <button
                    type="button"
                    :disabled="image.uploading"
                    :aria-label="t('INSTAGRAM_PUBLISH.REMOVE_IMAGE')"
                    class="absolute flex items-center justify-center transition rounded-full top-1 right-1 size-5 bg-n-solid-1/90 text-n-slate-12 hover:bg-n-solid-1 disabled:opacity-50"
                    @click="removeImage(image)"
                  >
                    <span class="i-lucide-x size-3" />
                  </button>
                </div>
                <label
                  v-if="form.images.length < imageLimit"
                  class="flex flex-col items-center justify-center gap-1 text-xs text-center transition cursor-pointer border border-dashed rounded-lg size-20 border-n-weak text-n-slate-10 hover:border-n-brand hover:text-n-brand"
                >
                  <span
                    :class="isReels ? 'i-lucide-clapperboard' : 'i-lucide-plus'"
                    class="size-5"
                  />
                  {{
                    isReels
                      ? t('INSTAGRAM_PUBLISH.ADD_VIDEO')
                      : t('INSTAGRAM_PUBLISH.ADD_IMAGE')
                  }}
                  <input
                    type="file"
                    :accept="
                      isStory
                        ? 'image/*,video/*'
                        : isReels
                          ? 'video/*'
                          : 'image/*'
                    "
                    :multiple="form.post_type === 'post'"
                    class="hidden"
                    @change="onFiles"
                  />
                </label>
              </div>
              <p class="text-xs text-n-slate-10">
                {{
                  isReels
                    ? t('INSTAGRAM_PUBLISH.REELS_HINT')
                    : isStory
                      ? t('INSTAGRAM_PUBLISH.STORY_HINT')
                      : t('INSTAGRAM_PUBLISH.IMAGES_HINT', {
                          count: MAX_IMAGES,
                        })
                }}
              </p>
            </div>

            <!-- Legenda (post / reels) -->
            <div v-if="!isStory" class="flex flex-col gap-1.5">
              <label class="text-xs font-medium text-n-slate-11">
                {{ t('INSTAGRAM_PUBLISH.CAPTION') }}
              </label>
              <textarea
                v-model="form.caption"
                rows="4"
                :placeholder="t('INSTAGRAM_PUBLISH.CAPTION_PH')"
                class="resize-none"
                :class="[INPUT_CLASS]"
              />
            </div>

            <!-- Compartilhar reels no feed -->
            <label
              v-if="isReels"
              class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
            >
              <input
                v-model="form.share_to_feed"
                type="checkbox"
                class="accent-n-brand size-4"
              />
              {{ t('INSTAGRAM_PUBLISH.SHARE_TO_FEED') }}
            </label>
          </fieldset>

          <!-- SECAO: Quando -->
          <fieldset
            class="flex flex-col gap-3 p-5 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <legend class="flex items-center gap-2.5 px-1 -mb-1">
              <span
                class="flex items-center justify-center rounded-lg size-8 bg-n-alpha-2 text-n-brand"
              >
                <span class="i-lucide-calendar-clock size-4" />
              </span>
              <span class="text-sm font-semibold text-n-slate-12">
                {{ t('INSTAGRAM_PUBLISH.SECTION_WHEN') }}
              </span>
            </legend>
            <div class="flex gap-2">
              <button
                type="button"
                class="px-3 py-1.5 text-xs font-medium transition rounded-md"
                :class="
                  form.schedule === 'now'
                    ? 'bg-n-brand text-n-brand-text'
                    : 'bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12'
                "
                @click="form.schedule = 'now'"
              >
                {{ t('INSTAGRAM_PUBLISH.NOW') }}
              </button>
              <button
                type="button"
                class="px-3 py-1.5 text-xs font-medium transition rounded-md"
                :class="
                  form.schedule === 'later'
                    ? 'bg-n-brand text-n-brand-text'
                    : 'bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12'
                "
                @click="form.schedule = 'later'"
              >
                {{ t('INSTAGRAM_PUBLISH.SCHEDULE') }}
              </button>
            </div>
            <input
              v-if="form.schedule === 'later'"
              v-model="form.scheduled_at"
              type="datetime-local"
              class="w-fit"
              :class="[INPUT_CLASS]"
            />
            <!-- Sugestao de melhor horario -->
            <div class="flex flex-col gap-1.5">
              <span class="text-xs font-medium text-n-slate-11">
                {{ t('INSTAGRAM_PUBLISH.BEST_TIME') }}
              </span>
              <div class="flex flex-wrap gap-1.5">
                <button
                  v-for="(slot, i) in bestSlots"
                  :key="i"
                  type="button"
                  class="px-2.5 py-1 text-xs font-medium capitalize transition border rounded-full border-n-weak text-n-slate-11 hover:border-n-brand hover:text-n-brand"
                  @click="pickSlot(slot)"
                >
                  {{ slotLabel(slot) }}
                </button>
              </div>
            </div>
          </fieldset>

          <!-- SECAO: Engajamento (post / reels) -->
          <fieldset
            v-if="!isStory"
            class="flex flex-col gap-4 p-5 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <legend class="flex items-center gap-2.5 px-1 -mb-1">
              <span
                class="flex items-center justify-center rounded-lg size-8 bg-n-alpha-2 text-n-brand"
              >
                <span class="i-lucide-sparkles size-4" />
              </span>
              <span class="text-sm font-semibold text-n-slate-12">
                {{ t('INSTAGRAM_PUBLISH.SECTION_ENGAGEMENT') }}
              </span>
            </legend>

            <!-- 1o comentario -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-medium text-n-slate-11">
                {{ t('INSTAGRAM_PUBLISH.FIRST_COMMENT') }}
              </label>
              <textarea
                v-model="form.first_comment"
                rows="2"
                :placeholder="t('INSTAGRAM_PUBLISH.FIRST_COMMENT_PH')"
                class="resize-none"
                :class="[INPUT_CLASS]"
              />
              <p class="text-xs text-n-slate-10">
                {{ t('INSTAGRAM_PUBLISH.FIRST_COMMENT_HINT') }}
              </p>
            </div>

            <!-- Conjuntos de hashtags -->
            <InstagramHashtagPicker
              :current-text="form.first_comment"
              :caption-text="form.caption"
              @insert="insertHashtags"
            />

            <!-- Auto-story (so post de feed) -->
            <label
              v-if="form.post_type === 'post'"
              class="flex items-start gap-2 text-sm cursor-pointer text-n-slate-12"
            >
              <input
                v-model="form.auto_story"
                type="checkbox"
                class="mt-0.5 accent-n-brand size-4"
              />
              <span class="flex flex-col">
                <span>{{ t('INSTAGRAM_PUBLISH.AUTO_STORY') }}</span>
                <span class="text-xs text-n-slate-10">
                  {{ t('INSTAGRAM_PUBLISH.AUTO_STORY_HINT') }}
                </span>
              </span>
            </label>
          </fieldset>

          <!-- SECAO: Automacao (post / reels) -->
          <fieldset
            v-if="supportsAutomation"
            class="flex flex-col gap-3 p-5 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <legend
              class="flex items-center justify-between w-full gap-2 px-1 -mb-1"
            >
              <span class="flex items-center gap-2.5">
                <span
                  class="flex items-center justify-center rounded-lg size-8 bg-n-alpha-2 text-n-brand"
                >
                  <span class="i-lucide-bot-message-square size-4" />
                </span>
                <span class="flex flex-col">
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ t('INSTAGRAM_PUBLISH.SECTION_AUTOMATION') }}
                  </span>
                  <span class="text-xs text-n-slate-10">
                    {{ t('INSTAGRAM_PUBLISH.AUTOMATION_HINT') }}
                  </span>
                </span>
              </span>
              <label
                class="flex items-center gap-2 text-xs font-medium cursor-pointer text-n-slate-11"
              >
                <input
                  v-model="form.automation.enabled"
                  type="checkbox"
                  class="accent-n-brand size-4"
                />
                {{ t('INSTAGRAM_PUBLISH.AUTOMATION_ENABLE') }}
              </label>
            </legend>

            <div
              v-if="form.automation.enabled"
              class="flex flex-col gap-3 pt-1"
            >
              <!-- Gatilho -->
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-medium text-n-slate-11">
                  {{ t('INSTAGRAM_AUTOMATIONS.TRIGGER') }}
                </label>
                <div class="flex gap-2">
                  <button
                    v-for="matchType in MATCH_TYPES"
                    :key="matchType"
                    type="button"
                    class="px-2.5 py-1 text-xs font-medium transition rounded-md"
                    :class="
                      form.automation.match_type === matchType
                        ? 'bg-n-brand text-n-brand-text'
                        : 'bg-n-alpha-2 text-n-slate-11 hover:text-n-slate-12'
                    "
                    @click="form.automation.match_type = matchType"
                  >
                    {{
                      t(
                        `INSTAGRAM_AUTOMATIONS.MATCH.${matchType.toUpperCase()}`
                      )
                    }}
                  </button>
                </div>
                <input
                  v-if="form.automation.match_type !== 'any'"
                  v-model="form.automation.keywords"
                  type="text"
                  :placeholder="t('INSTAGRAM_AUTOMATIONS.KEYWORDS_PH')"
                  :class="INPUT_CLASS"
                />
              </div>

              <!-- DM (imagem + titulo + mensagem + botoes + resposta publica) -->
              <InstagramDmComposer
                v-model="form.automation"
                :auth-fn="authFn"
                @update:uploading="dmCoverUploading = $event"
              />

              <label
                class="flex items-center gap-2 text-sm cursor-pointer text-n-slate-12"
              >
                <input
                  v-model="form.automation.once_per_user"
                  type="checkbox"
                  class="accent-n-brand size-4"
                />
                {{ t('INSTAGRAM_AUTOMATIONS.ONCE_PER_USER') }}
              </label>
            </div>
          </fieldset>

          <!-- Acoes -->
          <div class="flex items-center justify-end gap-2 pt-1">
            <button
              type="button"
              class="px-4 py-2 text-sm font-medium transition rounded-lg text-n-slate-11 hover:text-n-slate-12"
              @click="cancelForm"
            >
              {{ t('INSTAGRAM_PUBLISH.CANCEL') }}
            </button>
            <button
              type="submit"
              :disabled="!canSave || saving"
              class="flex items-center gap-1.5 px-4 py-2 text-sm font-semibold transition rounded-lg bg-n-brand text-n-brand-text disabled:opacity-50 hover:brightness-110"
            >
              <Spinner v-if="saving" class="size-4" />
              {{
                form.schedule === 'later'
                  ? t('INSTAGRAM_PUBLISH.SCHEDULE_BTN')
                  : t('INSTAGRAM_PUBLISH.PUBLISH_BTN')
              }}
            </button>
          </div>
        </form>

        <!-- ---- Coluna da PREVIA (sticky) ---- -->
        <aside class="lg:sticky lg:top-0 h-fit flex flex-col gap-4">
          <span
            class="text-[10px] font-semibold tracking-wide uppercase text-n-slate-10"
          >
            {{ t('INSTAGRAM_PUBLISH.PREVIEW.TITLE') }}
          </span>
          <InstagramMediaPreview
            :username="username"
            :post-type="form.post_type"
            :images="previewImages"
            :video="form.video"
            :caption="form.caption"
          />
          <InstagramDmPreview
            v-if="supportsAutomation && form.automation.enabled"
            :name="username"
            :public-reply="form.automation.public_reply"
            :dm-message="form.automation.dm_message"
            :card-title="form.automation.dm_card_title"
            :image="form.automation.dm_image_url"
            :buttons="form.automation.dm_buttons"
          />
        </aside>
      </div>
    </div>
  </section>
</template>
