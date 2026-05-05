// app/frontend/router/routes.js
export default [
  {
    path: '/',
    name: 'Downloads',
    component: () => import('../pages/Dashboard.vue'),
  },
  {
    path: '/folders',
    name: 'Folders',
    component: () => import('../pages/Folders.vue'),
  },
  {
    path: '/folders/:id',
    name: 'FolderShow',
    component: () => import('../pages/FolderShow.vue'),
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../pages/NotFound.vue'),
  },
]
