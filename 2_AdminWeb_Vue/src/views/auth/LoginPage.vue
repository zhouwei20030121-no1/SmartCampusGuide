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

      <template v-if="isRegister">
        <div class="input-group">
          <input type="text" class="glass-input" placeholder="设置管理员账号 (必填)" v-model="form.username" />
        </div>
        <div class="input-group">
          <input type="password" class="glass-input" placeholder="设置密码 (必填)" v-model="form.password" />
        </div>
        <div class="input-group">
          <input type="password" class="glass-input" placeholder="确认密码 (必填)" v-model="form.confirmPassword" />
        </div>
        <div class="input-group">
          <input type="text" class="glass-input" placeholder="工号/学号 (选填)" v-model="form.campusId" />
        </div>
        <div class="input-group">
          <input type="text" class="glass-input" placeholder="手机号码 (选填)" v-model="form.phone" />
        </div>
      </template>

      <template v-else>
        <div class="input-group">
          <input type="text" class="glass-input" placeholder="管理员账号" v-model="form.username" @keyup.enter="handleSubmit" />
        </div>
        <div class="input-group">
          <input type="password" class="glass-input" placeholder="管理密码" v-model="form.password" @keyup.enter="handleSubmit" />
        </div>
      </template>

      <button class="login-btn" @click="handleSubmit" :disabled="loading">
        {{ loading ? '处理中...' : (isRegister ? '注册管理员并返回' : '登 录') }}
      </button>

      <p class="toggle-hint" @click="toggleMode">
        {{ isRegister ? '已有账号？点击此处直接登录' : '没有账号？点击注册管理员账号' }}
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import request from '@/api/request'

const router = useRouter()
const loading = ref(false)
const isRegister = ref(false) // 默认为登录模式

const form = reactive({
  username: '',
  password: '',
  confirmPassword: '',
  campusId: '',
  phone: ''
})

const toggleMode = () => {
  isRegister.value = !isRegister.value
  // 切换模式时清空表单
  form.username = ''
  form.password = ''
  form.confirmPassword = ''
  form.campusId = ''
  form.phone = ''
}

const handleSubmit = async () => {
  // === 注册逻辑 ===
  if (isRegister.value) {
    if (!form.username || !form.password) {
      ElMessage.warning('请填写必填项（账号和密码）')
      return
    }
    if (form.password !== form.confirmPassword) {
      ElMessage.warning('两次输入的密码不一致')
      return
    }

    loading.value = true
    try {
      await request.post('/user/register', {
        username: form.username,
        password: form.password,
        campusId: form.campusId,
        phone: form.phone
      })
      ElMessage.success('管理员注册成功，请登录！')
      toggleMode() // 注册成功后自动切回登录页面
    } catch (error) {
      console.error('注册异常', error)
    } finally {
      loading.value = false
    }
  } 
  // === 登录逻辑 ===
  else {
    if (!form.username || !form.password) {
      ElMessage.warning('请输入完整的账号和密码')
      return
    }

    loading.value = true
    try {
      const token = await request.post('/user/login', {
        account: form.username,
        password: form.password
      })
      localStorage.setItem('token', token as any)
      ElMessage.success('登录成功')
      router.replace('/dashboard')
    } catch (error) {
      console.error('登录异常', error)
    } finally {
      loading.value = false
    }
  }
}
</script>

<style scoped>
.login-container { position: relative; width: 100vw; height: 100vh; display: flex; justify-content: center; align-items: center; overflow: hidden; font-family: 'PingFang SC', 'Microsoft YaHei', sans-serif; }
.global-bg { position: fixed; top: 0; left: 0; width: 100%; height: 100%; object-fit: cover; z-index: -2; }
.bg-mask { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: linear-gradient(135deg, rgba(224, 242, 254, 0.5), rgba(186, 230, 253, 0.35)); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); z-index: -1; }
.login-box { width: 400px; padding: 50px 40px; background: rgba(255, 255, 255, 0.45); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); border: 1px solid rgba(255, 255, 255, 0.65); border-radius: 24px; box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.08); text-align: center; transition: all 0.3s; }
.login-header { margin-bottom: 30px; }
.logo-circle { width: 60px; height: 60px; background: #1A5276; color: #fff; font-size: 18px; font-weight: bold; line-height: 60px; border-radius: 50%; margin: 0 auto 15px; }
.sys-title { font-size: 26px; font-weight: 800; color: #1A5276; margin: 0 0 6px; letter-spacing: 2px; }
.sys-subtitle { font-size: 14px; color: #64748b; margin: 0; }
.input-group { margin-bottom: 16px; }
.glass-input { width: 100%; box-sizing: border-box; padding: 14px 18px; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.7); background: rgba(255, 255, 255, 0.4); font-size: 15px; color: #1e293b; outline: none; transition: all 0.3s; }
.glass-input::placeholder { color: #94a3b8; }
.glass-input:focus { background: rgba(255, 255, 255, 0.7); border-color: #1A5276; box-shadow: 0 0 0 3px rgba(26, 82, 118, 0.1); }
.login-btn { width: 100%; padding: 14px; border-radius: 12px; font-size: 17px; font-weight: bold; background: #1A5276; color: white; border: none; cursor: pointer; transition: all 0.3s; margin-top: 8px; }
.login-btn:hover:not(:disabled) { background: #144266; transform: translateY(-1px); box-shadow: 0 4px 16px rgba(26, 82, 118, 0.3); }
.login-btn:disabled { background: #94a3b8; cursor: not-allowed; }
.toggle-hint { margin: 20px 0 0; font-size: 13px; color: #1A5276; font-weight: bold; cursor: pointer; text-decoration: underline; transition: opacity 0.3s; }
.toggle-hint:hover { opacity: 0.7; }
</style>