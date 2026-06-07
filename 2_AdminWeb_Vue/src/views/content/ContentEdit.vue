<template>
  <div class="page-container">
    <el-card class="main-card">
      <template #header>
        <div class="card-header">
          <span class="card-title">多媒体讲解内容编辑</span>
          <span class="card-desc">管理景点的音频、视频及讲解文案内容</span>
        </div>
      </template>

      <el-form :model="form" label-width="100px" class="content-form">
        
        <!-- 基本信息 -->
        <div class="section-title">基本信息</div>
        
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="选择景点" prop="spotId" :rules="[{ required: true, message: '请选择景点' }]">
              <el-select 
                v-model="form.spotId" 
                placeholder="请选择景点" 
                style="width: 100%"
                filterable
                @change="handleSpotChange"
              >
                <el-option 
                  v-for="s in spots" 
                  :key="s.id" 
                  :label="s.name" 
                  :value="s.id" 
                />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="语言" prop="language">
              <el-radio-group v-model="form.language" @change="handleLanguageChange">
                <el-radio-button value="zh">中文</el-radio-button>
                <el-radio-button value="en">English</el-radio-button>
                <el-radio-button value="ja">日本語</el-radio-button>
              </el-radio-group>
            </el-form-item>
          </el-col>
        </el-row>

        <el-form-item label="讲解标题" prop="title">
          <el-input 
            v-model="form.title" 
            placeholder="请输入讲解标题" 
            maxlength="100"
            show-word-limit
          />
        </el-form-item>

        <!-- 讲解文案 -->
        <div class="section-title">讲解文案</div>

        <el-form-item label="讲解文案" prop="scriptContent">
          <div class="editor-toolbar">
            <el-button-group size="small">
              <el-button @click="insertTag('<p>', '</p>')" title="段落">P</el-button>
              <el-button @click="insertTag('<br>', '')" title="换行">BR</el-button>
              <el-button @click="insertTag('<b>', '</b>')" title="加粗"><b>B</b></el-button>
              <el-button @click="insertTag('<i>', '</i>')" title="斜体"><i>I</i></el-button>
            </el-button-group>
            
            <el-button 
              type="success" 
              size="small" 
              @click="handleGenerate" 
              :disabled="!form.spotId"
              style="margin-left: 10px;"
            >
              <el-icon><MagicStick /></el-icon>
              AI 自动生成文案
            </el-button>
          </div>
          
          <el-input
            v-model="form.scriptContent"
            type="textarea"
            :rows="10"
            placeholder="请输入讲解文案内容，支持HTML标签格式化..."
            class="script-textarea"
          />
          
          <div class="word-count">
            字数统计：{{ form.scriptContent?.length || 0 }} 字
          </div>
        </el-form-item>

        <!-- 多媒体文件 -->
        <div class="section-title">多媒体文件</div>

        <!-- 音频上传 -->
        <el-form-item label="音频文件">
          <div class="media-upload-container">
            <div v-if="form.audioUrl" class="media-preview">
              <div class="media-icon">
                <el-icon :size="28" color="#1A5276"><Headset /></el-icon>
              </div>
              <div class="media-info">
                <span class="media-name">{{ form.audioName || '音频文件' }}</span>
                <audio :src="getFullMediaUrl(form.audioUrl)" controls class="audio-player">
                  您的浏览器不支持音频播放
                </audio>
              </div>
              <el-button 
                type="danger" 
                size="small" 
                @click="removeAudio"
                :icon="Delete"
                circle
              />
            </div>
            
            <el-upload
              class="media-uploader"
              :action="uploadAudioUrl"
              :show-file-list="false"
              :on-success="handleAudioUploadSuccess"
              :on-error="handleUploadError"
              :before-upload="beforeAudioUpload"
              accept="audio/mp3,audio/wav"
              :disabled="audioUploading"
            >
              <el-button 
                type="primary" 
                :loading="audioUploading"
                :icon="Upload"
              >
                {{ audioUploading ? '上传中...' : (form.audioUrl ? '更换音频' : '上传音频') }}
              </el-button>
              <template #tip>
                <div class="upload-tip">支持 MP3 / WAV 格式，大小不超过 20MB</div>
              </template>
            </el-upload>
          </div>
        </el-form-item>

        <!-- 视频上传 -->
        <el-form-item label="视频文件">
          <div class="media-upload-container">
            <div v-if="form.videoUrl" class="media-preview">
              <div class="media-icon">
                <el-icon :size="28" color="#1A5276"><VideoCamera /></el-icon>
              </div>
              <div class="media-info">
                <span class="media-name">{{ form.videoName || '视频文件' }}</span>
                <video 
                  :src="getFullMediaUrl(form.videoUrl)" 
                  controls 
                  class="video-player"
                >
                  您的浏览器不支持视频播放
                </video>
              </div>
              <el-button 
                type="danger" 
                size="small" 
                @click="removeVideo"
                :icon="Delete"
                circle
              />
            </div>
            
            <el-upload
              class="media-uploader"
              :action="uploadVideoUrl"
              :show-file-list="false"
              :on-success="handleVideoUploadSuccess"
              :on-error="handleUploadError"
              :before-upload="beforeVideoUpload"
              accept="video/mp4,video/webm"
              :disabled="videoUploading"
            >
              <el-button 
                type="primary" 
                :loading="videoUploading"
                :icon="VideoCamera"
              >
                {{ videoUploading ? '上传中...' : (form.videoUrl ? '更换视频' : '上传视频') }}
              </el-button>
              <template #tip>
                <div class="upload-tip">支持 MP4 / WebM 格式，大小不超过 100MB</div>
              </template>
            </el-upload>
          </div>
        </el-form-item>

        <!-- 内容预览 -->
        <div class="section-title">内容预览</div>

        <el-form-item>
          <el-button @click="showPreview = !showPreview">
            {{ showPreview ? '隐藏预览' : '显示预览' }}
          </el-button>
        </el-form-item>

        <div v-if="showPreview" class="content-preview">
          <div class="preview-card">
            <div class="preview-header">📱 预览效果</div>
            <div class="preview-body">
              <h3 class="preview-title">{{ form.title || '讲解标题' }}</h3>
              <div class="preview-text" v-html="form.scriptContent || '暂无文案内容'"></div>
              
              <div v-if="form.audioUrl" class="preview-media">
                <p>🎵 音频播放</p>
                <audio :src="getFullMediaUrl(form.audioUrl)" controls>
                  您的浏览器不支持音频播放
                </audio>
              </div>
              
              <div v-if="form.videoUrl" class="preview-media">
                <p>🎬 视频播放</p>
                <video 
                  :src="getFullMediaUrl(form.videoUrl)" 
                  controls 
                  class="preview-video"
                >
                  您的浏览器不支持视频播放
                </video>
              </div>
            </div>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="action-buttons">
          <el-button 
            type="primary" 
            @click="handleSave" 
            :loading="saveLoading"
            :icon="Check"
            size="large"
          >
            保存内容
          </el-button>
          <el-button 
            @click="handleReset" 
            :icon="RefreshLeft"
            size="large"
          >
            重置
          </el-button>
          <el-button 
            @click="() => handleLoadContent(true)" 
            :icon="Download"
            size="large"
            :disabled="!form.spotId"
            :loading="loadingContent"
          >
            加载已有内容
          </el-button>
        </div>

      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import type { UploadProps } from 'element-plus'
import {
  MagicStick,
  Headset,
  VideoCamera,
  Delete,
  Upload,
  Check,
  RefreshLeft,
  Download,
} from '@element-plus/icons-vue'
import request from '@/api/request'

const router = useRouter()

// 景点列表
const spots = ref<any[]>([])

// 加载状态
const saveLoading = ref(false)
const loadingContent = ref(false)
const audioUploading = ref(false)
const videoUploading = ref(false)

// 预览显示
const showPreview = ref(false)

// 上传地址
const uploadAudioUrl = ref('/api/upload/audio')
const uploadVideoUrl = ref('/api/upload/video')

// 表单数据
const form = reactive({
  id: null as number | null,
  spotId: '' as string | number,
  language: 'zh',
  title: '',
  scriptContent: '',
  audioUrl: '',
  audioName: '',
  videoUrl: '',
  videoName: '',
})

// 获取完整的多媒体URL
const getFullMediaUrl = (url: string) => {
  if (!url) return ''
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url
  }
  if (url.startsWith('/')) {
    return 'http://localhost:8080' + url
  }
  return url
}

// 获取景点列表
const fetchSpots = async () => {
  try {
    const response = await request.get('/spot/list', {
      params: { page: 1, size: 100 }
    })
    const data = response.data || response
    spots.value = data.records || []
  } catch (error) {
    console.error('获取景点列表失败:', error)
  }
}

// 景点选择改变 - 自动加载当前语言的内容
const handleSpotChange = (spotId: string) => {
  form.spotId = spotId
  handleLoadContent(false)
}

// 语言切换 - 自动加载新语言的内容
const handleLanguageChange = () => {
  if (form.spotId) {
    handleLoadContent(true)
  }
}

// 插入HTML标签
const insertTag = (openTag: string, closeTag: string) => {
  const textarea = document.querySelector('.script-textarea textarea') as HTMLTextAreaElement
  if (!textarea) return
  
  const start = textarea.selectionStart
  const end = textarea.selectionEnd
  const selectedText = form.scriptContent.substring(start, end)
  const newText = openTag + selectedText + closeTag
  
  form.scriptContent = form.scriptContent.substring(0, start) + newText + form.scriptContent.substring(end)
}

// AI生成文案 - 跳转到AI工作台
const handleGenerate = () => {
  if (!form.spotId) {
    ElMessage.warning('请先选择景点')
    return
  }

  // 获取当前选中的景点名称
  const spot = spots.value.find(s => s.id == form.spotId)
  const spotName = spot ? spot.name : ''

  // 保存当前表单状态，以便返回时恢复
  sessionStorage.setItem('contentEditState', JSON.stringify({
    id: form.id,
    spotId: form.spotId,
    language: form.language,
    title: form.title,
    scriptContent: form.scriptContent,
    audioUrl: form.audioUrl,
    audioName: form.audioName,
    videoUrl: form.videoUrl,
    videoName: form.videoName,
  }))

  // 跳转到AI工作台，并通过query传递景点名称
  router.push({
    path: '/ai-workbench',
    query: { spotName }
  })
}

// 加载已有内容
const handleLoadContent = async (showMessage = true) => {
  if (!form.spotId) {
    if (showMessage) ElMessage.warning('请先选择景点')
    return
  }
  
  loadingContent.value = true
  try {
    const response = await request.get(`/guide/content/${form.spotId}`, {
      params: { language: form.language }
    })
    const data = response || (response as any).data
    
    if (data && data.id) {
      form.id = data.id
      form.title = data.title || ''
      form.scriptContent = data.scriptContent || ''
      form.audioUrl = data.audioUrl || ''
      form.audioName = data.audioName || ''
      form.videoUrl = data.videoUrl || ''
      form.videoName = data.videoName || ''
      if (showMessage) ElMessage.success('内容加载成功')
    } else {
      form.id = null
      form.title = ''
      form.scriptContent = ''
      form.audioUrl = ''
      form.audioName = ''
      form.videoUrl = ''
      form.videoName = ''
      if (showMessage) ElMessage.info('该景点暂无此语言的讲解内容，请新建')
    }
  } catch (error) {
    console.error('加载内容失败:', error)
    form.id = null
    if (showMessage) ElMessage.info('该景点暂无讲解内容，请新建')
  } finally {
    loadingContent.value = false
  }
}

// 音频上传前验证
const beforeAudioUpload: UploadProps['beforeUpload'] = (file) => {
  const isValidType = file.type === 'audio/mpeg' || file.type === 'audio/wav' || 
    file.name.endsWith('.mp3') || file.name.endsWith('.wav')
  if (!isValidType) {
    ElMessage.error('只支持 MP3 和 WAV 格式的音频文件')
    return false
  }
  
  const isLt20M = file.size / 1024 / 1024 < 20
  if (!isLt20M) {
    ElMessage.error('音频文件大小不能超过 20MB')
    return false
  }
  
  audioUploading.value = true
  return true
}

// 音频上传成功
const handleAudioUploadSuccess: UploadProps['onSuccess'] = async (response: any) => {
  audioUploading.value = false
  
  let audioUrl = ''
  let audioName = ''
  
  if (typeof response === 'string') {
    audioUrl = response
  } else if (response.url) {
    audioUrl = response.url
  } else if (response.data && response.data.url) {
    audioUrl = response.data.url
    audioName = response.data.fileName || ''
  }
  
  if (audioUrl) {
    if (form.audioUrl) {
      try {
        await request.delete('/upload/media', {
          params: { url: form.audioUrl }
        })
      } catch (error) {
        console.error('删除旧音频失败:', error)
      }
    }
    
    form.audioUrl = audioUrl
    form.audioName = audioName
    ElMessage.success('音频上传成功')
  } else {
    ElMessage.error('音频上传失败')
  }
}

// 视频上传前验证
const beforeVideoUpload: UploadProps['beforeUpload'] = (file) => {
  const isValidType = file.type === 'video/mp4' || file.type === 'video/webm' ||
    file.name.endsWith('.mp4') || file.name.endsWith('.webm')
  if (!isValidType) {
    ElMessage.error('只支持 MP4 和 WebM 格式的视频文件')
    return false
  }
  
  const isLt100M = file.size / 1024 / 1024 < 100
  if (!isLt100M) {
    ElMessage.error('视频文件大小不能超过 100MB')
    return false
  }
  
  videoUploading.value = true
  return true
}

// 视频上传成功
const handleVideoUploadSuccess: UploadProps['onSuccess'] = async (response: any) => {
  videoUploading.value = false
  
  let videoUrl = ''
  let videoName = ''
  
  if (typeof response === 'string') {
    videoUrl = response
  } else if (response.url) {
    videoUrl = response.url
  } else if (response.data && response.data.url) {
    videoUrl = response.data.url
    videoName = response.data.fileName || ''
  }
  
  if (videoUrl) {
    if (form.videoUrl) {
      try {
        await request.delete('/upload/media', {
          params: { url: form.videoUrl }
        })
      } catch (error) {
        console.error('删除旧视频失败:', error)
      }
    }
    
    form.videoUrl = videoUrl
    form.videoName = videoName
    ElMessage.success('视频上传成功')
  } else {
    ElMessage.error('视频上传失败')
  }
}

// 上传失败处理
const handleUploadError: UploadProps['onError'] = () => {
  audioUploading.value = false
  videoUploading.value = false
  ElMessage.error('文件上传失败，请重试')
}

// 删除音频
const removeAudio = async () => {
  if (form.audioUrl) {
    try {
      await request.delete('/upload/media', {
        params: { url: form.audioUrl }
      })
    } catch (error) {
      console.error('删除音频文件失败:', error)
    }
  }
  
  form.audioUrl = ''
  form.audioName = ''
  ElMessage.success('音频已删除')
}

// 删除视频
const removeVideo = async () => {
  if (form.videoUrl) {
    try {
      await request.delete('/upload/media', {
        params: { url: form.videoUrl }
      })
    } catch (error) {
      console.error('删除视频文件失败:', error)
    }
  }
  
  form.videoUrl = ''
  form.videoName = ''
  ElMessage.success('视频已删除')
}

// 保存内容
const handleSave = async () => {
  if (!form.spotId) {
    ElMessage.warning('请先选择景点')
    return
  }
  
  saveLoading.value = true
  try {
    const submitData = {
      spotId: Number(form.spotId),
      language: form.language,
      title: form.title,
      scriptContent: form.scriptContent,
      audioUrl: form.audioUrl,
      audioName: form.audioName,
      videoUrl: form.videoUrl,
      videoName: form.videoName,
    }
    
    let response
    if (form.id) {
      response = await request.put(`/guide/content/${form.id}`, submitData)
    } else {
      response = await request.post('/guide/content', submitData)
    }
    
    if (response && response.id) {
      form.id = response.id
    }
    ElMessage.success('保存成功')
  } catch (error: any) {
    console.error('保存失败:', error)
  } finally {
    saveLoading.value = false
  }
}

// 重置表单
const handleReset = () => {
  form.id = null
  form.title = ''
  form.scriptContent = ''
  form.audioUrl = ''
  form.audioName = ''
  form.videoUrl = ''
  form.videoName = ''
  audioUploading.value = false
  videoUploading.value = false
}

onMounted(() => {
  fetchSpots()
  
  // 检查是否有保存的表单状态（从AI工作台返回）
  const savedState = sessionStorage.getItem('contentEditState')
  if (savedState) {
    try {
      const state = JSON.parse(savedState)
      form.id = state.id
      form.spotId = state.spotId
      form.language = state.language
      form.title = state.title
      form.scriptContent = state.scriptContent || ''
      form.audioUrl = state.audioUrl || ''
      form.audioName = state.audioName || ''
      form.videoUrl = state.videoUrl || ''
      form.videoName = state.videoName || ''
      sessionStorage.removeItem('contentEditState')
      
      // 检查是否有AI工作台生成的文案
      const aiContent = sessionStorage.getItem('aiGeneratedContent')
      if (aiContent) {
        form.scriptContent = aiContent
        sessionStorage.removeItem('aiGeneratedContent')
        ElMessage.success('已自动填入AI生成的讲解文案')
      }
    } catch (e) {
      console.error('恢复表单状态失败:', e)
    }
  }
})
</script>

<style scoped>
.page-container { padding: 20px; }
.main-card { border-radius: 20px; background: rgba(255,255,255,0.55); backdrop-filter: blur(14px); border: 1px solid rgba(255,255,255,0.45); }
.card-header { display: flex; flex-direction: column; gap: 4px; }
.card-title { font-size: 20px; font-weight: 600; color: #1A5276; }
.card-desc { font-size: 13px; color: #999; }
.content-form { max-width: 900px; }
.section-title { font-size: 16px; font-weight: 600; color: #1A5276; margin: 24px 0 16px 0; padding-bottom: 8px; border-bottom: 2px solid rgba(26,82,118,0.2); position: relative; }
.section-title::after { content: ''; position: absolute; bottom: -2px; left: 0; width: 60px; height: 2px; background: #1A5276; border-radius: 1px; }
.editor-toolbar { margin-bottom: 10px; display: flex; align-items: center; }
.script-textarea { font-family: 'Courier New', monospace; font-size: 14px; line-height: 1.6; }
.word-count { margin-top: 5px; font-size: 12px; color: #999; text-align: right; }
.media-upload-container { display: flex; flex-direction: column; gap: 10px; width: 100%; }
.media-preview { display: flex; align-items: flex-start; gap: 12px; padding: 12px 16px; border: 1px solid rgba(26,82,118,0.15); border-radius: 10px; background: rgba(255,255,255,0.5); }
.media-icon { width: 44px; height: 44px; border-radius: 10px; background: rgba(26,82,118,0.08); display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.media-info { flex: 1; display: flex; flex-direction: column; gap: 8px; min-width: 0; }
.media-name { font-size: 14px; color: #333; font-weight: 500; }
.audio-player { width: 100%; max-width: 400px; height: 40px; }
.video-player { width: 300px; height: 200px; border-radius: 8px; background: #000; object-fit: cover; }
.media-uploader { display: inline-block; }
.upload-tip { font-size: 12px; color: #999; margin-top: 5px; }
.content-preview { margin-bottom: 20px; }
.preview-card { border: 1px solid rgba(26,82,118,0.15); border-radius: 12px; overflow: hidden; background: rgba(255,255,255,0.5); }
.preview-header { padding: 12px 16px; font-size: 14px; font-weight: 600; color: #1A5276; background: rgba(26,82,118,0.05); border-bottom: 1px solid rgba(26,82,118,0.1); }
.preview-body { padding: 20px; }
.preview-title { font-size: 20px; color: #1A5276; margin-bottom: 16px; font-weight: 600; }
.preview-text { line-height: 1.8; color: #333; margin-bottom: 20px; font-size: 14px; }
.preview-media { margin-top: 16px; padding: 16px; background: rgba(26,82,118,0.03); border-radius: 10px; }
.preview-media p { margin-bottom: 10px; font-weight: 500; font-size: 14px; color: #555; }
.preview-video { max-width: 100%; max-height: 300px; border-radius: 8px; }
.action-buttons { display: flex; gap: 12px; margin-top: 10px; }
:deep(.el-input__inner), :deep(.el-textarea__inner) { border-radius: 8px; }
:deep(.el-select .el-input__inner) { border-radius: 8px; }
:deep(.el-radio-button__inner) { padding: 8px 20px; }
:deep(.el-button) { border-radius: 8px; }
:deep(.el-form-item__label) { font-weight: 500; color: #555; }
</style>