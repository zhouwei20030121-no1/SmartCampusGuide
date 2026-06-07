<template>
  <div class="story-page">
    <div class="page-head">
      <div>
        <h2>校园故事管理</h2>
        <p>维护 App 首页故事列表与讲解页弹出的校园故事。没有手写内容时，可先用 AI 生成。</p>
      </div>
      <div class="head-actions">
        <el-button @click="openGenerate">AI生成故事</el-button>
        <el-button type="primary" @click="openCreate">新建故事</el-button>
      </div>
    </div>

    <el-card class="table-card">
      <div class="toolbar">
        <el-input v-model="keyword" placeholder="搜索标题或内容" clearable class="search-input" @keyup.enter="fetchStories" />
        <el-select v-model="language" placeholder="语言" clearable class="lang-select">
          <el-option label="中文" value="zh" />
          <el-option label="English" value="en" />
          <el-option label="日本語" value="ja" />
          <el-option label="Français" value="fr" />
          <el-option label="한국어" value="ko" />
        </el-select>
        <el-button type="primary" @click="fetchStories">搜索</el-button>
      </div>

      <el-table :data="stories" border stripe v-loading="loading" empty-text="暂无校园故事">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="title" label="标题" min-width="180" />
        <el-table-column prop="spotName" label="关联景点" width="180" />
        <el-table-column prop="language" label="语言" width="90" />
        <el-table-column prop="sourceType" label="来源" width="120" />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'">{{ row.status === 1 ? '启用' : '停用' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="内容预览" min-width="280">
          <template #default="{ row }">
            <span class="preview">{{ row.storyContent }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="170" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button link type="danger" @click="deleteStory(row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="dialogVisible" :title="form.id ? '编辑校园故事' : '新建校园故事'" width="720px">
      <el-form label-width="90px">
        <el-form-item label="景点ID">
          <el-input v-model.number="form.spotId" type="number" placeholder="填写 scenic_spot 表中的景点 ID" />
        </el-form-item>
        <el-form-item label="标题">
          <el-input v-model="form.title" />
        </el-form-item>
        <el-form-item label="语言">
          <el-select v-model="form.language">
            <el-option label="中文" value="zh" />
            <el-option label="English" value="en" />
            <el-option label="日本語" value="ja" />
            <el-option label="Français" value="fr" />
            <el-option label="한국어" value="ko" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-radio-group v-model="form.status">
            <el-radio :label="1">启用</el-radio>
            <el-radio :label="0">停用</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="故事内容">
          <el-input v-model="form.storyContent" type="textarea" :rows="12" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveStory">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="generateVisible" title="AI生成校园故事" width="620px">
      <el-form label-width="90px">
        <el-form-item label="景点名称">
          <el-input v-model="generateForm.spotName" placeholder="例如：中心图书馆" />
        </el-form-item>
        <el-form-item label="景点ID">
          <el-input v-model.number="generateForm.spotId" type="number" placeholder="可选，填写后直接关联景点" />
        </el-form-item>
        <el-form-item label="用户身份">
          <el-select v-model="generateForm.persona">
            <el-option label="新生" value="新生" />
            <el-option label="校友" value="校友" />
            <el-option label="游客" value="游客" />
          </el-select>
        </el-form-item>
        <el-form-item label="语言">
          <el-select v-model="generateForm.language">
            <el-option label="中文" value="zh" />
            <el-option label="English" value="en" />
            <el-option label="日本語" value="ja" />
            <el-option label="Français" value="fr" />
            <el-option label="한국어" value="ko" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="generateVisible = false">取消</el-button>
        <el-button type="primary" :loading="generating" @click="generateAndSave">生成并入库</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '@/api/request'

const stories = ref<any[]>([])
const loading = ref(false)
const keyword = ref('')
const language = ref('zh')
const dialogVisible = ref(false)
const generateVisible = ref(false)
const generating = ref(false)

const form = reactive<any>({
  id: null,
  spotId: null,
  title: '',
  language: 'zh',
  sourceType: 'manual',
  storyContent: '',
  status: 1,
})

const generateForm = reactive<any>({
  spotName: '中心图书馆',
  spotId: null,
  persona: '新生',
  language: 'zh',
})

const fetchStories = async () => {
  loading.value = true
  try {
    const res: any = await request.get('/ai/story/list', {
      params: { keyword: keyword.value, language: language.value, page: 1, size: 100 },
    })
    const data = res?.data || res || {}
    stories.value = data.records || []
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  Object.assign(form, { id: null, spotId: null, title: '', language: 'zh', sourceType: 'manual', storyContent: '', status: 1 })
}

const openCreate = () => {
  resetForm()
  dialogVisible.value = true
}

const openEdit = (row: any) => {
  Object.assign(form, row)
  dialogVisible.value = true
}

const saveStory = async () => {
  if (!form.spotId || !form.title || !form.storyContent) {
    ElMessage.warning('请填写景点ID、标题和故事内容')
    return
  }
  if (form.id) {
    await request.put(`/ai/story/${form.id}`, form)
  } else {
    await request.post('/ai/story', form)
  }
  ElMessage.success('已保存')
  dialogVisible.value = false
  fetchStories()
}

const deleteStory = async (id: number) => {
  await ElMessageBox.confirm('确定删除这条校园故事？', '提示', { type: 'warning' })
  await request.delete(`/ai/story/${id}`)
  ElMessage.success('已删除')
  fetchStories()
}

const openGenerate = () => {
  generateVisible.value = true
}

const generateAndSave = async () => {
  generating.value = true
  try {
    await request.post('/ai/story/generate-save', generateForm)
    ElMessage.success('AI故事已生成并入库')
    generateVisible.value = false
    fetchStories()
  } finally {
    generating.value = false
  }
}

onMounted(fetchStories)
</script>

<style scoped>
.story-page {
  display: grid;
  gap: 18px;
}

.page-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.page-head h2 {
  margin: 0 0 6px;
  color: #123b5d;
  font-size: 26px;
}

.page-head p {
  margin: 0;
  color: #64748b;
}

.head-actions,
.toolbar {
  display: flex;
  gap: 10px;
}

.table-card {
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.82);
}

.toolbar {
  margin-bottom: 14px;
}

.search-input {
  width: 260px;
}

.lang-select {
  width: 140px;
}

.preview {
  display: -webkit-box;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  line-height: 1.5;
}
</style>
