<template>
  <div class="knowledge-page">
    <div class="page-head">
      <div>
        <h2>知识库管理</h2>
        <p>维护 AI 识别知识库与西小导对话 RAG 知识库。</p>
      </div>
      <div class="summary">
        <div>
          <span>{{ summary.visionCount }}</span>
          <small>识别样本</small>
        </div>
        <div>
          <span>{{ summary.visionPlaceCount }}</span>
          <small>识别地点</small>
        </div>
        <div>
          <span>{{ summary.dialogCount }}</span>
          <small>对话知识</small>
        </div>
      </div>
    </div>

    <el-alert class="sync-alert" type="info" show-icon :closable="false">
      <template #title>
        保存文件后，AI 服务内存缓存和 Chroma 向量库需要重新同步后才会完全影响识别与问答结果。
      </template>
      <div class="sync-path">
        <span>识别库：{{ summary.visionDatasetPath || '-' }}</span>
        <span>对话库：{{ summary.dialogChunksPath || '-' }}</span>
      </div>
    </el-alert>

    <el-card class="table-card">
      <el-tabs v-model="activeTab" @tab-change="handleTabChange">
        <el-tab-pane label="AI识别知识库" name="vision">
          <div class="toolbar">
            <el-input v-model="visionKeyword" placeholder="搜索名称、介绍或来源" clearable class="search-input" @keyup.enter="fetchVision" />
            <el-button type="primary" @click="fetchVision">搜索</el-button>
            <el-button @click="openVisionCreate">新增识别地点</el-button>
          </div>

          <el-table :data="visionRows" border stripe v-loading="visionLoading" empty-text="暂无识别知识">
            <el-table-column label="照片样本" min-width="220">
              <template #default="{ row }">
                <div v-if="row.imagePaths?.length" class="thumb-list">
                  <el-image
                    v-for="path in row.imagePaths.slice(0, 4)"
                    :key="path"
                    class="thumb"
                    fit="cover"
                    :src="imageSrc(path)"
                    :preview-src-list="row.imagePaths.map(imageSrc)"
                    preview-teleported
                  />
                  <span v-if="row.imagePaths.length > 4" class="more-count">+{{ row.imagePaths.length - 4 }}</span>
                </div>
                <span v-else class="empty-image">无图</span>
              </template>
            </el-table-column>
            <el-table-column prop="buildingName" label="名称" width="180" />
            <el-table-column prop="imageCount" label="样本数" width="90" />
            <el-table-column label="介绍" min-width="360">
              <template #default="{ row }">
                <span class="preview">{{ row.description }}</span>
              </template>
            </el-table-column>
            <el-table-column prop="sourceUrl" label="来源" min-width="220" show-overflow-tooltip />
            <el-table-column label="操作" width="160" fixed="right">
              <template #default="{ row }">
                <el-button link type="primary" @click="openVisionEdit(row)">编辑</el-button>
                <el-button link type="danger" @click="deleteVision(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>

          <div class="pager">
            <el-pagination
              v-model:current-page="visionPage"
              v-model:page-size="visionPageSize"
              :page-sizes="[10, 20, 50, 100]"
              :total="visionTotal"
              layout="total, sizes, prev, pager, next"
              @current-change="fetchVision"
              @size-change="fetchVision"
            />
          </div>
        </el-tab-pane>

        <el-tab-pane label="对话知识库" name="dialog">
          <div class="toolbar">
            <el-input v-model="dialogKeyword" placeholder="搜索标题、问题、回答或来源文件" clearable class="search-input wide" @keyup.enter="fetchDialog" />
            <el-select v-model="dialogCategory" placeholder="分类" clearable class="category-select">
              <el-option v-for="item in dialogCategories" :key="item" :label="item" :value="item" />
            </el-select>
            <el-button type="primary" @click="fetchDialog">搜索</el-button>
            <el-button @click="openDialogCreate">新增对话知识</el-button>
          </div>

          <el-table :data="dialogRows" border stripe v-loading="dialogLoading" empty-text="暂无对话知识">
            <el-table-column prop="id" label="ID" min-width="190" show-overflow-tooltip />
            <el-table-column prop="title" label="标题" min-width="210" />
            <el-table-column prop="category" label="分类" width="120" />
            <el-table-column prop="source_file" label="来源文件" width="190" show-overflow-tooltip />
            <el-table-column label="回答预览" min-width="360">
              <template #default="{ row }">
                <span class="preview">{{ row.answer }}</span>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="160" fixed="right">
              <template #default="{ row }">
                <el-button link type="primary" @click="openDialogEdit(row)">编辑</el-button>
                <el-button link type="danger" @click="deleteDialog(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>

          <div class="pager">
            <el-pagination
              v-model:current-page="dialogPage"
              v-model:page-size="dialogPageSize"
              :page-sizes="[10, 20, 50, 100]"
              :total="dialogTotal"
              layout="total, sizes, prev, pager, next"
              @current-change="fetchDialog"
              @size-change="fetchDialog"
            />
          </div>
        </el-tab-pane>
      </el-tabs>
    </el-card>

    <el-dialog v-model="visionDialogVisible" :title="visionEditingKey ? '编辑识别地点' : '新增识别地点'" width="760px">
      <el-form label-width="92px">
        <el-form-item label="名称">
          <el-input v-model="visionForm.buildingName" placeholder="例如：含弘门（1号门）" />
        </el-form-item>
        <el-form-item label="照片">
          <div class="photo-manager">
            <div v-for="(path, index) in visionForm.imagePaths" :key="index" class="photo-row">
              <el-input v-model="visionForm.imagePaths[index]" placeholder="data/rag_dataset/images/xxx.jpg" />
              <el-button text type="danger" @click="removeVisionImage(index)">删除</el-button>
            </div>
            <div class="upload-row">
              <el-button @click="addVisionImagePath">手动添加路径</el-button>
              <el-button :loading="uploading" @click="triggerFileInput">上传照片</el-button>
            </div>
            <input ref="fileInputRef" class="hidden-file" type="file" accept="image/*" @change="uploadVisionImage" />
            <div v-if="visionForm.imagePaths.length" class="form-preview-list">
              <div v-for="(path, index) in visionForm.imagePaths" :key="`${path}-${index}`" class="preview-item">
                <el-image
                  class="form-preview-image"
                  fit="cover"
                  :src="imageSrc(path)"
                  :preview-src-list="visionForm.imagePaths.map(imageSrc)"
                  preview-teleported
                />
                <button class="preview-delete" type="button" title="删除图片" @click="removeVisionImage(index)">
                  ×
                </button>
              </div>
            </div>
          </div>
        </el-form-item>
        <el-form-item label="介绍">
          <el-input v-model="visionForm.description" type="textarea" :rows="7" placeholder="填写识别命中后展示给用户的地点介绍" />
        </el-form-item>
        <el-form-item label="来源">
          <el-input v-model="visionForm.sourceUrl" placeholder="官网页面或资料来源 URL" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="visionDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveVision">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="dialogEditVisible" :title="dialogEditingId ? '编辑对话知识' : '新增对话知识'" width="860px">
      <el-form label-width="96px">
        <el-form-item label="ID">
          <el-input v-model="dialogForm.id" placeholder="可留空，保存时自动生成" />
        </el-form-item>
        <el-form-item label="标题">
          <el-input v-model="dialogForm.title" />
        </el-form-item>
        <el-form-item label="问题">
          <el-input v-model="dialogForm.question" type="textarea" :rows="2" />
        </el-form-item>
        <el-form-item label="回答">
          <el-input v-model="dialogForm.answer" type="textarea" :rows="8" />
        </el-form-item>
        <el-form-item label="关键词">
          <el-input v-model="dialogKeywordsText" type="textarea" :rows="3" placeholder="每行一个关键词，也可以用逗号分隔" />
        </el-form-item>
        <div class="form-grid">
          <el-form-item label="分类">
            <el-select v-model="dialogForm.category" filterable allow-create default-first-option>
              <el-option v-for="item in dialogCategories" :key="item" :label="item" :value="item" />
            </el-select>
          </el-form-item>
          <el-form-item label="章节">
            <el-input v-model="dialogForm.section" />
          </el-form-item>
          <el-form-item label="来源">
            <el-input v-model="dialogForm.source" />
          </el-form-item>
          <el-form-item label="来源文件">
            <el-input v-model="dialogForm.sourceFile" />
          </el-form-item>
          <el-form-item label="实体ID">
            <el-input v-model="dialogForm.entityId" />
          </el-form-item>
          <el-form-item label="来源URL">
            <el-input v-model="dialogForm.sourceUrl" />
          </el-form-item>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="dialogEditVisible = false">取消</el-button>
        <el-button type="primary" @click="saveDialog">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import request from '@/api/request'

interface VisionRecord {
  key: string
  buildingName: string
  description: string
  imagePaths: string[]
  imageCount: number
  sourceUrl: string
}

interface DialogRecord {
  id: string
  title: string
  question: string
  answer: string
  keywords: string[] | string
  category: string
  source: string
  source_file: string
  source_url: string
  entity_id: string
  section: string
}

const activeTab = ref('vision')
const summary = reactive<any>({
  visionCount: 0,
  visionPlaceCount: 0,
  dialogCount: 0,
  visionDatasetPath: '',
  dialogChunksPath: '',
})

const visionRows = ref<VisionRecord[]>([])
const visionKeyword = ref('')
const visionPage = ref(1)
const visionPageSize = ref(10)
const visionTotal = ref(0)
const visionLoading = ref(false)
const visionDialogVisible = ref(false)
const visionEditingKey = ref('')
const uploading = ref(false)
const fileInputRef = ref<HTMLInputElement | null>(null)
const visionForm = reactive<any>({
  buildingName: '',
  description: '',
  imagePaths: [] as string[],
  sourceUrl: '',
})

const dialogRows = ref<DialogRecord[]>([])
const dialogCategories = ref<string[]>([])
const dialogKeyword = ref('')
const dialogCategory = ref('')
const dialogPage = ref(1)
const dialogPageSize = ref(10)
const dialogTotal = ref(0)
const dialogLoading = ref(false)
const dialogEditVisible = ref(false)
const dialogEditingId = ref('')
const dialogKeywordsText = ref('')
const dialogForm = reactive<any>({
  id: '',
  title: '',
  question: '',
  answer: '',
  category: 'campus',
  source: 'web_admin',
  sourceFile: 'admin_manual.json',
  sourceUrl: '',
  entityId: '',
  section: '',
})

const imageSrc = (path: string) => `/api/ai/knowledge/vision/image?path=${encodeURIComponent(path)}`

const fetchSummary = async () => {
  const res: any = await request.get('/ai/knowledge/summary')
  Object.assign(summary, res || {})
}

const fetchVision = async () => {
  visionLoading.value = true
  try {
    const res: any = await request.get('/ai/knowledge/vision/list', {
      params: {
        keyword: visionKeyword.value,
        page: visionPage.value,
        size: visionPageSize.value,
      },
    })
    visionRows.value = res?.records || []
    visionTotal.value = res?.total || 0
  } finally {
    visionLoading.value = false
  }
}

const fetchDialog = async () => {
  dialogLoading.value = true
  try {
    const res: any = await request.get('/ai/knowledge/dialog/list', {
      params: {
        keyword: dialogKeyword.value,
        category: dialogCategory.value,
        page: dialogPage.value,
        size: dialogPageSize.value,
      },
    })
    dialogRows.value = res?.records || []
    dialogTotal.value = res?.total || 0
  } finally {
    dialogLoading.value = false
  }
}

const fetchDialogCategories = async () => {
  dialogCategories.value = await request.get('/ai/knowledge/dialog/categories') as string[]
}

const handleTabChange = () => {
  if (activeTab.value === 'dialog') {
    fetchDialog()
    fetchDialogCategories()
  } else {
    fetchVision()
  }
}

const openVisionCreate = () => {
  visionEditingKey.value = ''
  Object.assign(visionForm, { buildingName: '', description: '', imagePaths: [], sourceUrl: '' })
  visionDialogVisible.value = true
}

const openVisionEdit = (row: VisionRecord) => {
  visionEditingKey.value = row.key
  Object.assign(visionForm, {
    buildingName: row.buildingName,
    description: row.description,
    imagePaths: [...(row.imagePaths || [])],
    sourceUrl: row.sourceUrl,
  })
  visionDialogVisible.value = true
}

const saveVision = async () => {
  const imagePaths = visionForm.imagePaths.map((item: string) => item.trim()).filter(Boolean)
  if (!visionForm.buildingName || !visionForm.description || imagePaths.length === 0) {
    ElMessage.warning('请填写名称、介绍，并至少添加一张照片')
    return
  }
  const payload = { ...visionForm, imagePaths }
  if (visionEditingKey.value) {
    await request.put(`/ai/knowledge/vision/${encodeURIComponent(visionEditingKey.value)}`, payload)
  } else {
    await request.post('/ai/knowledge/vision', payload)
  }
  ElMessage.success('已保存识别知识')
  visionDialogVisible.value = false
  await fetchVision()
  await fetchSummary()
}

const deleteVision = async (row: VisionRecord) => {
  await ElMessageBox.confirm(`确定删除“${row.buildingName}”及其 ${row.imageCount || 0} 张照片样本？`, '提示', { type: 'warning' })
  await request.delete(`/ai/knowledge/vision/${encodeURIComponent(row.key)}`)
  ElMessage.success('已删除')
  fetchVision()
  fetchSummary()
}

const triggerFileInput = () => {
  fileInputRef.value?.click()
}

const addVisionImagePath = () => {
  visionForm.imagePaths.push('')
}

const removeVisionImage = (index: number) => {
  visionForm.imagePaths.splice(index, 1)
}

const uploadVisionImage = async (event: Event) => {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) {
    return
  }
  const formData = new FormData()
  formData.append('file', file)
  uploading.value = true
  try {
    const res: any = await request.post('/ai/knowledge/vision/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    if (!visionForm.imagePaths.includes(res.imagePath)) {
      visionForm.imagePaths.push(res.imagePath)
    }
    ElMessage.success('图片已上传')
  } finally {
    uploading.value = false
    input.value = ''
  }
}

const openDialogCreate = () => {
  dialogEditingId.value = ''
  Object.assign(dialogForm, {
    id: '',
    title: '',
    question: '',
    answer: '',
    category: 'campus',
    source: 'web_admin',
    sourceFile: 'admin_manual.json',
    sourceUrl: '',
    entityId: '',
    section: '',
  })
  dialogKeywordsText.value = ''
  dialogEditVisible.value = true
}

const openDialogEdit = (row: DialogRecord) => {
  dialogEditingId.value = row.id
  Object.assign(dialogForm, {
    id: row.id,
    title: row.title,
    question: row.question,
    answer: row.answer,
    category: row.category || 'campus',
    source: row.source || 'swu_rag_knowledge_base',
    sourceFile: row.source_file || '',
    sourceUrl: row.source_url || '',
    entityId: row.entity_id || '',
    section: row.section || '',
  })
  dialogKeywordsText.value = Array.isArray(row.keywords) ? row.keywords.join('\n') : String(row.keywords || '')
  dialogEditVisible.value = true
}

const saveDialog = async () => {
  if (!dialogForm.title || !dialogForm.answer) {
    ElMessage.warning('请填写标题和回答内容')
    return
  }
  const payload = {
    ...dialogForm,
    keywords: dialogKeywordsText.value,
  }
  if (dialogEditingId.value) {
    await request.put(`/ai/knowledge/dialog/${encodeURIComponent(dialogEditingId.value)}`, payload)
  } else {
    await request.post('/ai/knowledge/dialog', payload)
  }
  ElMessage.success('已保存对话知识')
  dialogEditVisible.value = false
  await fetchDialog()
  await fetchDialogCategories()
  await fetchSummary()
}

const deleteDialog = async (row: DialogRecord) => {
  await ElMessageBox.confirm(`确定删除“${row.title || row.id}”？`, '提示', { type: 'warning' })
  await request.delete(`/ai/knowledge/dialog/${encodeURIComponent(row.id)}`)
  ElMessage.success('已删除')
  fetchDialog()
  fetchSummary()
}

onMounted(async () => {
  await fetchSummary()
  await fetchVision()
  await fetchDialogCategories()
})
</script>

<style scoped>
.knowledge-page {
  display: grid;
  gap: 18px;
}

.page-head {
  display: flex;
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

.summary {
  display: flex;
  gap: 12px;
}

.summary div {
  min-width: 110px;
  padding: 12px 16px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.78);
  border: 1px solid rgba(255, 255, 255, 0.72);
}

.summary span {
  display: block;
  color: #023d83;
  font-size: 24px;
  font-weight: 700;
}

.summary small {
  color: #64748b;
}

.sync-alert {
  border-radius: 8px;
}

.sync-path {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 18px;
  margin-top: 6px;
}

.table-card {
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.84);
}

.toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 14px;
}

.search-input {
  width: 280px;
}

.search-input.wide {
  width: 340px;
}

.category-select {
  width: 150px;
}

.thumb {
  width: 72px;
  height: 56px;
  border-radius: 6px;
  border: 1px solid #dbeafe;
}

.thumb-list {
  display: flex;
  align-items: center;
  gap: 8px;
}

.more-count {
  color: #64748b;
  font-weight: 700;
}

.empty-image {
  color: #94a3b8;
}

.preview {
  display: -webkit-box;
  overflow: hidden;
  color: #334155;
  line-height: 1.5;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
}

.pager {
  display: flex;
  justify-content: flex-end;
  margin-top: 14px;
}

.upload-row {
  display: flex;
  width: 100%;
  gap: 10px;
}

.photo-manager {
  display: grid;
  width: 100%;
  gap: 10px;
}

.photo-row {
  display: flex;
  gap: 8px;
}

.hidden-file {
  display: none;
}

.form-preview-list {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.preview-item {
  position: relative;
  width: 132px;
  height: 92px;
}

.form-preview-image {
  width: 132px;
  height: 92px;
  border-radius: 8px;
  border: 1px solid #dbeafe;
}

.preview-delete {
  position: absolute;
  top: -7px;
  right: -7px;
  width: 22px;
  height: 22px;
  border: 1px solid rgba(255, 255, 255, 0.9);
  border-radius: 50%;
  background: #ef4444;
  color: #fff;
  font-size: 16px;
  font-weight: 700;
  line-height: 18px;
  cursor: pointer;
  box-shadow: 0 4px 10px rgba(15, 23, 42, 0.18);
}

.preview-delete:hover {
  background: #dc2626;
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  column-gap: 12px;
}
</style>
