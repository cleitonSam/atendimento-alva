<script setup>
import { ref, reactive, watch, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import PostsAPI from 'dashboard/api/instagramScheduledPosts';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const MAX_IMAGES = 10;

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
  caption: '',
  images: [], // { preview, url, uploading }
  schedule: 'now', // now | later
  scheduled_at: '',
});
const form = ref(blankForm());

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

const openCreate = () => {
  form.value = blankForm();
  mode.value = 'form';
};
const cancelForm = () => {
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

async function onFiles(event) {
  const files = Array.from(event.target.files || []);
  event.target.value = '';
  for (let i = 0; i < files.length; i += 1) {
    if (form.value.images.length >= MAX_IMAGES) {
      useAlert(t('INSTAGRAM_PUBLISH.MAX_IMAGES', { count: MAX_IMAGES }));
      break;
    }
    const file = files[i];
    // eslint-disable-next-line no-await-in-loop
    const preview = await readAsDataUrl(file);
    // reactive() garante que as escritas (image.url/uploading) disparem o render e
    // que o filtro por identidade (img !== image) funcione (proxy === proxy).
    const image = reactive({ preview, url: '', uploading: true });
    form.value.images.push(image);
    try {
      // eslint-disable-next-line no-await-in-loop
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
}

// Sobe o arquivo DIRETO pro ImageKit com a assinatura do backend (fetch cru, sem
// mandar os headers de auth do app pro ImageKit; a foto nao passa pelo nosso servidor).
async function uploadToImagekit(file) {
  const { data: auth } = await PostsAPI.imagekitAuth();
  if (!auth || auth.error) throw new Error(t('INSTAGRAM_PUBLISH.UPLOAD_ERROR'));

  const fd = new FormData();
  fd.append('file', file);
  fd.append('fileName', file.name || 'upload.jpg');
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

const removeImage = image => {
  form.value.images = form.value.images.filter(img => img !== image);
};

const uploadedUrls = computed(() =>
  form.value.images.filter(img => img.url).map(img => img.url)
);
// Paralelo a uploadedUrls (mesmo filtro/ordem) — pro backend poder deletar no ImageKit.
const uploadedFileIds = computed(() =>
  form.value.images.filter(img => img.url).map(img => img.fileId || '')
);
const anyUploading = computed(() =>
  form.value.images.some(img => img.uploading)
);
const canSave = computed(
  () =>
    form.value.inbox_id &&
    uploadedUrls.value.length > 0 &&
    !anyUploading.value &&
    (form.value.schedule === 'now' || form.value.scheduled_at)
);

async function save() {
  if (!canSave.value || saving.value) return;
  saving.value = true;
  try {
    await PostsAPI.create({
      instagram_scheduled_post: {
        inbox_id: form.value.inbox_id,
        caption: form.value.caption.trim(),
        image_urls: uploadedUrls.value,
        image_file_ids: uploadedFileIds.value,
        // datetime-local e hora LOCAL; converte pro instante UTC certo (o backend
        // interpreta string naive como UTC).
        scheduled_at:
          form.value.schedule === 'later'
            ? new Date(form.value.scheduled_at).toISOString()
            : null,
      },
    });
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

const STATUS_STYLE = {
  scheduled: 'bg-n-blue-3 text-n-blue-11',
  publishing: 'bg-n-amber-3 text-n-amber-11',
  published: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};
const statusStyle = status =>
  STATUS_STYLE[status] || 'bg-n-alpha-2 text-n-slate-11';
const statusLabel = status =>
  t(`INSTAGRAM_PUBLISH.STATUS.${status.toUpperCase()}`);

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
      <div class="flex items-center gap-2 min-w-0">
        <span class="i-lucide-image-plus size-5 text-n-brand" />
        <h1 class="text-lg font-semibold truncate text-n-slate-12">
          {{ t('INSTAGRAM_PUBLISH.TITLE') }}
        </h1>
      </div>
      <button
        v-if="mode === 'list'"
        type="button"
        class="flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-lg bg-n-brand text-n-brand-text hover:brightness-110"
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
            class="px-3 py-2 text-sm font-medium rounded-lg bg-n-brand text-n-brand-text hover:brightness-110"
            @click="openCreate"
          >
            {{ t('INSTAGRAM_PUBLISH.NEW') }}
          </button>
        </div>
        <ul v-else class="flex flex-col gap-3 p-6 mx-auto max-w-3xl">
          <li
            v-for="post in posts"
            :key="post.id"
            class="flex gap-3 p-4 border rounded-xl border-n-weak bg-n-solid-1"
          >
            <div
              class="flex-shrink-0 overflow-hidden rounded-lg size-16 bg-n-alpha-2"
            >
              <img
                v-if="post.image_urls && post.image_urls[0]"
                :src="post.image_urls[0]"
                alt=""
                class="object-cover w-full h-full"
              />
              <div
                v-else
                class="flex items-center justify-center w-full h-full text-n-slate-8"
              >
                <span class="i-lucide-image size-6" />
              </div>
            </div>
            <div class="flex flex-col min-w-0 gap-1 flex-1">
              <div class="flex items-center gap-2">
                <span
                  class="px-1.5 py-0.5 text-[10px] font-semibold rounded-full"
                  :class="statusStyle(post.status)"
                >
                  {{ statusLabel(post.status) }}
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
              class="self-start text-xs font-medium text-n-ruby-9 hover:text-n-ruby-10"
              @click="remove(post)"
            >
              {{ t('INSTAGRAM_PUBLISH.DELETE') }}
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
        <div v-if="igInboxes.length > 1" class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_PUBLISH.INBOX') }}
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

        <!-- Imagens -->
        <div class="flex flex-col gap-2">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_PUBLISH.IMAGES') }}
          </label>
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
                class="absolute flex items-center justify-center rounded-full top-1 right-1 size-5 bg-n-solid-1/90 text-n-slate-12 disabled:opacity-50"
                @click="removeImage(image)"
              >
                <span class="i-lucide-x size-3" />
              </button>
            </div>
            <label
              v-if="form.images.length < MAX_IMAGES"
              class="flex flex-col items-center justify-center gap-1 text-xs cursor-pointer border border-dashed rounded-lg size-20 border-n-weak text-n-slate-10 hover:border-n-brand hover:text-n-brand"
            >
              <span class="i-lucide-plus size-5" />
              {{ t('INSTAGRAM_PUBLISH.ADD_IMAGE') }}
              <input
                type="file"
                accept="image/*"
                multiple
                class="hidden"
                @change="onFiles"
              />
            </label>
          </div>
          <p class="text-xs text-n-slate-10">
            {{ t('INSTAGRAM_PUBLISH.IMAGES_HINT', { count: MAX_IMAGES }) }}
          </p>
        </div>

        <!-- Legenda -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_PUBLISH.CAPTION') }}
          </label>
          <textarea
            v-model="form.caption"
            rows="4"
            :placeholder="t('INSTAGRAM_PUBLISH.CAPTION_PH')"
            class="px-3 py-2 text-sm border rounded-lg resize-none bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
        </div>

        <!-- Quando -->
        <div class="flex flex-col gap-2">
          <label class="text-xs font-medium text-n-slate-11">
            {{ t('INSTAGRAM_PUBLISH.WHEN') }}
          </label>
          <div class="flex gap-2">
            <button
              type="button"
              class="px-3 py-1.5 text-xs font-medium rounded-md"
              :class="
                form.schedule === 'now'
                  ? 'bg-n-brand text-n-brand-text'
                  : 'bg-n-alpha-2 text-n-slate-11'
              "
              @click="form.schedule = 'now'"
            >
              {{ t('INSTAGRAM_PUBLISH.NOW') }}
            </button>
            <button
              type="button"
              class="px-3 py-1.5 text-xs font-medium rounded-md"
              :class="
                form.schedule === 'later'
                  ? 'bg-n-brand text-n-brand-text'
                  : 'bg-n-alpha-2 text-n-slate-11'
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
            class="px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 focus:outline-none focus:border-n-brand w-fit"
          />
        </div>

        <div class="flex items-center justify-end gap-2 pt-2">
          <button
            type="button"
            class="px-4 py-2 text-sm font-medium rounded-lg text-n-slate-11 hover:text-n-slate-12"
            @click="cancelForm"
          >
            {{ t('INSTAGRAM_PUBLISH.CANCEL') }}
          </button>
          <button
            type="submit"
            :disabled="!canSave || saving"
            class="px-4 py-2 text-sm font-semibold rounded-lg bg-n-brand text-n-brand-text disabled:opacity-50 hover:brightness-110"
          >
            {{
              form.schedule === 'later'
                ? t('INSTAGRAM_PUBLISH.SCHEDULE_BTN')
                : t('INSTAGRAM_PUBLISH.PUBLISH_BTN')
            }}
          </button>
        </div>
      </form>
    </div>
  </section>
</template>
