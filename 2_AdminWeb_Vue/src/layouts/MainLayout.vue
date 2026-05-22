<template>
  <el-container class="layout">
    <el-aside width="220px" class="sidebar">
      <div class="logo">
        <span>西大智能导览</span>
      </div>
      <el-menu
        :default-active="activeMenu"
        router
        background-color="#304156"
        text-color="#bfcbd9"
        active-text-color="#4A90E2"
      >
        <el-menu-item index="/dashboard">
          <el-icon><DataAnalysis /></el-icon>
          <span>数据大屏</span>
        </el-menu-item>
        <el-menu-item index="/users">
          <el-icon><User /></el-icon>
          <span>用户管理</span>
        </el-menu-item>
        <el-menu-item index="/spots">
          <el-icon><Location /></el-icon>
          <span>景点管理</span>
        </el-menu-item>
        <el-menu-item index="/content">
          <el-icon><EditPen /></el-icon>
          <span>内容编辑</span>
        </el-menu-item>
        <el-menu-item index="/guide-config">
          <el-icon><Microphone /></el-icon>
          <span>讲解配置</span>
        </el-menu-item>
        <el-menu-item index="/routes">
          <el-icon><MapLocation /></el-icon>
          <span>路线管理</span>
        </el-menu-item>
        <el-menu-item index="/comments">
          <el-icon><ChatLineSquare /></el-icon>
          <span>评论审核</span>
        </el-menu-item>
        <el-menu-item index="/corpus">
          <el-icon><Document /></el-icon>
          <span>语料库管理</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="header">
        <span class="page-title">{{ route.meta.title }}</span>
        <el-dropdown>
          <span class="user-info">
            <el-icon><UserFilled /></el-icon> 管理员
          </span>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item @click="handleLogout">退出登录</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </el-header>
      <el-main class="main-content">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const activeMenu = computed(() => route.path)

const handleLogout = () => {
  localStorage.removeItem('token')
  window.location.reload()
}
</script>

<style scoped>
.layout { height: 100vh; }
.sidebar { background-color: #304156; overflow: hidden; }
.logo {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 18px;
  font-weight: bold;
  letter-spacing: 2px;
  border-bottom: 1px solid rgba(255,255,255,.1);
}
.sidebar .el-menu { border-right: none; }
.header {
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: space-between;
  box-shadow: 0 1px 4px rgba(0,0,0,.08);
  padding: 0 20px;
}
.page-title { font-size: 16px; font-weight: 600; color: #2C3E50; }
.user-info { cursor: pointer; display: flex; align-items: center; gap: 4px; color: #666; }
.main-content { background: #f0f2f5; min-height: calc(100vh - 60px); }
</style>
