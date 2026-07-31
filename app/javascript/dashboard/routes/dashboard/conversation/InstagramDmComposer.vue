<script setup>
import { ref, watch, computed, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useImagekitUpload } from 'dashboard/composables/useImagekitUpload';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

// Construtor da DM da automacao (compartilhado entre Automacoes e Publicacao).
// modelValue: { dm_message, dm_card_title, dm_image_url, dm_image_file_id,
//               dm_buttons: [{title,url}], public_reply }
// authFn: fn que devolve a assinatura do ImageKit (upload da capa do card).
const props = defineProps({
  modelValue: { type: Object, required: true },
  authFn: { type: Function, required: true },
});
const emit = defineEmits(['update:modelValue', 'update:uploading']);

const { t } = useI18n();
const { uploadToImagekit } = useImagekitUpload(props.authFn);

const MAX_BUTTONS = 3;
const INPUT_CLASS =
  'w-full px-3 py-2 text-sm border rounded-lg bg-n-background border-n-weak text-n-slate-12 transition focus:outline-none focus:border-n-brand focus:ring-1 focus:ring-n-brand/40';

const imageUploading = ref(false);
const localPreview = ref('');

// Avisa o pai quando a capa esta subindo, pra ele travar Salvar/Publicar e nao perder a imagem.
watch(imageUploading, value => emit('update:uploading', value));
// Se o composer desmonta no meio do upload (desmarcar automacao, trocar formato, cancelar),
// o watch para e o emit(false) do finally se perde -> libera o pai aqui pra nao travar o botao.
onBeforeUnmount(() => emit('update:uploading', false));

function set(patch) {
  emit('update:modelValue', { ...props.modelValue, ...patch });
}

const buttons = computed(() => props.modelValue.dm_buttons || []);
const cover = computed(
  () => localPreview.value || props.modelValue.dm_image_url || ''
);
const hasImage = computed(() => !!cover.value);

const readAsDataUrl = file =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });

async function onImage(event) {
  const file = (event.target.files || [])[0];
  event.target.value = '';
  if (!file) return;
  localPreview.value = await readAsDataUrl(file);
  imageUploading.value = true;
  try {
    const up = await uploadToImagekit(file);
    set({ dm_image_url: up.url, dm_image_file_id: up.fileId });
  } catch (error) {
    localPreview.value = '';
    useAlert(error?.message || t('INSTAGRAM_DM.UPLOAD_ERROR'));
  } finally {
    imageUploading.value = false;
  }
}
function removeImage() {
  localPreview.value = '';
  set({ dm_image_url: '', dm_image_file_id: '' });
}

function addButton() {
  if (buttons.value.length >= MAX_BUTTONS) return;
  set({ dm_buttons: [...buttons.value, { title: '', url: '' }] });
}
function removeButton(index) {
  set({ dm_buttons: buttons.value.filter((_, i) => i !== index) });
}
function updateButton(index, field, value) {
  set({
    dm_buttons: buttons.value.map((btn, i) =>
      i === index ? { ...btn, [field]: value } : btn
    ),
  });
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Capa do card (opcional) -->
    <div class="flex flex-col gap-1.5">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('INSTAGRAM_DM.IMAGE') }}
      </label>
      <div class="flex items-start gap-3">
        <div
          v-if="hasImage"
          class="relative w-24 overflow-hidden border rounded-lg aspect-[1.91/1] border-n-weak bg-n-alpha-2"
        >
          <img :src="cover" alt="" class="object-cover w-full h-full" />
          <div
            v-if="imageUploading"
            class="absolute inset-0 flex items-center justify-center bg-n-alpha-black2"
          >
            <Spinner class="text-white" />
          </div>
          <button
            type="button"
            :disabled="imageUploading"
            :aria-label="t('INSTAGRAM_DM.REMOVE_IMAGE')"
            class="absolute flex items-center justify-center transition rounded-full top-1 right-1 size-5 bg-n-solid-1/90 text-n-slate-12 hover:bg-n-solid-1 disabled:opacity-50"
            @click="removeImage"
          >
            <span class="i-lucide-x size-3" />
          </button>
        </div>
        <label
          v-else
          class="flex flex-col items-center justify-center w-24 gap-1 text-xs text-center transition cursor-pointer border border-dashed rounded-lg aspect-[1.91/1] border-n-weak text-n-slate-10 hover:border-n-brand hover:text-n-brand"
        >
          <span class="i-lucide-image-plus size-5" />
          {{ t('INSTAGRAM_DM.ADD_IMAGE') }}
          <input
            type="file"
            accept="image/*"
            class="hidden"
            @change="onImage"
          />
        </label>
        <p class="flex-1 text-xs text-n-slate-10">
          {{ t('INSTAGRAM_DM.IMAGE_HINT') }}
        </p>
      </div>
    </div>

    <!-- Titulo do card (so com imagem) -->
    <div v-if="hasImage" class="flex flex-col gap-1.5">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('INSTAGRAM_DM.CARD_TITLE') }}
      </label>
      <input
        :value="modelValue.dm_card_title"
        type="text"
        maxlength="80"
        :placeholder="t('INSTAGRAM_DM.CARD_TITLE_PH')"
        :class="INPUT_CLASS"
        @input="set({ dm_card_title: $event.target.value })"
      />
    </div>

    <!-- Mensagem (texto no modo simples; subtitulo no modo card) -->
    <div class="flex flex-col gap-1.5">
      <label class="text-xs font-medium text-n-slate-11">
        {{ hasImage ? t('INSTAGRAM_DM.SUBTITLE') : t('INSTAGRAM_DM.MESSAGE') }}
      </label>
      <textarea
        :value="modelValue.dm_message"
        :rows="hasImage ? 2 : 3"
        :maxlength="hasImage ? 80 : 640"
        :placeholder="t('INSTAGRAM_DM.MESSAGE_PH')"
        class="resize-none"
        :class="[INPUT_CLASS]"
        @input="set({ dm_message: $event.target.value })"
      />
      <p v-if="hasImage" class="text-xs text-n-slate-10">
        {{ t('INSTAGRAM_DM.SUBTITLE_HINT') }}
      </p>
    </div>

    <!-- Botoes (ate 3) -->
    <div class="flex flex-col gap-2">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('INSTAGRAM_DM.BUTTONS') }}
      </label>
      <div v-for="(btn, index) in buttons" :key="index" class="flex gap-2">
        <input
          :value="btn.title"
          type="text"
          maxlength="20"
          :placeholder="t('INSTAGRAM_DM.BUTTON_LABEL_PH')"
          class="w-32"
          :class="[INPUT_CLASS]"
          @input="updateButton(index, 'title', $event.target.value)"
        />
        <input
          :value="btn.url"
          type="url"
          :placeholder="t('INSTAGRAM_DM.BUTTON_URL_PH')"
          class="flex-1"
          :class="[INPUT_CLASS]"
          @input="updateButton(index, 'url', $event.target.value)"
        />
        <button
          type="button"
          :aria-label="t('INSTAGRAM_DM.REMOVE_BUTTON')"
          class="flex items-center justify-center flex-shrink-0 transition rounded-lg size-9 text-n-slate-10 hover:bg-n-alpha-2 hover:text-n-ruby-10"
          @click="removeButton(index)"
        >
          <span class="i-lucide-trash-2 size-4" />
        </button>
      </div>
      <button
        v-if="buttons.length < MAX_BUTTONS"
        type="button"
        class="flex items-center gap-1.5 px-3 py-2 text-xs font-medium transition border border-dashed rounded-lg w-fit border-n-weak text-n-slate-11 hover:border-n-brand hover:text-n-brand"
        @click="addButton"
      >
        <span class="i-lucide-plus size-4" />
        {{ t('INSTAGRAM_DM.ADD_BUTTON') }}
      </button>
    </div>

    <!-- Resposta publica -->
    <div class="flex flex-col gap-1.5">
      <label class="text-xs font-medium text-n-slate-11">
        {{ t('INSTAGRAM_DM.PUBLIC_REPLY') }}
      </label>
      <input
        :value="modelValue.public_reply"
        type="text"
        :placeholder="t('INSTAGRAM_DM.PUBLIC_REPLY_PH')"
        :class="INPUT_CLASS"
        @input="set({ public_reply: $event.target.value })"
      />
    </div>
  </div>
</template>
