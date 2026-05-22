<template>
  <div class="page-container">
    <el-card>
      <template #header>
        <span>讲解内容编辑</span>
      </template>
      <el-form :model="form" label-width="100px">
        <el-form-item label="选择景点">
          <el-select v-model="form.spotId" placeholder="请选择景点" style="width: 300px">
            <el-option v-for="s in spots" :key="s.id" :label="s.name" :value="s.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="语言">
          <el-radio-group v-model="form.language">
            <el-radio value="zh">中文</el-radio>
            <el-radio value="en">English</el-radio>
            <el-radio value="ja">日本語</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="讲解标题">
          <el-input v-model="form.title" placeholder="请输入讲解标题" />
        </el-form-item>
        <el-form-item label="讲解文案">
          <el-input
            v-model="form.scriptContent"
            type="textarea"
            :rows="8"
            placeholder="请输入讲解文案内容..."
          />
        </el-form-item>
        <el-form-item label="触发半径">
          <el-input-number v-model="form.triggerRadius" :min="10" :max="500" />
          <span style="margin-left: 8px; color: #999">米</span>
        </el-form-item>
        <el-form-item label="音频文件">
          <el-upload action="#" :auto-upload="false">
            <el-button type="primary">上传音频</el-button>
            <template #tip>
              <div class="el-upload__tip">支持 MP3 / WAV 格式</div>
            </template>
          </el-upload>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSave">保存</el-button>
          <el-button @click="handleGenerate" type="success" :loading="genLoading">
            AI 自动生成文案
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { ElMessage } from 'element-plus'
import request from '@/api/request'

const spots = ref<any[]>([])
const genLoading = ref(false)

const form = reactive({
  spotId: '',
  language: 'zh',
  title: '',
  scriptContent: '',
  triggerRadius: 50,
})

const handleSave = async () => {
  try {
    await request.post('/guide/content', form)
    ElMessage.success('保存成功')
  } catch {
    ElMessage.error('保存失败')
  }
}

const handleGenerate = async () => {
  if (!form.spotId) {
    ElMessage.warning('请先选择景点')
    return
  }
  genLoading.value = true
  try {
    const res = await request.post('/guide/content/generate', { spotId: form.spotId, language: form.language })
    form.scriptContent = (res as any).script || ''
    ElMessage.success('AI 文案生成成功')
  } catch {
    ElMessage.error('生成失败，请检查 AI 服务')
  } finally {
    genLoading.value = false
  }
}
</script>

<style scoped>
.page-container { padding: 0; }
</style>
