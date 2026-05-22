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
        component: () => import('@/views/dashboard/Dashboard.vue'),
        meta: { title: '数据大屏' },
      },
      {
        path: 'users',
        name: 'UserList',
        component: () => import('@/views/user/UserList.vue'),
        meta: { title: '用户管理' },
      },
      {
        path: 'spots',
        name: 'SpotManage',
        component: () => import('@/views/spot/SpotManage.vue'),
        meta: { title: '景点管理' },
      },
      {
        path: 'content',
        name: 'ContentEdit',
        component: () => import('@/views/content/ContentEdit.vue'),
        meta: { title: '内容编辑' },
      },
      {
        path: 'guide-config',
        name: 'GuideConfig',
        component: () => import('@/views/guide/GuideConfig.vue'),
        meta: { title: '讲解配置' },
      },
      {
        path: 'routes',
        name: 'RouteConfig',
        component: () => import('@/views/route/RouteConfig.vue'),
        meta: { title: '路线管理' },
      },
      {
        path: 'comments',
        name: 'CommentReview',
        component: () => import('@/views/comment/CommentReview.vue'),
        meta: { title: '评论审核' },
      },
      {
        path: 'corpus',
        name: 'CorpusManage',
        component: () => import('@/views/ai/CorpusManage.vue'),
        meta: { title: '语料库管理' },
      },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
