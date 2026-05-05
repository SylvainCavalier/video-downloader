<template>
  <div class="min-h-screen bg-gray-50">
    <NavBar />

    <div class="max-w-6xl mx-auto px-4 py-8">
      <div class="mb-6">
        <router-link to="/folders" class="text-sm text-gray-500 hover:text-blue-600">← Folders</router-link>
        <h1 class="text-2xl font-bold text-gray-900 mt-2">{{ folder?.name || '…' }}</h1>
        <p class="text-sm text-gray-500">{{ completed.length }} video{{ completed.length === 1 ? '' : 's' }}</p>
      </div>

      <div v-if="loading" class="text-gray-500 text-sm">Loading…</div>
      <div v-else-if="!completed.length" class="bg-white rounded-xl shadow-sm border border-gray-200 p-8 text-center text-gray-500 text-sm">
        No completed downloads in this folder yet.
      </div>

      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <button
          v-for="d in completed"
          :key="d.id"
          @click="open(d)"
          class="text-left bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-md hover:border-blue-400 transition"
        >
          <div class="aspect-video bg-gray-900 flex items-center justify-center overflow-hidden">
            <img
              v-if="d.thumbnail_url"
              :src="d.thumbnail_url"
              :alt="d.title"
              class="w-full h-full object-cover"
              loading="lazy"
            />
            <span v-else class="text-gray-500 text-xs">No preview</span>
          </div>
          <div class="p-4">
            <div class="font-semibold text-gray-900 line-clamp-2">{{ d.title || d.url }}</div>
            <div class="text-xs text-gray-500 mt-1 flex gap-2">
              <span>{{ d.format.toUpperCase() }}</span>
              <span v-if="d.duration">· {{ formatDuration(d.duration) }}</span>
              <span v-if="d.file_size">· {{ formatSize(d.file_size) }}</span>
            </div>
            <p v-if="d.description" class="text-xs text-gray-600 mt-2 line-clamp-3 whitespace-pre-line">
              {{ d.description }}
            </p>
          </div>
        </button>
      </div>
    </div>

    <div
      v-if="active"
      class="fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4"
      @click.self="close"
    >
      <div class="bg-gray-900 rounded-xl w-full max-w-4xl overflow-hidden shadow-2xl">
        <div class="flex items-center justify-between px-4 py-3 text-white">
          <div class="font-medium truncate pr-4">{{ active.title || active.url }}</div>
          <button @click="close" class="text-gray-300 hover:text-white text-xl leading-none">✕</button>
        </div>

        <video
          v-if="active.format === 'mp4'"
          :src="active.file_url"
          controls
          autoplay
          class="w-full bg-black aspect-video"
        />
        <div v-else class="p-6 flex flex-col items-center gap-4 bg-black">
          <img
            v-if="active.thumbnail_url"
            :src="active.thumbnail_url"
            class="max-h-60 rounded"
            :alt="active.title"
          />
          <audio :src="active.file_url" controls autoplay class="w-full" />
        </div>

        <div v-if="active.description" class="px-4 py-3 text-sm text-gray-300 max-h-40 overflow-y-auto whitespace-pre-line">
          {{ active.description }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import NavBar from '../components/NavBar.vue'
import api from '../plugins/axios'

const route = useRoute()
const folder = ref(null)
const downloads = ref([])
const loading = ref(true)
const active = ref(null)

const completed = computed(() => downloads.value.filter((d) => d.status === 'completed'))

onMounted(async () => {
  await Promise.all([fetchFolder(), fetchDownloads()])
  loading.value = false
  window.addEventListener('keydown', onKey)
})

onUnmounted(() => window.removeEventListener('keydown', onKey))

async function fetchFolder() {
  const res = await api.get(`/folders/${route.params.id}`)
  folder.value = res.data
}

async function fetchDownloads() {
  const res = await api.get('/downloads', { params: { folder_id: route.params.id } })
  downloads.value = res.data
}

function open(download) {
  active.value = download
}

function close() {
  active.value = null
}

function onKey(e) {
  if (e.key === 'Escape') close()
}

function formatDuration(seconds) {
  const s = Math.round(seconds)
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
  return `${m}:${String(sec).padStart(2, '0')}`
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}
</script>
