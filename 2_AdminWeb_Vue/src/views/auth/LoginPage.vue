<template>
  <div class="login-container">
    <img class="global-bg" src="/images/bg.jpg" alt="background" />
    <div class="bg-mask"></div>

    <div class="login-box">
      <div class="login-header">
        <div class="logo-circle">西大</div>
        <h2 class="sys-title">SWU Guide</h2>
        <p class="sys-subtitle">AI沉浸式智慧校园导览 · 管理后台</p>
      </div>

      <div class="input-group">
        <input
          type="text"
          class="glass-input"
          placeholder="管理员账号"
          v-model="form.username"
          @keyup.enter="handleLogin"
        />
      </div>
      <div class="input-group">
        <input
          type="password"
          class="glass-input"
          placeholder="管理密码"
          v-model="form.password"
          @keyup.enter="handleLogin"
        />
      </div>

      <button class="login-btn" @click="handleLogin">登 录</button>
      <p class="login-hint">输入任意账号即可体验</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()

const form = reactive({
  username: '',
  password: '',
})

const handleLogin = () => {
  if (!form.username) {
    alert('请输入管理员账号')
    return
  }
  localStorage.setItem('token', 'demo-token')
  router.replace('/dashboard')
}
</script>

<style scoped>
.login-container {
  position: relative;
  width: 100vw;
  height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
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

.login-box {
  width: 400px;
  padding: 50px 40px;
  background: rgba(255, 255, 255, 0.45);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid rgba(255, 255, 255, 0.65);
  border-radius: 24px;
  box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.08);
  text-align: center;
}

.login-header {
  margin-bottom: 40px;
}

.logo-circle {
  width: 60px;
  height: 60px;
  background: #1A5276;
  color: #fff;
  font-size: 18px;
  font-weight: bold;
  line-height: 60px;
  border-radius: 50%;
  margin: 0 auto 15px;
}

.sys-title {
  font-size: 26px;
  font-weight: 800;
  color: #1A5276;
  margin: 0 0 6px;
  letter-spacing: 2px;
}

.sys-subtitle {
  font-size: 14px;
  color: #64748b;
  margin: 0;
}

.input-group {
  margin-bottom: 18px;
}

.glass-input {
  width: 100%;
  box-sizing: border-box;
  padding: 14px 18px;
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.7);
  background: rgba(255, 255, 255, 0.4);
  font-size: 15px;
  color: #1e293b;
  outline: none;
  transition: all 0.3s;
}

.glass-input::placeholder {
  color: #94a3b8;
}

.glass-input:focus {
  background: rgba(255, 255, 255, 0.7);
  border-color: #1A5276;
  box-shadow: 0 0 0 3px rgba(26, 82, 118, 0.1);
}

.login-btn {
  width: 100%;
  padding: 14px;
  border-radius: 12px;
  font-size: 17px;
  font-weight: bold;
  background: #1A5276;
  color: white;
  border: none;
  cursor: pointer;
  transition: all 0.3s;
  margin-top: 8px;
}

.login-btn:hover {
  background: #144266;
  transform: translateY(-1px);
  box-shadow: 0 4px 16px rgba(26, 82, 118, 0.3);
}

.login-hint {
  margin: 16px 0 0;
  font-size: 12px;
  color: #94a3b8;
}
</style>
