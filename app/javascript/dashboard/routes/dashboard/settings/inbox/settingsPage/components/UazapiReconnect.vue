<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: { type: Object, required: true },
});

const accountId = useMapGetter('getCurrentAccountId');
const baseUrl = computed(
  () => `/api/v1/accounts/${accountId.value}/inboxes/${props.inbox.id}`
);

const status = ref('');
const qrcode = ref('');
const loading = ref(false);
let pollTimer = null;

const connected = computed(() => status.value === 'connected');

const checkStatus = async () => {
  try {
    const { data } = await axios.get(`${baseUrl.value}/uazapi_status`);
    status.value = data.status || '';
    if (data.qrcode) qrcode.value = data.qrcode;
    if (data.connected) stopPolling();
  } catch (e) {
    // erro transitório de rede não deve parar o painel
  }
};

const reconnect = async () => {
  loading.value = true;
  qrcode.value = '';
  try {
    const { data } = await axios.post(`${baseUrl.value}/uazapi_setup`);
    qrcode.value = data.qrcode || '';
    status.value = data.status || 'connecting';
    startPolling();
  } catch (e) {
    status.value = 'erro';
  } finally {
    loading.value = false;
  }
};

const startPolling = () => {
  stopPolling();
  pollTimer = setInterval(checkStatus, 3000);
};
const stopPolling = () => {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
};

onMounted(checkStatus);
onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="p-4 mb-4 rounded-xl border border-n-weak bg-n-solid-2">
    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-2">
        <span
          class="w-2.5 h-2.5 rounded-full"
          :class="connected ? 'bg-green-500' : 'bg-amber-400 animate-pulse'"
        />
        <span class="text-sm font-medium text-n-slate-12">
          {{ connected ? 'WhatsApp conectado' : 'WhatsApp desconectado' }}
        </span>
        <span class="text-xs text-n-slate-10">({{ status || 'verificando…' }})</span>
      </div>
      <NextButton
        v-if="!connected"
        :is-loading="loading"
        variant="outline"
        label="Reconectar (gerar QR)"
        @click="reconnect"
      />
    </div>

    <div v-if="!connected && qrcode" class="flex flex-col items-center gap-2 mt-4">
      <p class="text-xs text-n-slate-11 text-center max-w-sm m-0">
        No celular: <b>WhatsApp → Aparelhos conectados → Conectar aparelho</b> e aponte
        para o código. Conecta sozinho.
      </p>
      <div class="w-56 h-56 flex items-center justify-center border border-n-weak rounded-xl bg-white p-3">
        <img :src="qrcode" alt="QR Code UAZAPI" class="w-full h-full object-contain" />
      </div>
    </div>
  </div>
</template>
