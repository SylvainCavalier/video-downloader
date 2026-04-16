<template>
  <nav class="bg-white border-b border-gray-200 shadow-sm">
    <div class="max-w-5xl mx-auto px-4 py-3 flex items-center justify-between">
      <div class="flex items-center gap-8">
        <span class="text-lg font-bold text-gray-900">Video Downloader</span>
        <div class="flex gap-4">
          <router-link
            to="/"
            class="text-sm font-medium text-gray-600 hover:text-blue-600"
            active-class="text-blue-600"
          >Downloads</router-link>
          <router-link
            to="/folders"
            class="text-sm font-medium text-gray-600 hover:text-blue-600"
            active-class="text-blue-600"
          >Folders</router-link>
        </div>
      </div>
      <div class="flex items-center gap-3 text-sm">
        <span v-if="email" class="text-gray-600">{{ email }}</span>
        <a
          href="/users/sign_out"
          data-method="delete"
          @click.prevent="signOut"
          class="text-gray-500 hover:text-red-600"
        >Sign out</a>
      </div>
    </div>
  </nav>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api, { railsClient } from '../plugins/axios'

const email = ref(null)

onMounted(async () => {
  try {
    const res = await api.get('/me')
    email.value = res.data.email
  } catch (_) {
    // interceptor redirects to sign_in on 401
  }
})

async function signOut() {
  try {
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    await railsClient.delete('/users/sign_out', { headers: { 'X-CSRF-Token': token } })
  } catch (_) {}
  window.location.href = '/users/sign_in'
}
</script>
