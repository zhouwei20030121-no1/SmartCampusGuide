import { createRouter, createWebHistory } from 'vue-router'
import MainLayout from '@/layouts/MainLayout.vue'

const routes = [
  {
    path: '/',
    component: MainLayout,
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/content_sys/Dashboard.vue'),
        meta: { title: '数据大屏' },
      },
      {
        path: 'users',
        name: 'UserList',
        component: () => import('@/views/user_sys/UserList.vue'),
        meta: { title: '用户管理' },
      },
      {
        path: 'spots',
        name: 'SpotManage',
        component: () => import('@/views/content_sys/SpotManage.vue'),
        meta: { title: '景点管理' },
      },
      {
        path: 'tts-config',
        name: 'TTSConfig',
        component: () => import('@/views/ai_config/TTSConfig.vue'),
        meta: { title: 'TTS 配置' },
      },
      {
        path: 'corpus',
        name: 'CorpusManage',
        component: () => import('@/views/ai_config/CorpusManage.vue'),
        meta: { title: '语料库管理' },
      },
      {
        path: 'comments',
        name: 'CommentReview',
        component: () => import('@/views/interactive_sys/CommentReview.vue'),
        meta: { title: '评论审核' },
      },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
