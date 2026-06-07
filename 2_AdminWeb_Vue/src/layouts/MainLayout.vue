<template>
  <div class="layout">
    <!-- 背景 -->
    <img class="global-bg" src="/images/bg.jpg" alt="bg" />
    <div class="bg-mask"></div>

    <!-- 顶部导航栏 -->
    <header class="topbar">
      <div class="topbar-left">
        <div class="logo-circle">西大</div>
        <span class="topbar-title">SWU Guide 管理后台</span>
      </div>
      <nav class="topbar-nav">
        <router-link
          v-for="item in navItems"
          :key="item.path"
          :to="item.path"
          class="nav-item"
          active-class="nav-active"
        >
          {{ item.label }}
        </router-link>
      </nav>
      <div class="topbar-right">
        <span class="admin-name">{{ username }}</span>
        <button class="logout-btn" @click="handleLogout">退出</button>
      </div>
    </header>

    <!-- 内容区 -->
    <main class="main-content">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import request from '@/api/request'

const router = useRouter()
const username = ref('管理员')

const navItems = [
  { label: '数据大屏', path: '/dashboard' },
  { label: '景点管理', path: '/spots' },
  { label: '用户管理', path: '/users' },
  { label: '内容编辑', path: '/content' },
  { label: '路线管理', path: '/routes' },
  { label: '校车管理', path: '/bus' },
  { label: 'AI工作台', path: '/ai-workbench' },
  { label: '校园故事', path: '/stories' },
  { label: '评论审核', path: '/comments' },
  { label: '语料库', path: '/corpus' },
  { label: '校园公告', path: '/announcement-manage' }, // 🌟 新增
]

const getUsername = () => {
  const name = localStorage.getItem('username') 
    || localStorage.getItem('realName') 
    || localStorage.getItem('real_name')
  if (name) {
    username.value = name
  }
}

const handleLogout = () => {
  localStorage.removeItem('token')
  localStorage.removeItem('username')
  localStorage.removeItem('realName')
  router.replace('/login')
}

onMounted(async () => {
  getUsername()
  if (username.value === '管理员') {
    try {
      const token = localStorage.getItem('token')
      if (token) {
        const payload = token.split('.')[1]
        const decoded = JSON.parse(atob(payload))
        const userId = decoded.userId || decoded.id || decoded.sub
        if (userId) {
          const res = await request.get(`/user/info/${userId}`)
          const user = (res as any).data || res
          if (user && user.realName) {
            localStorage.setItem('realName', user.realName)
            username.value = user.realName
          }
        }
      }
    } catch (e) {
      console.log('获取用户信息失败')
    }
  }
})
</script>

<style scoped>
.layout {
  position: relative;
  width: 100vw;
  height: 100vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  font-family: 'PingFang SC', 'Microsoft YaHei', sans-serif;
}

.global-bg {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  z-index: -2;
}
.bg-mask {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, rgba(224, 242, 254, 0.5), rgba(186, 230, 253, 0.35));
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  z-index: -1;
}

.topbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 32px;
  height: 64px;
  background: rgba(255, 255, 255, 0.5);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.7);
  box-shadow: 0 2px 16px rgba(31, 38, 135, 0.06);
  flex-shrink: 0;
  z-index: 10;
}

.topbar-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.logo-circle {
  width: 36px;
  height: 36px;
  background: #1A5276;
  color: #fff;
  font-size: 13px;
  font-weight: bold;
  line-height: 36px;
  text-align: center;
  border-radius: 50%;
}

.topbar-title {
  font-size: 18px;
  font-weight: 700;
  color: #1A5276;
  letter-spacing: 1px;
}

.topbar-nav {
  display: flex;
  gap: 4px;
}

.nav-item {
  padding: 8px 18px;
  border-radius: 18px;
  font-size: 14px;
  font-weight: 500;
  color: #475569;
  text-decoration: none;
  transition: all 0.3s;
}

.nav-item:hover {
  background: rgba(26, 82, 118, 0.08);
  color: #1A5276;
}

.nav-active {
  background: #1A5276;
  color: #fff;
  box-shadow: 0 4px 12px rgba(26, 82, 118, 0.25);
}

.nav-active:hover {
  background: #144266;
  color: #fff;
}

.topbar-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.admin-name {
  font-size: 14px;
  font-weight: 600;
  color: #1e293b;
}

.logout-btn {
  padding: 6px 16px;
  border-radius: 14px;
  border: 1px solid rgba(26, 82, 118, 0.3);
  background: rgba(255, 255, 255, 0.6);
  color: #1A5276;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.3s;
}

.logout-btn:hover {
  background: #1A5276;
  color: #fff;
}

.main-content {
  flex: 1;
  overflow-y: auto;
  padding: 24px 32px;
}
</style>
