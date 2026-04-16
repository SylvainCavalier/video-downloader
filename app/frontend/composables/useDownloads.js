import { ref, computed, onUnmounted } from 'vue'
import api from '../plugins/axios'

const POLL_INTERVAL = 2000

export function useDownloads() {
  const downloads = ref([])
  const loading = ref(false)
  const error = ref(null)
  let pollTimer = null

  const hasActive = computed(() =>
    downloads.value.some((d) => d.status === 'pending' || d.status === 'processing')
  )

  async function fetchAll() {
    loading.value = true
    try {
      const res = await api.get('/downloads')
      downloads.value = res.data
      error.value = null
      schedulePoll()
    } catch (e) {
      error.value = e.response?.data?.error || e.message
    } finally {
      loading.value = false
    }
  }

  async function createDownload(payload) {
    const res = await api.post('/downloads', { download: payload })
    downloads.value.unshift(res.data)
    schedulePoll()
    return res.data
  }

  async function destroyDownload(id) {
    await api.delete(`/downloads/${id}`)
    downloads.value = downloads.value.filter((d) => d.id !== id)
  }

  function schedulePoll() {
    clearTimeout(pollTimer)
    if (!hasActive.value) return
    pollTimer = setTimeout(async () => {
      try {
        const res = await api.get('/downloads')
        downloads.value = res.data
      } catch (e) {
        // swallow polling errors
      }
      schedulePoll()
    }, POLL_INTERVAL)
  }

  onUnmounted(() => clearTimeout(pollTimer))

  return { downloads, loading, error, hasActive, fetchAll, createDownload, destroyDownload }
}
