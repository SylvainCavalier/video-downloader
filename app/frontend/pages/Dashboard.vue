<template>
  <div class="min-h-screen bg-gray-50">
    <NavBar />

    <div class="max-w-5xl mx-auto px-4 py-8">
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-8">
        <h1 class="text-2xl font-bold text-gray-900 mb-1">New download</h1>
        <p class="text-sm text-gray-500 mb-6">Paste a YouTube URL and pick your options.</p>

        <form @submit.prevent="submit" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">YouTube URL</label>
            <input
              v-model="form.url"
              type="url"
              required
              placeholder="https://www.youtube.com/watch?v=..."
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
            />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Format</label>
              <select v-model="form.format" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <option value="mp4">Video (MP4)</option>
                <option value="mp3">Audio (MP3)</option>
              </select>
            </div>

            <div v-if="form.format === 'mp4'">
              <label class="block text-sm font-medium text-gray-700 mb-1">Quality</label>
              <select v-model="form.quality" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <option value="original">Original (up to 1080p)</option>
                <option value="720p">Reduced (720p)</option>
              </select>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Storage</label>
              <select v-model="form.storage" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <option value="local">Local download</option>
                <option value="cloud">OVH Cloud</option>
              </select>
            </div>
          </div>

          <div v-if="form.storage === 'cloud'">
            <label class="block text-sm font-medium text-gray-700 mb-1">Folder (optional)</label>
            <select v-model="form.folder_id" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
              <option :value="null">— No folder —</option>
              <option v-for="f in folders" :key="f.id" :value="f.id">{{ f.name }}</option>
            </select>
          </div>

          <div v-if="submitError" class="bg-red-50 border border-red-200 text-red-700 px-3 py-2 rounded-lg text-sm">
            {{ submitError }}
          </div>

          <button
            type="submit"
            :disabled="submitting"
            class="bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-medium px-5 py-2 rounded-lg"
          >
            {{ submitting ? 'Queueing…' : 'Start download' }}
          </button>
        </form>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-bold text-gray-900">History</h2>
          <span v-if="hasActive" class="text-sm text-blue-600 animate-pulse">Polling…</span>
        </div>

        <div v-if="loading && !downloads.length" class="text-gray-500 text-sm">Loading…</div>
        <div v-else-if="!downloads.length" class="text-gray-500 text-sm">No downloads yet.</div>

        <ul class="divide-y divide-gray-100">
          <li v-for="d in downloads" :key="d.id" class="py-3 flex items-center gap-4">
            <div class="flex-1 min-w-0">
              <div class="font-medium text-gray-900 truncate">
                {{ d.title || d.url }}
              </div>
              <div class="text-xs text-gray-500 flex gap-3 mt-1">
                <span>{{ d.format.toUpperCase() }}<span v-if="d.quality"> · {{ d.quality }}</span></span>
                <span>{{ d.storage === 'cloud' ? 'OVH Cloud' : 'Local' }}</span>
                <span v-if="d.file_size">{{ formatSize(d.file_size) }}</span>
              </div>
            </div>

            <span :class="statusClass(d.status)" class="text-xs font-semibold px-2 py-1 rounded">
              {{ d.status }}
            </span>

            <a
              v-if="d.status === 'completed' && d.file_url"
              :href="d.file_url"
              class="text-blue-600 hover:text-blue-800 text-sm font-medium"
            >Download</a>

            <button
              @click="remove(d.id)"
              class="text-gray-400 hover:text-red-600 text-sm"
              title="Delete"
            >✕</button>
          </li>
        </ul>
      </div>

      <div v-if="downloads.find((d) => d.status === 'failed' && d.error_message)" class="mt-4 text-xs text-gray-500">
        Tip: hover over failed items to see the error message.
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import NavBar from '../components/NavBar.vue'
import api from '../plugins/axios'
import { useDownloads } from '../composables/useDownloads'

const { downloads, loading, hasActive, fetchAll, createDownload, destroyDownload } = useDownloads()

const folders = ref([])
const submitting = ref(false)
const submitError = ref(null)

const form = ref({
  url: '',
  format: 'mp4',
  quality: 'original',
  storage: 'local',
  folder_id: null
})

onMounted(async () => {
  await fetchAll()
  try {
    const res = await api.get('/folders')
    folders.value = res.data
  } catch (_) {}
})

async function submit() {
  submitting.value = true
  submitError.value = null
  try {
    const payload = {
      url: form.value.url,
      format: form.value.format,
      storage: form.value.storage
    }
    if (form.value.format === 'mp4') payload.quality = form.value.quality
    if (form.value.storage === 'cloud' && form.value.folder_id) payload.folder_id = form.value.folder_id

    await createDownload(payload)
    form.value.url = ''
  } catch (e) {
    const errors = e.response?.data?.errors
    submitError.value = errors ? errors.join(', ') : (e.response?.data?.error || e.message)
  } finally {
    submitting.value = false
  }
}

async function remove(id) {
  if (!confirm('Delete this download?')) return
  await destroyDownload(id)
}

function statusClass(status) {
  return {
    pending: 'bg-gray-100 text-gray-700',
    processing: 'bg-blue-100 text-blue-700',
    completed: 'bg-green-100 text-green-700',
    failed: 'bg-red-100 text-red-700'
  }[status] || 'bg-gray-100 text-gray-700'
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}
</script>
