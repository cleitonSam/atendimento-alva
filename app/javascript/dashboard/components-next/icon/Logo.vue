<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    :src="globalConfig.logoThumbnail"
  />
  <svg
    v-else
    v-once
    v-bind="attrs"
    width="16"
    height="16"
    viewBox="0 0 512 512"
    fill="none"
    role="img"
    aria-label="ALVA IA TECH"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      fill="currentColor"
      fill-rule="evenodd"
      d="M120 430 L256 168 L392 430 Z M256 232 L298 322 L214 322 Z M256 362 L316 430 L196 430 Z"
    />
    <circle cx="256" cy="112" r="46" fill="currentColor" />
  </svg>
</template>
