<template>
  <div class="min-h-screen bg-gray-50">
    <NavBar />

    <div class="max-w-3xl mx-auto px-4 py-8">
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
        <h1 class="text-2xl font-bold text-gray-900 mb-1">Folders</h1>
        <p class="text-sm text-gray-500 mb-6">Organize your cloud downloads.</p>

        <form @submit.prevent="createFolder" class="flex gap-2">
          <input
            v-model="newName"
            type="text"
            required
            placeholder="New folder name"
            class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          />
          <button
            type="submit"
            :disabled="creating"
            class="bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-medium px-4 py-2 rounded-lg"
          >Add</button>
        </form>

        <p v-if="error" class="mt-2 text-sm text-red-600">{{ error }}</p>
      </div>

      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div v-if="!folders.length" class="text-gray-500 text-sm">No folders yet.</div>
        <ul class="divide-y divide-gray-100">
          <li v-for="f in folders" :key="f.id" class="py-3 flex items-center gap-3">
            <input
              v-if="editing === f.id"
              v-model="editName"
              @keyup.enter="save(f)"
              @keyup.esc="editing = null"
              class="flex-1 px-2 py-1 border border-gray-300 rounded"
              autofocus
            />
            <span v-else class="flex-1 font-medium text-gray-900">{{ f.name }}</span>
            <span class="text-xs text-gray-500">{{ f.downloads_count }} download{{ f.downloads_count === 1 ? '' : 's' }}</span>
            <button v-if="editing !== f.id" @click="startEdit(f)" class="text-sm text-gray-500 hover:text-blue-600">Rename</button>
            <button v-else @click="save(f)" class="text-sm text-blue-600 font-medium">Save</button>
            <button @click="remove(f)" class="text-sm text-gray-400 hover:text-red-600">Delete</button>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import NavBar from '../components/NavBar.vue'
import api from '../plugins/axios'

const folders = ref([])
const newName = ref('')
const creating = ref(false)
const error = ref(null)
const editing = ref(null)
const editName = ref('')

onMounted(fetchFolders)

async function fetchFolders() {
  const res = await api.get('/folders')
  folders.value = res.data
}

async function createFolder() {
  creating.value = true
  error.value = null
  try {
    const res = await api.post('/folders', { folder: { name: newName.value } })
    folders.value.push(res.data)
    folders.value.sort((a, b) => a.name.localeCompare(b.name))
    newName.value = ''
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || e.message
  } finally {
    creating.value = false
  }
}

function startEdit(folder) {
  editing.value = folder.id
  editName.value = folder.name
}

async function save(folder) {
  try {
    const res = await api.patch(`/folders/${folder.id}`, { folder: { name: editName.value } })
    const idx = folders.value.findIndex((f) => f.id === folder.id)
    folders.value[idx] = res.data
    editing.value = null
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || e.message
  }
}

async function remove(folder) {
  if (!confirm(`Delete folder "${folder.name}"? Downloads inside will be unlinked.`)) return
  await api.delete(`/folders/${folder.id}`)
  folders.value = folders.value.filter((f) => f.id !== folder.id)
}
</script>
