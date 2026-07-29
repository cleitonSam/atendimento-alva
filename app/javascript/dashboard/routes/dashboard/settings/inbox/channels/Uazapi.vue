<script setup>
import { ref, reactive, computed, onBeforeUnmount } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import NextButton from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const accountId = useMapGetter('getCurrentAccountId');

// O servidor UAZAPI e o admin token são infraestrutura (multi-cliente): ficam SEMPRE
// no ENV (UAZAPI_URL / UAZAPI_ADMIN_TOKEN). O cliente nunca digita isso — só informa
// nome + número. Se o ENV não estiver configurado, mostramos um aviso ao invés do form.
const uazapiConfigured = window.chatwootConfig?.uazapiConfigured === true;

// step: 'form' (nome + numero) -> 'qr' (escanear) -> 'connected'
const step = ref('form');
const creating = ref(false);
const connecting = ref(false);
const qrcode = ref('');
const connState = ref('');
const inboxId = ref(null);
let pollTimer = null;

const state = reactive({
  inboxName: '',
  phoneNumber: '',
});

const rules = {
  inboxName: { required },
  phoneNumber: { required, isPhoneE164OrEmpty },
};
const v$ = useVuelidate(rules, state);

const baseUrl = computed(
  () => `/api/v1/accounts/${accountId.value}/inboxes/${inboxId.value}`
);

const createInbox = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;
  creating.value = true;
  try {
    const channel = await store.dispatch('inboxes/createChannel', {
      name: state.inboxName.trim(),
      channel: {
        type: 'whatsapp',
        phone_number: state.phoneNumber,
        provider: 'uazapi',
        provider_config: { instance_name: state.inboxName.trim() },
      },
    });
    inboxId.value = channel.id;
    step.value = 'qr';
    await requestQr();
  } catch (error) {
    useAlert(error?.message || t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE'));
  } finally {
    creating.value = false;
  }
};

const requestQr = async () => {
  connecting.value = true;
  try {
    const { data } = await axios.post(`${baseUrl.value}/uazapi_setup`);
    qrcode.value = data.qrcode || '';
    connState.value = data.status || 'connecting';
    startPolling();
  } catch (error) {
    useAlert(
      error?.response?.data?.error || 'Falha ao gerar o QR. Confira a configuração do servidor UAZAPI (ENV).'
    );
  } finally {
    connecting.value = false;
  }
};

const startPolling = () => {
  stopPolling();
  pollTimer = setInterval(async () => {
    try {
      const { data } = await axios.get(`${baseUrl.value}/uazapi_status`);
      connState.value = data.status;
      if (data.qrcode) qrcode.value = data.qrcode;
      if (data.connected) {
        stopPolling();
        finish();
      }
    } catch (error) {
      // segue tentando; erro transitório de rede não deve parar o polling
    }
  }, 3000);
};

const stopPolling = () => {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
};

const finish = () => {
  step.value = 'connected';
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: inboxId.value },
  });
};

onBeforeUnmount(stopPolling);
</script>

<template>
  <!-- Servidor UAZAPI não configurado no ambiente: infra é do administrador da plataforma -->
  <div
    v-if="!uazapiConfigured"
    class="flex flex-col gap-2 p-4 rounded-xl border border-n-amber-6 bg-n-amber-2"
  >
    <p class="text-sm font-medium text-n-slate-12 m-0">
      Servidor UAZAPI ainda não configurado
    </p>
    <p class="text-sm text-n-slate-11 m-0">
      O servidor e o token de administrador da UAZAPI são definidos uma vez no ambiente
      da plataforma (variáveis <b>UAZAPI_URL</b> e <b>UAZAPI_ADMIN_TOKEN</b>). Peça ao
      administrador para configurá-las — depois disso é só informar nome e número aqui.
    </p>
  </div>

  <!-- Passo 1: nome + número (servidor/token vêm do ENV) -->
  <form
    v-else-if="step === 'form'"
    class="flex flex-col gap-4"
    @submit.prevent="createInbox"
  >
    <p class="text-sm text-n-slate-11 m-0">
      Conecte um número de WhatsApp pela UAZAPI. Informe o <b>nome</b> e o <b>número</b> —
      o QR aparece no próximo passo e a conexão é automática.
    </p>

    <label :class="{ error: v$.inboxName.$error }">
      Nome da caixa
      <input
        v-model="state.inboxName"
        type="text"
        placeholder="Ex.: WhatsApp Atendimento"
        @blur="v$.inboxName.$touch"
      />
    </label>

    <label :class="{ error: v$.phoneNumber.$error }">
      Número (com DDI/DDD)
      <input
        v-model="state.phoneNumber"
        type="text"
        placeholder="+5511999999999"
        @blur="v$.phoneNumber.$touch"
      />
    </label>

    <div>
      <NextButton
        type="submit"
        :is-loading="creating"
        :label="creating ? 'Criando…' : 'Criar e gerar QR'"
      />
    </div>
  </form>

  <!-- Passo 2: QR code -->
  <div v-else-if="step === 'qr'" class="flex flex-col items-center gap-4 py-4">
    <h3 class="text-lg font-medium text-n-slate-12 m-0">Escaneie o QR no WhatsApp</h3>
    <p class="text-sm text-n-slate-11 text-center max-w-md m-0">
      No celular: <b>WhatsApp → Aparelhos conectados → Conectar aparelho</b> e aponte
      para o código. A tela avança sozinha quando conectar.
    </p>

    <div
      class="w-64 h-64 flex items-center justify-center border border-n-weak rounded-xl bg-white p-3"
    >
      <img v-if="qrcode" :src="qrcode" alt="QR Code UAZAPI" class="w-full h-full object-contain" />
      <span v-else class="text-sm text-n-slate-10">
        {{ connecting ? 'Gerando QR…' : 'Aguardando QR…' }}
      </span>
    </div>

    <div class="flex items-center gap-2 text-sm text-n-slate-11">
      <span class="w-2 h-2 rounded-full bg-amber-400 animate-pulse" />
      Status: {{ connState || 'connecting' }}
    </div>

    <NextButton variant="ghost" label="Gerar novo QR" @click="requestQr" />
  </div>

  <!-- Passo 3: conectado -->
  <div v-else class="flex flex-col items-center gap-3 py-8">
    <span class="w-3 h-3 rounded-full bg-green-500" />
    <p class="text-n-slate-12 font-medium m-0">Conectado! Redirecionando…</p>
  </div>
</template>
