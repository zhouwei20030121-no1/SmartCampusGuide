import { createRouter, createWebHistory } from 'vue-router'
import MainLayout from '@/layouts/MainLayout.vue'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/auth/LoginPage.vue'),
    meta: { title: '登录 - SWU Guide Admin' },
  },
  {
    path: '/',
    component: MainLayout,
    redirect: '/dashboard',
    meta: { requiresAuth: true },
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
        path: 'ai-workbench',
        name: 'AiGuideWorkbench',
        component: () => import('@/views/ai/AiGuideWorkbench.vue'),
        meta: { title: 'AI动态讲解工作台' },
      },
      {
        path: 'stories',
        name: 'StoryManage',
        component: () => import('@/views/ai/StoryManage.vue'),
        meta: { title: '校园故事管理' },
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
      {
        path: 'knowledge-base',
        name: 'KnowledgeBaseManage',
        component: () => import('@/views/ai/KnowledgeBaseManage.vue'),
        meta: { title: '知识库管理' },
      },
      {
        path: 'announcement-manage',
        name: 'AnnouncementManage',
        component: () => import('@/views/announcement/AnnouncementManage.vue'),
        meta: { title: '校园公告管理' },
      },
      {
        path: '/bus',
        name: 'Bus',
        component: () => import('@/views/bus/BusManage.vue'),
      }

    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// 路由守卫：未登录跳转到登录页
router.beforeEach((to, _from) => {
  const token = localStorage.getItem('token')
  if (to.meta.requiresAuth && !token) {
    return '/login'
  }
  if (to.path === '/login' && token) {
    return '/dashboard'
  }
})

export default router
